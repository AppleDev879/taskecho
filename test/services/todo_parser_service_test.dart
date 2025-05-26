import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:interview_todos/models/openai_response.dart';
import 'package:interview_todos/services/todo_parser_service.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

// Load test environment variables
Future<void> setupTestEnv() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
}

// Create a mock response for successful API call
final mockResponse = {
  'todos': [
    {
      'title': 'Test Todo',
      'description': 'Test Description',
      'due_date': '2023-01-01T12:00:00Z',
      'priority': 'high',
      'category': 'personal',
    },
  ],
};

void main() {
  // Setup test environment before all tests
  setUpAll(() async {
    await setupTestEnv();
    registerFallbackValue(Uri.parse('https://fallback.test'));
    registerFallbackValue(http.MultipartRequest('POST', Uri.parse('https://fallback.test')));
  });

  group('TodoParserService', () {
    late TodoParserService service;
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
      service = TodoParserService(client: mockClient);
    });

    tearDown(() {
      mockClient.close();
    });

    tearDown(() {
      mockClient.close();
    });

    test('parseAudio returns list of OpenAIResponse on success', () async {
      // Arrange
      final testFile = File('test/assets/test_audio.m4a');
      when(() => mockClient.send(any())).thenAnswer((_) async {
        final stream = Stream.value(utf8.encode(jsonEncode(mockResponse)));
        return http.StreamedResponse(stream, 200);
      });

      // Act
      final result = await service.parseAudio(testFile);

      // Assert
      expect(result, isA<List<OpenAIResponse>>());
      expect(result.length, 1);
      expect(result.first.title, 'Test Todo');
      expect(result.first.description, 'Test Description');
      expect(result.first.dateTime, '2023-01-01T12:00:00Z');
      expect(result.first.priority, 'high');
      expect(result.first.category, 'personal');
    });

    test('parseAudio throws HttpException on non-200 response', () async {
      // Arrange
      final testFile = File('test/assets/test_audio.m4a');
      when(() => mockClient.send(any())).thenAnswer((_) async {
        final stream = Stream.value(utf8.encode('Bad Request'));
        return http.StreamedResponse(stream, 400);
      });

      // Act & Assert
      expect(() => service.parseAudio(testFile), throwsA(isA<HttpException>()));
    });

    test('uses provided baseUrl and apiKey', () {
      // Arrange
      const customBaseUrl = 'https://custom-api.example.com';
      const customApiKey = 'test-api-key';

      // Act
      service = TodoParserService(client: mockClient, baseUrl: customBaseUrl, apiKey: customApiKey);

      // Assert
      expect(service.baseUrl, customBaseUrl);
      expect(service.apiKey, customApiKey);
    });
  });
}
