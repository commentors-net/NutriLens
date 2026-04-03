import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_service.dart';

enum LogUploadScope {
  today,
  all,
  range,
}

extension LogUploadScopeName on LogUploadScope {
  String get apiValue {
    switch (this) {
      case LogUploadScope.today:
        return "today";
      case LogUploadScope.all:
        return "all";
      case LogUploadScope.range:
        return "range";
    }
  }

  String get label {
    switch (this) {
      case LogUploadScope.today:
        return "Today";
      case LogUploadScope.all:
        return "All logs";
      case LogUploadScope.range:
        return "Date range";
    }
  }
}

class AppLogService {
  static const String _consentKey = 'diagnostics_log_upload_consent';
  static final List<String> _buffer = <String>[];
  static const int _maxBufferEntries = 500;
  static bool _initialized = false;
  static void Function(String? message, {int? wrapWidth})? _originalDebugPrint;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.trim().isNotEmpty) {
        log("DEBUG", message);
      }
      _originalDebugPrint?.call(message, wrapWidth: wrapWidth);
    };

    FlutterError.onError = (FlutterErrorDetails details) {
      log(
        "FLUTTER_ERROR",
        details.exceptionAsString(),
        stackTrace: details.stack,
      );
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      log("UNHANDLED", error.toString(), stackTrace: stack);
      return false;
    };

    log("INFO", "AppLogService initialized");
  }

  static void log(String level, String message, {StackTrace? stackTrace}) {
    final ts = DateTime.now().toIso8601String();
    final line = "[$ts][$level] $message";
    _buffer.add(line);
    if (_buffer.length > _maxBufferEntries) {
      _buffer.removeAt(0);
    }
    if (stackTrace != null) {
      _buffer.add("[$ts][STACK] $stackTrace");
    }
    unawaited(_appendToDisk([line, if (stackTrace != null) "[$ts][STACK] $stackTrace"]));
  }

  static Future<File> _logFileForDate(DateTime date) async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory("${dir.path}/logs");
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final dateName = date.toIso8601String().split('T').first;
    return File("${logDir.path}/app-$dateName.log");
  }

  static Future<void> _appendToDisk(List<String> lines) async {
    final file = await _logFileForDate(DateTime.now());
    await file.writeAsString("${lines.join("\n")}\n", mode: FileMode.append, flush: false);
  }

  static DateTime? _extractDateFromLogFileName(String fileName) {
    final match = RegExp(r'^app-(\d{4}-\d{2}-\d{2})\.log$').firstMatch(fileName);
    if (match == null) return null;
    return DateTime.tryParse(match.group(1)!);
  }

  static Future<List<File>> _resolveFilesForRange(
    DateTime? start,
    DateTime? end,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory("${dir.path}/logs");
    if (!await logDir.exists()) return [];

    final files = await logDir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();

    final filtered = files.where((file) {
      final date = _extractDateFromLogFileName(file.uri.pathSegments.last);
      if (date == null) return false;
      if (start != null && date.isBefore(DateTime(start.year, start.month, start.day))) {
        return false;
      }
      if (end != null && date.isAfter(DateTime(end.year, end.month, end.day))) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) => a.path.compareTo(b.path));
    return filtered;
  }

  static Future<String> exportLogs({
    int maxChars = 200000,
    LogUploadScope scope = LogUploadScope.today,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    DateTime? start;
    DateTime? end;
    final now = DateTime.now();

    if (scope == LogUploadScope.today) {
      start = DateTime(now.year, now.month, now.day);
      end = start;
    } else if (scope == LogUploadScope.range) {
      if (startDate == null || endDate == null) {
        throw Exception("Start date and end date are required for range uploads");
      }
      if (endDate.isBefore(startDate)) {
        throw Exception("End date must be on or after start date");
      }
      start = DateTime(startDate.year, startDate.month, startDate.day);
      end = DateTime(endDate.year, endDate.month, endDate.day);
    }

    final files = await _resolveFilesForRange(start, end);
    final diskChunks = <String>[];
    for (final file in files) {
      final text = await file.readAsString();
      final name = file.uri.pathSegments.last;
      diskChunks.add("=== DISK LOG FILE: $name ===\n$text");
    }

    final includeMemory = scope == LogUploadScope.all ||
        scope == LogUploadScope.today ||
        (scope == LogUploadScope.range && start != null && end != null &&
            !now.isBefore(start) && !now.isAfter(end.add(const Duration(days: 1))));
    final memText = includeMemory ? _buffer.join("\n") : "";

    final merged = [
      if (includeMemory) "=== MEMORY LOG BUFFER ===",
      if (includeMemory) memText,
      if (includeMemory) "",
      ...diskChunks,
    ].join("\n");

    if (merged.length <= maxChars) {
      return merged;
    }
    return merged.substring(merged.length - maxChars);
  }

  static Future<Map<String, dynamic>> uploadLogs({
    required String baseUrl,
    required AuthService authService,
    required String environment,
    LogUploadScope scope = LogUploadScope.today,
    DateTime? startDate,
    DateTime? endDate,
    String appVersion = "0.1.0",
  }) async {
    final consent = await isUploadConsentGranted();
    if (!consent) {
      throw Exception("Diagnostics consent not granted");
    }

    final logs = await exportLogs(
      scope: scope,
      startDate: startDate,
      endDate: endDate,
    );
    final token = await authService.getIdToken();
    final uri = Uri.parse("$baseUrl/meals/logs");

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "app_version": appVersion,
        "platform": Platform.operatingSystem,
        "environment": environment,
        "session_id": DateTime.now().millisecondsSinceEpoch.toString(),
        "log_scope": scope.apiValue,
        "range_start": startDate?.toIso8601String().split('T').first,
        "range_end": endDate?.toIso8601String().split('T').first,
        "logs": logs,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      log("INFO", "Logs uploaded successfully id=${decoded['log_id']}");
      return decoded;
    }

    log("ERROR", "Log upload failed ${response.statusCode}: ${response.body}");
    throw Exception("Log upload failed: ${response.statusCode}");
  }

  static Future<bool> isUploadConsentGranted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  static Future<void> setUploadConsent(bool allowed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, allowed);
    log("INFO", "Diagnostics consent updated: $allowed");
  }
}
