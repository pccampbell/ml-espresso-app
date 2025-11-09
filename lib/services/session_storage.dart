import 'package:ml_espresso_app/models/weight_reading.dart';

/// Simple in-memory session storage
/// In a production app, this would persist to local storage/database
class SessionStorage {
  static final SessionStorage _instance = SessionStorage._internal();
  factory SessionStorage() => _instance;
  SessionStorage._internal();

  final List<ExtractionSession> _sessions = [];

  /// Get all sessions
  List<ExtractionSession> get sessions => List.unmodifiable(_sessions);

  /// Add a new session
  void addSession(ExtractionSession session) {
    _sessions.insert(0, session); // Add to beginning (newest first)
    print('📊 SessionStorage: Session added. Total sessions: ${_sessions.length}');
    print('   Session details: ${session.readings.length} readings, ${session.durationSeconds.toStringAsFixed(1)}s');
  }

  /// Clear all sessions
  void clearAll() {
    _sessions.clear();
  }

  /// Remove a specific session
  void removeSession(int index) {
    if (index >= 0 && index < _sessions.length) {
      _sessions.removeAt(index);
    }
  }
}

