import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'proxy_server.dart';
import 'log_manager.dart';

void main() => runApp(const GateApp());

class GateApp extends StatelessWidget {
  const GateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF90CAF9),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFE3F2FD),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF90CAF9),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _deployIdController = TextEditingController();
  final _keyController = TextEditingController();
  
  bool _vpnActive = false;
  bool _loading = false;
  
  GateProxy? _proxy;
  static const _vpnChannel = MethodChannel('com.gate.app/vpn');
  
  double _downloadSpeed = 0.0;
  double _uploadSpeed = 0.0;
  Timer? _speedTimer;
  
  List<LogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _deployIdController.text = prefs.getString('deploy_id') ?? '';
    _keyController.text = prefs.getString('auth_key') ?? '';
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deploy_id', _deployIdController.text);
    await prefs.setString('auth_key', _keyController.text);
  }

  Future<void> _startVpn() async {
    if (_deployIdController.text.isEmpty || _keyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deployment ID و Key را وارد کنید')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      _proxy = GateProxy(_deployIdController.text, _keyController.text);
      await _proxy!.start();
      
      final bool result = await _vpnChannel.invokeMethod('startVpn', {
        'proxyPort': _proxy!.port,
      });
      
      if (result) {
        setState(() {
          _vpnActive = true;
          _loading = false;
        });
        _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() {
            _downloadSpeed = _proxy?.downloadMonitor.currentSpeed ?? 0;
            _uploadSpeed = _proxy?.uploadMonitor.currentSpeed ?? 0;
            _logs = _proxy?.logManager.logs ?? [];
          });
        });
        _saveConfig();
      } else {
        throw Exception('VPN service failed to start');
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در راه‌اندازی VPN: $e')),
      );
    }
  }

  Future<void> _stopVpn() async {
    _speedTimer?.cancel();
    await _vpnChannel.invokeMethod('stopVpn');
    _proxy?.stop();
    setState(() {
      _vpnActive = false;
      _downloadSpeed = 0;
      _uploadSpeed = 0;
      _logs = [];
    });
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _proxy?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white),
              ),
              child: CustomPaint(painter: KavianiPainter()),
            ),
            const SizedBox(width: 8),
            const Text('Gate VPN', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      _vpnActive ? Icons.lock_open : Icons.lock,
                      size: 48,
                      color: _vpnActive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _vpnActive ? 'VPN فعال' : 'VPN غیرفعال',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : (_vpnActive ? _stopVpn : _startVpn),
                        icon: Icon(_vpnActive ? Icons.power_settings_new : Icons.play_arrow),
                        label: Text(_loading ? 'در حال اتصال...' : (_vpnActive ? 'قطع اتصال' : 'اتصال')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _vpnActive ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.download, color: Colors.blue),
                          const Text('دانلود'),
                          const SizedBox(height: 4),
                          Text(
                            _formatSpeed(_downloadSpeed),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.upload, color: Colors.orange),
                          const Text('آپلود'),
                          const SizedBox(height: 4),
                          Text(
                            _formatSpeed(_uploadSpeed),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('لاگ فعالیت‌ها', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (_, index) {
                          final entry = _logs[index];
                          return Text(
                            '${entry.timestamp.toString().substring(11, 19)} - ${entry.message}',
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1048576) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSec / 1048576).toStringAsFixed(2)} MB/s';
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تنظیمات اتصال'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _deployIdController,
                decoration: const InputDecoration(
                  labelText: 'Deployment ID',
                  hintText: 'AKfycbw...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _keyController,
                decoration: const InputDecoration(
                  labelText: 'Auth Key',
                  hintText: 'کلید امنیتی اسکریپت',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              _saveConfig();
              Navigator.pop(ctx);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}

class KavianiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFC62828);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);
    final gold = Paint()..color = Colors.amber.shade700;
    canvas.drawRect(Rect.fromLTWH(size.width * 0.4, 0, size.width * 0.2, size.height), gold);
    final sun = Paint()..color = Colors.yellow;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), size.width * 0.15, sun);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
