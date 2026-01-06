import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

class HrUpdate {
  final double hr;
  final int quality;
  HrUpdate({required this.hr, required this.quality});

  factory HrUpdate.fromJson(Map<String, dynamic> j) => HrUpdate(
    hr: (j['hr'] as num).toDouble(),
    quality: (j['quality'] as num).toInt(),
  );
}

class FinalResult {
  final double avgHr;
  final double stress;
  FinalResult({required this.avgHr, required this.stress});

  factory FinalResult.fromJson(Map<String, dynamic> j) => FinalResult(
    avgHr: (j['avg_hr'] as num).toDouble(),
    stress: (j['stress'] as num).toDouble(),
  );
}

class WsStreamService {
  final Uri uri;
  WebSocketChannel? _ch;

  final _hrCtrl = StreamController<HrUpdate>.broadcast();
  final _finalCtrl = StreamController<FinalResult>.broadcast();

  Stream<HrUpdate> get hrStream => _hrCtrl.stream;
  Stream<FinalResult> get finalStream => _finalCtrl.stream;

  WsStreamService(this.uri);

  Future<void> connect({Map<String, dynamic>? hello}) async {
    _ch = WebSocketChannel.connect(uri);

    // optional: 서버에 세션 시작 메시지
    if (hello != null) {
      _ch!.sink.add(jsonEncode({"type": "start", ...hello}));
    }

    _ch!.stream.listen((event) {
      // 서버가 JSON 텍스트를 보낸다고 가정
      final data = jsonDecode(event as String) as Map<String, dynamic>;
      final type = data['type'];

      if (type == 'hr_update') {
        _hrCtrl.add(HrUpdate.fromJson(data));
      } else if (type == 'final_result') {
        _finalCtrl.add(FinalResult.fromJson(data));
      }
    }, onError: (e) {
      // 필요 시 재연결 로직 추가
    }, onDone: () {
      // 연결 종료 처리
    });
  }

  /// 프레임(또는 feature) 전송: 처음엔 JSON+base64로 단순하게 시작할 수 있음.
  /// 성능 개선 시 binary 송신으로 바꾸는 것을 권장.
  void sendFrameJpegBase64(Uint8List jpegBytes, {int? seq, int? tsMs}) {
    final msg = {
      "type": "frame",
      "seq": seq,
      "ts": tsMs,
      "encoding": "jpeg_base64",
      "payload": base64Encode(jpegBytes),
    };
    _ch?.sink.add(jsonEncode(msg));
  }

  /// 전처리된 숫자 feature만 보내는 방식(권장)
  void sendFeatures(List<double> features, {int? seq, int? tsMs}) {
    final msg = {
      "type": "features",
      "seq": seq,
      "ts": tsMs,
      "payload": features,
    };
    _ch?.sink.add(jsonEncode(msg));
  }

  void stop() {
    _ch?.sink.add(jsonEncode({"type": "stop"}));
  }

  Future<void> close() async {
    await _hrCtrl.close();
    await _finalCtrl.close();
    await _ch?.sink.close();
  }
}
