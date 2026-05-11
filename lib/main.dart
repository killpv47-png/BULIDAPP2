import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const GateApp());

class GateApp extends StatelessWidget {
  const GateApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF90CAF9)),
      scaffoldBackgroundColor: const Color(0xFFE3F2FD),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF90CAF9), foregroundColor: Colors.white),
    ),
    home: const BrowserPage(),
  );
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});
  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final _urlController = TextEditingController();
  final _deployController = TextEditingController();
  final _keyController = TextEditingController();
  WebViewController? _webController;
  bool _googleMode = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('about:blank'));
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _deployController.text = prefs.getString('deploy_id') ?? '';
    _keyController.text = prefs.getString('auth_key') ?? '';
  }

  Future<void> _navigate(String url) async {
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'https://$url';

    if (_googleMode) {
      final scriptId = _deployController.text.trim();
      final key = _keyController.text.trim();
      if (scriptId.isEmpty || key.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deployment ID و Key را وارد کنید')));
        return;
      }
      try {
        final response = await http.post(
          Uri.parse('https://script.google.com/macros/s/$scriptId/exec'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'key': key, 'url': url, 'method': 'GET'}),
        );
        if (response.statusCode == 200) {
          _webController?.loadHtmlString(response.body);
        } else {
          throw Exception('Error ${response.statusCode}');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e')));
      }
    } else {
      _webController?.loadRequest(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Gate Browser'),
      actions: [
        Switch(value: _googleMode, onChanged: (v) => setState(() => _googleMode = v)),
        IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _urlController,
            decoration: const InputDecoration(hintText: 'آدرس', border: OutlineInputBorder()),
            onSubmitted: _navigate,
          ),
        ),
        Expanded(child: WebViewWidget(controller: _webController!)),
      ],
    ),
  );

  void _showSettings() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('تنظیمات'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _deployController, decoration: const InputDecoration(labelText: 'Deployment ID')),
        TextField(controller: _keyController, decoration: const InputDecoration(labelText: 'Auth Key'), obscureText: true),
      ]),
      actions: [
        TextButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('deploy_id', _deployController.text);
            await prefs.setString('auth_key', _keyController.text);
            Navigator.pop(context);
          },
          child: const Text('ذخیره'),
        ),
      ],
    ),
  );
}
