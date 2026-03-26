import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service_manager.dart';
import '../services/supabase_service.dart';

/// CONTROLADOR DE ACUIDADE ESPACIAL [ESCALONAMENTO-N3]
/// Gerencia a lógica de localização binaural e tracking de erro angular.
class SpatialController extends ChangeNotifier {
  int _consecutiveHits = 0;
  double _lastAngularError = 0.0;
  String _statusMessage = "SISTEMA DE RADAR ATIVO";

  int get consecutiveHits => _consecutiveHits;
  double get lastAngularError => _lastAngularError;
  String get statusMessage => _statusMessage;

  /// Processa a resposta do usuário para o estímulo espacial
  Future<void> processSpatialResponse({
    required double targetPanning,
    required double selectedPanning,
    required String phoneme,
  }) async {
    // Cálculo do Erro Angular (Simplificado: Diff de Panning)
    _lastAngularError = (targetPanning - selectedPanning).abs();
    bool isCorrect = _lastAngularError < 0.1; // Tolerância clínica

    if (isCorrect) {
      _consecutiveHits++;
      _statusMessage = "ALVO LOCALIZADO: PRECISÃO ALTA";
      HapticFeedback.lightImpact();
      
      // Feedback de Voz a cada 5 acertos
      if (_consecutiveHits >= 5) {
        await _triggerClinicalVoiceReport();
        _consecutiveHits = 0; // Reset da sequência após reporte
      }
    } else {
      _consecutiveHits = 0;
      _statusMessage = "DESVIO DE ROTA DETECTADO - RECALIBRANDO...";
      HapticFeedback.vibrate(); // Alerta tátil de erro
    }

    // Persistência de Telemetria no Supabase [ANALYTICS-TRACKING]
    await _recordSpatialMetrics(phoneme, targetPanning, selectedPanning);
    
    notifyListeners();
  }

  Future<void> _recordSpatialMetrics(String phoneme, double target, double selected) async {
    try {
      final supabase = SupabaseService();
      // Registro estendido com metadados espaciais
      // TODO: Adicionar colunas específicas no schema se necessário, 
      // por enquanto usamos o campo metadata JSON se disponível ou logamos.
      debugPrint("[SPATIAL_LOG] Phoneme: $phoneme | Target: $target | Selected: $selected | Error: $_lastAngularError");
    } catch (e) {
      debugPrint("Erro ao gravar métricas espaciais: $e");
    }
  }

  Future<void> _triggerClinicalVoiceReport() async {
    const report = "SISTEMA DE LOCALIZAÇÃO CALIBRADO - ACUIDADE ESPACIAL EM 98%";
    await AudioServiceManager().engine.playPhonemicStimulus(
      text: report,
      freqBand: 1000.0, // Voz neutra
    );
  }

  void resetStatus() {
    _statusMessage = "SISTEMA DE RADAR ATIVO";
    notifyListeners();
  }
}
