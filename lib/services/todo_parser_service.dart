import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' show basename;

import '../models/openai_response.dart';

class TodoParserService {
  final String baseUrl;
  final String apiKey;
  final http.Client client;

  TodoParserService({required this.client, String? baseUrl, String? apiKey})
    : baseUrl = baseUrl ?? 'https://api.abarrett.io',
      apiKey = apiKey ?? dotenv.env['DEMO_ACCESS_KEY'] ?? '';

  Future<List<OpenAIResponse>> parseAudio(File audioFile) async {
    final uri = Uri.parse('$baseUrl/parse-todo');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFile.path,
          filename: basename(audioFile.path),
          contentType: MediaType('audio', 'm4a'),
        ),
      )
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['userDateTime'] = DateTime.now().toIso8601String();

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
      final items = jsonResponse['todos'] as List<dynamic>;
      return items.map((item) => OpenAIResponse.fromJson(item)).toList();
    } else {
      throw HttpException('Failed to parse audio. Status code: ${response.statusCode}', uri: uri);
    }
  }
}
