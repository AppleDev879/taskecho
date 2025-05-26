import 'package:flutter_test/flutter_test.dart';
import 'package:interview_todos/utils/date_utils.dart';

void main() {
  group('Date Utils', () {
    test('stripSeconds removes seconds and milliseconds', () {
      // Arrange
      final dateTime = DateTime(2023, 1, 1, 12, 30, 45, 500);
      
      // Act
      final result = stripSeconds(dateTime);
      
      // Assert
      expect(result.second, 0);
      expect(result.millisecond, 0);
      expect(result.minute, 30);
      expect(result.hour, 12);
      expect(result.day, 1);
      expect(result.month, 1);
      expect(result.year, 2023);
    });
  });
}
