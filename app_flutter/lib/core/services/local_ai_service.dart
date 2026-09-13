import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocalAiResult {
  final String modelName;
  final double latencySeconds;
  final List<LocalAiItem> items;
  final String notes;
  final bool detectedOilSheen;
  final Map<String, dynamic> rawPayload;

  const LocalAiResult({
    required this.modelName,
    required this.latencySeconds,
    required this.items,
    required this.notes,
    required this.detectedOilSheen,
    required this.rawPayload,
  });

  Map<String, dynamic> toJson() {
    return {
      'model': modelName,
      'latency_seconds': latencySeconds,
      'items': items.map((i) => i.toJson()).toList(),
      'notes': notes,
      'detected_oil_sheen': detectedOilSheen,
      'raw_payload': rawPayload,
    };
  }
}

class LocalAiItem {
  final String label;
  final int gramsEstimate;
  final String? visualCue;

  const LocalAiItem({
    required this.label,
    required this.gramsEstimate,
    this.visualCue,
  });

  factory LocalAiItem.fromJson(Map<String, dynamic> json) {
    return LocalAiItem(
      label: json['label'] as String? ?? 'food item',
      gramsEstimate: (json['grams_estimate'] as num?)?.toInt() ?? 100,
      visualCue: json['visual_cue'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'grams_estimate': gramsEstimate,
      if (visualCue != null) 'visual_cue': visualCue,
    };
  }
}

class LocalAiService {
  static const String kDefaultUrl = 'http://192.168.0.200:11434';
  static const String kDefaultModel = 'llama3.2-vision';

  static const String _prefEnabledKey = 'local_ai_enabled';
  static const String _prefUrlKey = 'local_ai_url';
  static const String _prefModelKey = 'local_ai_model';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, enabled);
  }

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefUrlKey) ?? kDefaultUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUrlKey, url.trim().replaceAll(RegExp(r'/+$'), ''));
  }

  Future<String> getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefModelKey) ?? kDefaultModel;
  }

  Future<void> setSelectedModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefModelKey, model.trim());
  }

  /// Ping local Ollama server to verify reachability on LAN
  Future<bool> checkReachability({String? urlOverride}) async {
    try {
      final base = urlOverride ?? await getBaseUrl();
      final url = Uri.parse('$base/api/tags');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Query available local vision models from Ollama
  Future<List<String>> fetchModels({String? urlOverride}) async {
    try {
      final base = urlOverride ?? await getBaseUrl();
      final url = Uri.parse('$base/api/tags');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final models = (data['models'] as List? ?? [])
            .map((m) => (m as Map<String, dynamic>)['name'] as String)
            .toList();
        return models;
      }
    } catch (_) {}
    return [];
  }

  /// Perform deep multimodal vision analysis via local Ollama agent
  Future<LocalAiResult> analyzeMealImages({
    required List<String> imagePaths,
    String? modelOverride,
    String? userNote,
  }) async {
    final base = await getBaseUrl();
    final model = modelOverride ?? await getSelectedModel();

    // Encode images to base64
    final base64Images = <String>[];
    for (final path in imagePaths) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        base64Images.add(base64Encode(bytes));
      }
    }

    if (base64Images.isEmpty) {
      throw Exception('No valid images available for local analysis.');
    }

    final prompt = '''
You are a specialist Food Vision Agent running on local hardware.
Examine the meal photos closely with particular focus on:
1. Identifying every distinct food item.
2. Estimating portion size in grams.
3. Scrutinizing surface gloss/sheen for hidden cooking oils, ghee, butter, or heavy sauces.
4. Layered ingredients or garnishes.

User Context: ${userNote ?? "None"}

Respond strictly in JSON matching:
{
  "detected_oil_sheen": true,
  "notes": "Surface shows clear sheen indicating approximately 15g butter/cooking oil.",
  "items": [
    {
      "label": "grilled chicken breast",
      "grams_estimate": 160,
      "visual_cue": "char marks, firm texture"
    },
    {
      "label": "butter",
      "grams_estimate": 15,
      "visual_cue": "glossy surface reflection"
    }
  ]
}
''';

    final stopwatch = Stopwatch()..start();
    final url = Uri.parse('$base/api/chat');

    final payload = {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': prompt,
          'images': base64Images.take(4).toList(),
        }
      ],
      'stream': false,
      'format': 'json',
    };

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 90));

    stopwatch.stop();
    final latency = stopwatch.elapsedMilliseconds / 1000.0;

    if (response.statusCode != 200) {
      throw Exception('Local AI returned ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = data['message'] as Map<String, dynamic>? ?? {};
    final contentStr = message['content'] as String? ?? '{}';

    Map<String, dynamic> parsedContent;
    try {
      parsedContent = jsonDecode(contentStr) as Map<String, dynamic>;
    } catch (_) {
      parsedContent = {
        'notes': contentStr,
        'detected_oil_sheen': false,
        'items': [],
      };
    }

    final rawItems = parsedContent['items'] as List? ?? [];
    final items = rawItems
        .map((i) => LocalAiItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return LocalAiResult(
      modelName: model,
      latencySeconds: latency,
      items: items,
      notes: parsedContent['notes'] as String? ?? 'Local analysis complete.',
      detectedOilSheen: parsedContent['detected_oil_sheen'] as bool? ?? false,
      rawPayload: parsedContent,
    );
  }
}

final localAiServiceProvider = Provider<LocalAiService>((ref) {
  return LocalAiService();
});
