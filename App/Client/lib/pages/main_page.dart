import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/adaptive_phone_canvas.dart';
import 'measure_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  /// 연구실 밖(학교 Wi‑Fi 등): 공인 IP + ipTIME 외부포트 → 내부 서버(192.168.0.110:8080).
  /// 연구실 안만 쓸 때는 `http://192.168.0.110:8080` 로 바꿔도 됩니다.
  static const String _defaultServerUrl = 'http://220.149.128.13:8888';
  static const String _serverUrlPrefKey = 'server_base_url';
  late final TextEditingController _serverUrlController;
  bool _testingConnection = false;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController(text: _defaultServerUrl);
    _restoreServerUrl();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  String _normalizedBaseUrl() {
    final raw = _serverUrlController.text.trim();
    if (raw.isEmpty) return _defaultServerUrl;
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  Future<void> _restoreServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_serverUrlPrefKey);
    if (!mounted || savedUrl == null || savedUrl.trim().isEmpty) return;
    _serverUrlController.text = savedUrl;
  }

  Future<void> _saveServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlPrefKey, _normalizedBaseUrl());
  }

  Future<void> _testServerConnection() async {
    final messenger = ScaffoldMessenger.of(context);
    final baseUrl = _normalizedBaseUrl();
    final healthUri = Uri.parse(baseUrl).replace(path: '/health', query: null);

    setState(() => _testingConnection = true);
    try {
      final resp = await http.get(healthUri).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        await _saveServerUrl();
        messenger.showSnackBar(
          const SnackBar(content: Text('서버 연결 성공 (/health 응답 확인)')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('연결 실패: HTTP ${resp.statusCode}')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('연결 실패: 주소/네트워크/서버 상태를 확인하세요.')),
      );
    } finally {
      if (mounted) {
        setState(() => _testingConnection = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF3F5),
      body: SafeArea(
        child: AdaptivePhoneCanvas(
          child: SizedBox(
            width: 390,
            height: 844,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'rPPG 측정',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '카메라를 통해 심박수와 스트레스 지수를 측정합니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5D646B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.1),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            label: '측정 시간',
                            value: '30초',
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            label: '결과 항목',
                            value: '심박수 / 스트레스',
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _serverUrlController,
                            keyboardType: TextInputType.url,
                            onSubmitted: (_) => _saveServerUrl(),
                            decoration: InputDecoration(
                              labelText: '서버 주소',
                              hintText: 'http://공인IP:8888 (외부 8888→내부 8080)',
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _testingConnection ? null : _testServerConnection,
                              child: Text(
                                _testingConnection ? '연결 확인 중...' : '서버 연결 테스트',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _saveServerUrl();
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DataExtractionScreen(
                              serverBaseUrl: _normalizedBaseUrl(),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '시작하기',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF59626B),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF151515),
            ),
          ),
        ],
      ),
    );
  }
}
