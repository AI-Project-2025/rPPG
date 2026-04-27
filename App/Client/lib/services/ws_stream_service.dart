import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 서버로부터 받은 분석 결과
class ServerResult {
  final int? frame;
  final String? timestamp;
  final double? heartRate;
  final double? bvp;
  final double? signalStrength;
  final List<double>? rppgSignal;
  final String? frameImage; // base64 encoded JPEG (선택사항)

  ServerResult({
    this.frame,
    this.timestamp,
    this.heartRate,
    this.bvp,
    this.signalStrength,
    this.rppgSignal,
    this.frameImage,
  });

  factory ServerResult.fromJson(Map<String, dynamic> j) {
    List<double>? rppg;
    final sig = j['rppg_signal'];
    if (sig is List) {
      rppg = sig.whereType<num>().map((e) => e.toDouble()).toList();
    }

    // heart_rate 파싱 (null, 숫자, 문자열 모두 처리)
    double? heartRate;
    final hrValue = j['heart_rate'];
    if (hrValue != null) {
      if (hrValue is num) {
        heartRate = hrValue.toDouble();
      } else if (hrValue is String) {
        // 문자열인 경우 파싱 시도
        final parsed = double.tryParse(hrValue);
        if (parsed != null) heartRate = parsed;
      }
    }

    // bvp 파싱
    double? bvp;
    final bvpValue = j['bvp'];
    if (bvpValue != null) {
      if (bvpValue is num) {
        bvp = bvpValue.toDouble();
      } else if (bvpValue is String) {
        final parsed = double.tryParse(bvpValue);
        if (parsed != null) bvp = parsed;
      }
    }

    return ServerResult(
      frame: j['frame'] != null ? (j['frame'] as num).toInt() : null,
      timestamp: j['timestamp']?.toString(),
      heartRate: heartRate,
      bvp: bvp,
      signalStrength: j['signal_strength'] != null ? (j['signal_strength'] as num).toDouble() : null,
      rppgSignal: rppg,
      frameImage: j['frame_image']?.toString(),
    );
  }
}

/// 서버 상태 메시지
class ServerStatus {
  final String status;
  final String? message;
  final int? fps;

  ServerStatus({
    required this.status,
    this.message,
    this.fps,
  });

  factory ServerStatus.fromJson(Map<String, dynamic> j) {
    return ServerStatus(
      status: j['status']?.toString() ?? '',
      message: j['message']?.toString(),
      fps: j['fps'] != null ? (j['fps'] as num).toInt() : null,
    );
  }
}

class WsStreamService {
  final Uri uri;
  WebSocketChannel? _channel;
  bool _isStreaming = false;
  StreamSubscription? _subscription;

  final _resultCtrl = StreamController<ServerResult>.broadcast();
  final _statusCtrl = StreamController<ServerStatus>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  Stream<ServerResult> get resultStream => _resultCtrl.stream;
  Stream<ServerStatus> get statusStream => _statusCtrl.stream;
  Stream<String> get errorStream => _errorCtrl.stream;

  bool get isStreaming => _isStreaming;

  WsStreamService(this.uri);

  /// 스트림 컨트롤러가 닫혔는지 확인하고 안전하게 이벤트 추가
  void _safeAddError(String message) {
    if (!_errorCtrl.isClosed) {
      try {
        _errorCtrl.add(message);
      } catch (e) {
        // 스트림이 이미 닫혔으면 무시
      }
    }
  }

  void _safeAddStatus(ServerStatus status) {
    if (!_statusCtrl.isClosed) {
      try {
        _statusCtrl.add(status);
      } catch (e) {
        // 스트림이 이미 닫혔으면 무시
      }
    }
  }

  void _safeAddResult(ServerResult result) {
    if (!_resultCtrl.isClosed) {
      try {
        _resultCtrl.add(result);
      } catch (e) {
        // 스트림이 이미 닫혔으면 무시
      }
    }
  }

  /// WebSocket 연결 및 스트리밍 시작
  /// 서버의 streaming_started 응답을 기다린 후 반환
  Future<void> connect({required int fps}) async {
    print('[WS] WebSocket 연결 시도: $uri');
    _channel = WebSocketChannel.connect(uri);

    final completer = Completer<void>();
    bool connectionEstablished = false; // streaming_started를 받았는지 확인

    _subscription = _channel!.stream.listen(
      (msg) {
        if (msg is! String) {
          print('[WS] 바이너리 메시지 수신 (예상치 못한 경우)');
          _safeAddError('바이너리 메시지 수신 (예상치 못한 경우)');
          return;
        }

        try {
          final data = jsonDecode(msg) as Map<String, dynamic>;
          print('[WS] 메시지 수신: ${data.keys}');

          // 상태 메시지 처리
          if (data.containsKey('status')) {
            final status = ServerStatus.fromJson(data);
            print('[WS] 상태 메시지: ${status.status} - ${status.message}');

            if (status.status == 'streaming_started') {
              _isStreaming = true;
              connectionEstablished = true;
              if (!completer.isCompleted) {
                print('[WS] 스트리밍 시작됨!');
                completer.complete();
              }
            } else if (status.status == 'streaming_stopped') {
              _isStreaming = false;
              print('[WS] 스트리밍 중지됨');
            } else if (status.status == 'error') {
              print('[WS] 서버 오류: ${status.message}');
              _safeAddError(status.message ?? '알 수 없는 오류');
              if (!completer.isCompleted) {
                completer.completeError(Exception(status.message ?? '서버 오류'));
              }
            }

            _safeAddStatus(status);
            return;
          }

          // 분석 결과 메시지 처리
          // 실제 서버 응답 로그 출력 (디버깅)
          if (data.containsKey('heart_rate') || data.containsKey('bvp')) {
            print('[WS] 원본 데이터: heart_rate=${data['heart_rate']} (타입: ${data['heart_rate']?.runtimeType}), bvp=${data['bvp']} (타입: ${data['bvp']?.runtimeType})');
          }
          
          final result = ServerResult.fromJson(data);
          if (result.heartRate != null) {
            print('[WS] HR 수신: ${result.heartRate} BPM (프레임: ${result.frame})');
          } else {
            print('[WS] HR이 null입니다. 원본: ${data['heart_rate']}');
          }
          if (result.bvp != null && result.bvp != 0.0) {
            print('[WS] BVP 수신: ${result.bvp}');
          }
          _safeAddResult(result);
        } catch (e) {
          print('[WS] 메시지 파싱 오류: $e');
          _safeAddError('메시지 파싱 오류: $e');
        }
      },
      onError: (e) {
        print('[WS] WebSocket 오류: $e');
        _safeAddError('WebSocket 오류: $e');
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
      onDone: () {
        print('[WS] WebSocket 연결 종료');
        _isStreaming = false;
        if (!connectionEstablished) {
          _safeAddError('WebSocket 연결이 종료되었습니다.');
        }
      },
      cancelOnError: false,
    );

    // 스트리밍 시작 요청 전송
    final startMsg = {
      "action": "start_streaming",
      "fps": fps,
    };
    print('[WS] start_streaming 요청 전송 (FPS: $fps)');
    _channel!.sink.add(jsonEncode(startMsg));

    // 서버 응답 대기 (타임아웃: 10초)
    try {
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[WS] 서버 응답 대기 시간 초과');
          throw TimeoutException('서버 응답 대기 시간 초과');
        },
      );
      print('[WS] 연결 완료');
    } catch (e) {
      print('[WS] 연결 실패: $e');
      await _subscription?.cancel();
      _subscription = null;
      try {
        await _channel?.sink.close();
      } catch (_) {
        // 이미 닫혔으면 무시
      }
      _channel = null;
      rethrow;
    }
  }

  /// JPEG 바이너리 전송 (서버 권장 방식)
  /// 스트리밍이 시작된 후에만 전송 가능
  void sendFrameBinary(Uint8List jpegBytes) {
    if (!_isStreaming) {
      _safeAddError('스트리밍이 시작되지 않았습니다.');
      return;
    }
    try {
      _channel?.sink.add(jpegBytes);
    } catch (e) {
      print('[WS] 프레임 전송 오류: $e');
      _safeAddError('프레임 전송 오류: $e');
    }
  }

  /// JSON 방식으로 프레임 전송 (base64 인코딩)
  void sendFrameJson(String base64FrameData) {
    if (!_isStreaming) {
      _safeAddError('스트리밍이 시작되지 않았습니다.');
      return;
    }
    final msg = {
      "action": "frame",
      "frame_data": base64FrameData,
    };
    _channel?.sink.add(jsonEncode(msg));
  }

  /// 스트리밍 중지
  void stop() {
    if (!_isStreaming) return;
    _channel?.sink.add(jsonEncode({"action": "stop_streaming"}));
  }

  Future<void> close() async {
    stop();
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // 이미 닫혔으면 무시
    }
    _channel = null;
    _isStreaming = false;
    await _resultCtrl.close();
    await _statusCtrl.close();
    await _errorCtrl.close();
  }
}
