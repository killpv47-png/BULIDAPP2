import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'speed_monitor.dart';
import 'log_manager.dart';

class GateProxy {
  final String scriptId;
  final String authKey;
  final SpeedMonitor uploadMonitor = SpeedMonitor();
  final SpeedMonitor downloadMonitor = SpeedMonitor();
  final LogManager logManager = LogManager();
  HttpServer? _server;
  int? get port => _server?.port;

  GateProxy(this.scriptId, this.authKey);

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    logManager.add('پروکسی روی پورت ${_server!.port} شروع به کار کرد');
    uploadMonitor.start();
    downloadMonitor.start();
    _server!.listen(_handleRequest);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      List<int> bodyBytes = [];
      await for (var chunk in request) {
        bodyBytes.addAll(chunk);
        uploadMonitor.addBytes(chunk.length);
      }
      String targetUrl = request.uri.toString();
      if (targetUrl.startsWith('/')) {
        request.response.statusCode = 400;
        request.response.close();
        return;
      }
      String apiUrl = 'https://script.google.com/macros/s/$scriptId/exec';
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': authKey,
          'url': targetUrl,
          'method': request.method,
          'headers': request.headers,
          'body': bodyBytes.isNotEmpty ? utf8.decode(bodyBytes) : null,
        }),
      );
      List<int> responseBytes = response.bodyBytes;
      downloadMonitor.addBytes(responseBytes.length);
      request.response.statusCode = response.statusCode;
      request.response.add(responseBytes);
      await request.response.close();
      logManager.add('${request.method} $targetUrl -> ${response.statusCode}');
    } catch (e) {
      logManager.add('خطا: $e');
      request.response.statusCode = 500;
      request.response.close();
    }
  }

  void stop() {
    _server?.close();
    uploadMonitor.stop();
    downloadMonitor.stop();
    logManager.add('پروکسی متوقف شد');
  }
}
