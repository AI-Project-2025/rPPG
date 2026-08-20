import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

/// 사용자 제공 `ppg_stress_simulator.html`을 UTF-8로 읽어 WebView에 표시한다.
class PpgStressSimulatorPage extends StatefulWidget {
  const PpgStressSimulatorPage({super.key});

  @override
  State<PpgStressSimulatorPage> createState() => _PpgStressSimulatorPageState();
}

class _PpgStressSimulatorPageState extends State<PpgStressSimulatorPage> {
  static const _assetPath = 'assets/ppg_stress_simulator.html';

  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    final html = await rootBundle.loadString(_assetPath);
    await _controller.loadHtmlString(
      html,
      baseUrl: 'https://cdn.jsdelivr.net/',
    );
    // WebView 레이아웃 확정 후 Chart.js 캔버스 폭을 맞춘다.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _controller.runJavaScript(
      'if (typeof resizeCharts === "function") resizeCharts();',
    );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF3F5),
      appBar: AppBar(
        title: const Text('PPG 스트레스 시뮬레이터'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const ColoredBox(
              color: Color(0xCCFFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
