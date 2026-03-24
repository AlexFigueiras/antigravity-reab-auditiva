import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class GoogleTTSService {
  final String _apiKey;
  static const String _baseUrl = 'https://texttospeech.googleapis.com/v1/text:synthesize';

  GoogleTTSService(this._apiKey);

  /// Synthesizes text to speech and returns the local file path.
  /// Uses a cache to avoid redundant API calls.
  Future<String> synthesize(String text, {
    String languageCode = 'pt-BR',
    String voiceName = 'pt-BR-Wavenet-A', // Wavenet para alta qualidade clínica
    double speakingRate = 1.0,
    double pitch = 0.0,
  }) async {
    final String cacheKey = _generateCacheKey(text, languageCode, voiceName, speakingRate, pitch);
    final File cacheFile = await _getCacheFile(cacheKey);

    if (await cacheFile.exists()) {
      print('DEBUG: TTS Cache Hit para "$text"');
      return cacheFile.path;
    }

    print('DEBUG: TTS API Call para "$text"');
    
    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': {'text': text},
        'voice': {
          'languageCode': languageCode,
          'name': voiceName,
        },
        'audioConfig': {
          'audioEncoding': 'MP3',
          'speakingRate': speakingRate,
          'pitch': pitch,
        },
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final String audioContent = data['audioContent'];
      final List<int> audioBytes = base64Decode(audioContent);
      
      await cacheFile.writeAsBytes(audioBytes);
      return cacheFile.path;
    } else {
      throw Exception('Falha ao sintetizar áudio: ${response.body}');
    }
  }

  String _generateCacheKey(String text, String lang, String voice, double rate, double pitch) {
    final String input = '$text|$lang|$voice|$rate|$pitch';
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<File> _getCacheFile(String key) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String path = '${tempDir.path}/tts_cache_$key.mp3';
    return File(path);
  }
}
