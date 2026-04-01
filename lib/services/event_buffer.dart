import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../services/audio_service_manager.dart';
import 'supabase_service.dart';

enum AudioOutputHardware { wiredHeadset, bluetooth, internalSpeaker, unknown }

class StimulusEvent {
  final String phoneme;
  final double targetPanning;
  final double selectedPanning;
  final double angularError;
  final bool isCorrect;
  final int reactionTimeMs;
  final int hardwareTimestampNs;
  final String outputHardware;
  final String deviceName;

  StimulusEvent({
    required this.phoneme,
    required this.targetPanning,
    required this.selectedPanning,
    required this.angularError,
    required this.isCorrect,
    required this.reactionTimeMs,
    required this.hardwareTimestampNs,
    required this.outputHardware,
    required this.deviceName,
  });

  Map<String, dynamic> toJson(String sessionId) => {
    'session_id': sessionId,
    'phoneme': phoneme,
    'target_panning': targetPanning,
    'selected_panning': selectedPanning,
    'angular_error': angularError,
    'is_correct': isCorrect,
    'reaction_time_ms': reactionTimeMs,
    'hardware_timestamp_ns': hardwareTimestampNs,
    'output_hardware': outputHardware,
    'device_name': deviceName,
  };
}

class SessionEventBuffer {
  static final SessionEventBuffer _instance = SessionEventBuffer._internal();
  factory SessionEventBuffer() => _instance;
  SessionEventBuffer._internal();

  final List<StimulusEvent> _buffer = [];
  String? _currentSessionId;
  Timer? _heartbeatTimer;
  Timer? _connectivitySyncTimer;
  
  AudioOutputHardware _currentHardware = AudioOutputHardware.unknown;
  String _currentDeviceName = "Unknown";
  StreamSubscription? _audioSessionSub;

  AudioOutputHardware get currentHardware => _currentHardware;
  String get deviceName => _currentDeviceName;

  Future<void> init() async {
    final session = await AudioSession.instance;
    await _updateHardwareInfo();
    
    _audioSessionSub = session.devicesChangedStream.listen((_) async {
      final oldHardware = _currentHardware;
      await _updateHardwareInfo();
      
      // RIGOR CLÍNICO: Se o hardware mudou, reiniciamos o motor Oboe para EXCLUSIVE mode.
      if (oldHardware != _currentHardware) {
        debugPrint("[HARDWARE_RESET] Reiniciando motor Oboe para novo hardware: $_currentHardware");
        await AudioServiceManager().engine.restartHardwareAudio();
      }
    });

    // CONNECTIVITY SYNC: Checa conexão a cada 2 minutos para desovar arquivos offline
    _connectivitySyncTimer = Timer.periodic(const Duration(minutes: 2), (_) => syncOfflineTelemetry());
  }

  Future<void> _updateHardwareInfo() async {
    final session = await AudioSession.instance;
    final devices = await session.getDevices();
    
    _currentHardware = AudioOutputHardware.unknown;
    _currentDeviceName = "Generic_Hardware";

    for (var device in devices) {
      if (device.type == AudioDeviceType.bluetoothA2dp) {
        _currentHardware = AudioOutputHardware.bluetooth;
        // PII SANITIZATION: Não salvamos nomes customizados (ex: "Fone do Alex")
        _currentDeviceName = "Bluetooth_A2DP_Protocol"; 
        break;
      } else if (device.type == AudioDeviceType.wiredHeadset || device.type == AudioDeviceType.wiredHeadphones) {
        _currentHardware = AudioOutputHardware.wiredHeadset;
        _currentDeviceName = "Analog_Wired_Headset";
        break;
      } else if (device.type == AudioDeviceType.builtInSpeaker) {
        _currentHardware = AudioOutputHardware.internalSpeaker;
        _currentDeviceName = "System_Internal_Speaker";
      }
    }
  }

  void startSession(String sessionId) {
    _currentSessionId = sessionId;
    _buffer.clear();
    _resetHeartbeat();
  }

  void _resetHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(const Duration(seconds: 30), () {
      if (_buffer.isNotEmpty) flush();
      _resetHeartbeat();
    });
  }

  void recordEvent(StimulusEvent event) {
    _buffer.add(event);
    _resetHeartbeat();
    if (_buffer.length >= 10) flush();
  }

  Future<void> flush() async {
    if (_buffer.isEmpty || _currentSessionId == null) return;

    final batch = List<StimulusEvent>.from(_buffer);
    _buffer.clear();
    
    final payload = batch.map((e) => e.toJson(_currentSessionId!)).toList();
    
    final filename = "pending_telemetry_${DateTime.now().millisecondsSinceEpoch}.json";
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(jsonEncode(payload));

    try {
      await SupabaseService().saveStimulusResultsBatch(payload);
      await file.delete();
      debugPrint("Telemetry: Upload fixo com sucesso.");
    } catch (e) {
      debugPrint("Telemetry Offline: Persistido localmente.");
    }
  }

  Future<void> syncOfflineTelemetry() async {
    try {
      // Verificação de Internet Lightweight
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      if (result.isEmpty || result[0].rawAddress.isEmpty) return;

      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync().whereType<File>().where((f) => f.path.contains("pending_telemetry_"));
      
      for (var file in files) {
        final content = await file.readAsString();
        final List<dynamic> payload = jsonDecode(content);
        await SupabaseService().saveStimulusResultsBatch(payload.cast<Map<String, dynamic>>());
        await file.delete();
      }
    } catch (_) {}
  }

  void dispose() {
    _audioSessionSub?.cancel();
    _heartbeatTimer?.cancel();
    _connectivitySyncTimer?.cancel();
  }
}
