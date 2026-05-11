class LogEntry {
  final String message;
  final DateTime timestamp;
  LogEntry(this.message) : timestamp = DateTime.now();
}

class LogManager {
  final List<LogEntry> _logs = [];

  void add(String msg) {
    _logs.insert(0, LogEntry(msg));
    if (_logs.length > 100) _logs.removeLast();
  }

  List<LogEntry> get logs => _logs;
}
