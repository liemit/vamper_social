import 'package:intl/intl.dart';

class DateFormatter {
  /// Converts a DateTime into a human-readable "Time Ago" string.
  /// Example: "Just now", "5m ago", "2h ago", "Yesterday", or "15 Sep 2026"
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // For older dates, show day and month
      if (now.year == dateTime.year) {
        return DateFormat('dd MMM').format(dateTime);
      } else {
        return DateFormat('dd MMM yyyy').format(dateTime);
      }
    }
  }

  /// Parses a UTC date string from the database and converts it to local time.
  static DateTime parseUtc(String utcString) {
    try {
      // Expected format: "2026-09-17 10:20:30"
      // We append 'Z' to treat it as UTC if it doesn't have timezone info
      String formatted = utcString;
      if (!formatted.contains('Z') && !formatted.contains('+')) {
        formatted = '${formatted.replaceFirst(' ', 'T')}Z';
      }
      return DateTime.parse(formatted).toLocal();
    } catch (e) {
      print('❌ Error parsing date: $utcString - $e');
      return DateTime.now();
    }
  }
}
