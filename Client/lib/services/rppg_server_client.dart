import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class ConnectionInfo {
  final String? recommendedUrl;
  final List<String> wsUrls;

  ConnectionInfo({required this.recommendedUrl, required this.wsUrls});

  factory ConnectionInfo.fromJson(Map<String, dynamic> j) {
    final recommended = j['recommended_url'] as String?;
    final wsList = <String>[];

    final arr = j['websocket_urls'];
    if (arr is List) {
      for (final item in arr) {
        if (item is Map && item['url'] is String) {
          wsList.add(item['url'] as String);
        }
      }
    }

    return ConnectionInfo(recommendedUrl: recommended, wsUrls: wsList);
  }
}

class StreamStatus {
  final String status;
  final String? message;
  StreamStatus(this.status, this.message);
}

class StreamData {
  final double? heartRate;
  final double? signalStrength;
  final int? frame;
  final List<double>? rppgSignal;

  StreamData({this.heartRate, this.signalStrength, this.frame, this.rppgSignal});
}

class RppgServerClient {
  WebSocketChannel? _ch;

  final _statusCtrl = StreamController<StreamStatus>.broadcast();
  final _dataCtrl = StreamController<StreamData>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  Stream<StreamStatus> get statusStream => _statusCtrl.stream;
  Stream<StreamData> get dataStream => _dataCtrl.stream;
  Stream<String> get errorStream => _errorCtrl.stream;

  bool get isConnected => _ch != null;

  /// Python client.py 로직 동일:
  /// - baseUrl이 주어지면: GET {baseUrl}/api/connection-info
  /// - 성공 시 recommended_url 우선 사용, 없으면 websocket_urls 마지막 사용
  Future<void> connectWithBaseUrl(String baseUrl) async {
    final info = await _getConnectionInfo(baseUrl);

    if (info.wsUrls.isEmpty && (info.recommendedUrl == null || info.recommendedUrl!.isEmpty)) {
      throw Exception('사용 가능한 WebSocket URL이 없습니다.');
    }

    final wsUrl = (info.recommendedUrl != null && info.recommendedUrl!.isNotEmpty)
        ? info.recommendedUrl!
        : info.wsUrls.last;

    _ch = WebSocketChannel.connect(Uri.parse(wsUrl));

    _ch!.stream.listen((event) {
      if (event is! String) return;
      try {
        final Map<String, dynamic> msg = jsonDecode(event);

        // status 메시지: {"status": "...", "message": "..."}
        if (msg.containsKey('status')) {
          final s = msg['status']?.toString() ?? '';
          final m = msg['message']?.toString();
          _statusCtrl.add(StreamStatus(s, m));
          return;
        }

        // data 메시지: heart_rate/signal_strength/frame/rppg_signal 등
        final hr = (msg['heart_rate'] is num) ? (msg['heart_rate'] as num).toDouble() : null;
        final ss = (msg['signal_strength'] is num) ? (msg['signal_strength'] as num).toDouble() : null;
        final frame = (msg['frame'] is num) ? (msg['frame'] as num).toInt() : null;

        List<double>? rppg;
        final sig = msg['rppg_signal'];
        if (sig is List) {
          rppg = sig.whereType<num>().map((e) => e.toDouble()).toList(growable: false);
        }

        _dataCtrl.add(StreamData(
          heartRate: hr,
          signalStrength: ss,
          frame: frame,
          rppgSignal: rppg,
        ));
      } catch (e) {
        _errorCtrl.add('메시지 파싱 오류: $e');
      }
    }, onError: (e) {
      _errorCtrl.add('WebSocket 오류: $e');
    }, onDone: () {
      _errorCtrl.add('WebSocket 연결이 종료되었습니다.');
    });
  }

  Future<ConnectionInfo> _getConnectionInfo(String baseUrl) async {
    final uri = Uri.parse(baseUrl);
    final infoUri = uri.replace(path: '/api/connection-info', query: null);

    final resp = await http.get(infoUri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('서버 응답 오류: ${resp.statusCode}');
    }

    final Map<String, dynamic> j = jsonDecode(resp.body);
    if (j['status'] != 'success') {
      throw Exception(j['message']?.toString() ?? 'connection-info 실패');
    }
    return ConnectionInfo.fromJson(j);
  }

  void startStreaming({int fps = 30}) {
    _send({"action": "start_streaming", "fps": fps});
  }

  void stopStreaming() {
    _send({"action": "stop_streaming"});
  }

  void _send(Map<String, dynamic> msg) {
    _ch?.sink.add(jsonEncode(msg));
  }

  Future<void> disconnect() async {
    await _ch?.sink.close();
    _ch = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _statusCtrl.close();
    await _dataCtrl.close();
    await _errorCtrl.close();
  }
}
