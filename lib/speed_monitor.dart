import 'dart:async';

class SpeedMonitor {
  int _totalBytes = 0;
  final List<int> _samples = [];
  Timer? _timer;

  double get currentSpeed {
    if (_samples.length < 2) return 0;
    int diff = _samples.last - _samples.first;
    return diff / _samples.length * 10;
  }

  void addBytes(int bytes) {
    _totalBytes += bytes;
    _samples.add(_totalBytes);
    if (_samples.length > 10) _samples.removeAt(0);
  }

  void start() {
    _timer = Timer.periodic(Duration(milliseconds: 100), (_) {
      _samples.add(_totalBytes);
    });
  }

  void stop() {
    _timer?.cancel();
  }
}
