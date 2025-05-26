/// A collection of date and time utility functions.
library;

/// Strips seconds and milliseconds from a DateTime object.
DateTime stripSeconds(DateTime dt) {
  return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
}

