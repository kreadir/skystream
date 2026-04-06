import 'dart:async';
import 'dart:io';

class AppErrorMessages {
  AppErrorMessages._();

  static String from(Object error) {
    final s = error.toString();
    if (error is SocketException || s.contains('SocketException')) {
      return 'No internet connection';
    }
    if (error is TimeoutException ||
        s.contains('TimeoutException') ||
        s.contains('Connection timed out')) {
      return 'Request timed out. Please try again.';
    }
    if (error is HttpException || s.contains('HttpException')) {
      return 'Server error. Please try again later.';
    }
    if (s.contains('404')) return 'Content not found.';
    if (s.contains('403') || s.contains('401')) {
      return 'Access denied. Check your credentials.';
    }
    if (s.contains('500') || s.contains('502') || s.contains('503')) {
      return 'Server is unavailable. Try again later.';
    }
    return 'Something went wrong. Please try again.';
  }
}
