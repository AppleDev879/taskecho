import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:http/testing.dart';

typedef RequestHandler = Future<Response> Function(Request request);
typedef StreamedRequestHandler = Future<StreamedResponse> Function(Request request);

MockClient createMockSuccessClient(Map<String, dynamic> responseData) {
  return MockClient((request) async {
    return Response(jsonEncode(responseData), 200);
  } as RequestHandler);
}

MockClient createMockErrorClient(int statusCode, String errorMessage) {
  return MockClient((request) async {
    return Response(errorMessage, statusCode);
  } as RequestHandler);
}

MockClient createMockStreamedResponse(StreamedRequestHandler handler) {
  return MockClient((request) async {
    final streamedResponse = await handler(request);
    return Response.fromStream(streamedResponse);
  } as RequestHandler);
}
