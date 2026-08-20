import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/rppg_server_client.dart';
import '../state/measure_controller.dart';
import '../utils/stats.dart';
import '../widgets/adaptive_phone_canvas.dart';
import '../widgets/rppg_waveform_chart.dart';
import 'stress_detail_page.dart';

class DataExtractionScreen extends StatefulWidget {
  final String serverBaseUrl;

  const DataExtractionScreen({
    super.key,
    required this.serverBaseUrl,
  });

  @override
  State<DataExtractionScreen> createState() => _DataExtractionScreenState();
}

class _DataExtractionScreenState extends State<DataExtractionScreen> {
  final MeasureController controller = MeasureController();
  final RppgServerClient _serverClient = RppgServerClient();
  StreamSubscription<StreamData>? _serverDataSub;
  StreamSubscription<String>? _serverErrorSub;
  StreamSubscription<ReportReadyData>? _serverReportSub;
  Map<String, dynamic>? _serverReport;
  List<double> _cachedRppgPreprocessedLast5s = [];

  CameraController? cam;

  bool _processing = false;
  DateTime _lastInfer = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _sendIntervalMs = 33; // 전송 FPS 약 30

  Timer? _measureTimer;
  Timer? _tickTimer;
  bool _navigatedToResult = false;

  /// 실시간 rPPG 슬라이딩 버퍼 (10초 @ 30fps).
  static const int _rppgSlidingWindowSamples = 300;
  final List<double> _rppgSamples = [];

  static const int measureDurationSeconds = 35;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final ok = await _requestCameraPermission();
    if (!ok) return;

    await _initCamera();
    if (mounted) setState(() {});
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    cam = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await cam!.initialize();
  }

  Widget _buildCameraArea() {
    final cameraReady = cam?.value.isInitialized == true;

    if (!cameraReady) {
      return Container(
        color: const Color(0xFFD2D2D2),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final preview = CameraPreview(cam!);
    final size = cam!.value.previewSize;

    if (size == null) return preview;

    final previewW = size.height;
    final previewH = size.width;

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewW,
          height: previewH,
          child: preview,
        ),
      ),
    );
  }

  Future<void> _startMeasuring() async {
    if (cam == null || cam!.value.isInitialized != true) return;
    if (controller.state == MeasureState.measuring) return;

    _navigatedToResult = false;
    setState(() => _rppgSamples.clear());
    controller.start(durationSeconds: measureDurationSeconds);

    await WakelockPlus.enable();

    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => controller.tick(),
    );

    _measureTimer?.cancel();
    _measureTimer = Timer(
      const Duration(seconds: measureDurationSeconds),
          () async {
        if (controller.state == MeasureState.measuring) {
          await _stopAndFinalize();
        }
      },
    );

    try {
      await _serverClient.connectWithBaseUrl(widget.serverBaseUrl);
      _serverClient.startStreaming(fps: 30);
      _bindServerStreams();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 연결 실패: 주소/서버 상태를 확인해주세요.')),
      );
      return;
    }

    await cam!.startImageStream((CameraImage image) async {
      if (controller.state != MeasureState.measuring) return;

      final now = DateTime.now();
      if (now.difference(_lastInfer).inMilliseconds < _sendIntervalMs) return;
      _lastInfer = now;

      if (_processing) return;
      _processing = true;

      try {
        final jpeg = _cameraImageToJpeg(image);
        if (jpeg != null) {
          _serverClient.sendFrameBase64(base64Encode(jpeg));
        }
      } finally {
        _processing = false;
      }
    });
  }

  Future<void> _stopAndFinalize() async {
    _measureTimer?.cancel();
    _tickTimer?.cancel();

    try {
      await cam?.stopImageStream();
    } catch (_) {}

    // stop_streaming 시 서버가 리포트를 보낸 뒤 연결을 끊는다.
    _serverClient.stopStreaming();
    final waitUntil = DateTime.now().add(const Duration(milliseconds: 3500));
    while (DateTime.now().isBefore(waitUntil)) {
      final rppgReady = _cachedRppgPreprocessedLast5s.length >= 2;
      final scoresReady = _serverReport?['scores'] is Map<String, dynamic>;
      if (rppgReady || scoresReady) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await _serverClient.disconnect();
    await _serverDataSub?.cancel();
    await _serverErrorSub?.cancel();
    await _serverReportSub?.cancel();
    _serverDataSub = null;
    _serverErrorSub = null;
    _serverReportSub = null;

    final reportScores = _serverReport?['scores'];
    final hasServerScores = reportScores is Map<String, dynamic>;
    final samples = List<double>.from(controller.hrSamples);
    final avg = hasServerScores
        ? ((reportScores['average_heart_rate'] as num?)?.toDouble() ?? mean(samples))
        : mean(samples);
    final stress = hasServerScores
        ? (((reportScores['stress_model'] as num?)?.toDouble() ?? 0.0) / 25.0)
        : stressIndexFromHrSamples(samples, scaleStdDev: 10.0);

    controller.complete(avgHr: avg, stressIndex: stress);
    _goToStressDetail(serverReport: _serverReport);

    await WakelockPlus.disable();
  }

  static const int _rppgDisplaySampleCount = 100;

  List<double> _rppgPreprocessedLast5s(Map<String, dynamic>? serverReport) {
    const maxSamples = _rppgDisplaySampleCount;
    if (_cachedRppgPreprocessedLast5s.length >= 2) {
      final cached = _cachedRppgPreprocessedLast5s;
      return cached.length <= maxSamples
          ? List<double>.from(cached)
          : cached.sublist(cached.length - maxSamples);
    }
    final raw = serverReport?['rppg_preprocessed_last_5s'] ??
        serverReport?['rppg_preprocessed_last_10s'];
    if (raw is! List) return const [];
    final parsed = raw
        .map((e) {
          if (e is num) return e.toDouble();
          return double.tryParse(e.toString()) ?? 0.0;
        })
        .where((v) => v.isFinite)
        .toList();
    if (parsed.length <= maxSamples) return parsed;
    return parsed.sublist(parsed.length - maxSamples);
  }

  int _stressScorePercent(Map<String, dynamic>? serverReport, double stressIndex) {
    final scores = serverReport?['scores'];
    if (scores is Map<String, dynamic>) {
      final m = scores['stress_model'];
      if (m is num) return m.round().clamp(0, 100);
    }
    return (stressIndex * 25).round().clamp(0, 100);
  }

  void _goToStressDetail({Map<String, dynamic>? serverReport}) {
    if (!mounted || _navigatedToResult) return;
    _navigatedToResult = true;
    final stressIdx = controller.stressIndex ?? 0.0;
    final score = _stressScorePercent(serverReport, stressIdx);
    final rppgLast5s = _rppgPreprocessedLast5s(serverReport);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StressDetailScreen(
          stressScore: score,
          rppgPreprocessedLast5s: rppgLast5s,
        ),
      ),
    );
  }

  void _onButtonPressed() {
    switch (controller.state) {
      case MeasureState.idle:
        _startMeasuring();
        break;
      case MeasureState.measuring:
        break;
      case MeasureState.completed:
        _goToStressDetail(serverReport: _serverReport);
        break;
    }
  }

  @override
  void dispose() {
    _measureTimer?.cancel();
    _tickTimer?.cancel();
    _serverDataSub?.cancel();
    _serverErrorSub?.cancel();
    _serverReportSub?.cancel();
    _serverClient.dispose();
    cam?.dispose();
    controller.dispose();
    super.dispose();
  }

  void _bindServerStreams() {
    _serverDataSub?.cancel();
    _serverErrorSub?.cancel();

    _serverDataSub = _serverClient.dataStream.listen((data) {
      if (!mounted || controller.state != MeasureState.measuring) return;

      final hr = data.heartRate;
      if (hr != null) {
        controller.updateLiveHr(hr);
      }

      final bvp = data.bvp;
      if (bvp != null && bvp.isFinite) {
        setState(() {
          _rppgSamples.add(bvp);
          if (_rppgSamples.length > _rppgSlidingWindowSamples) {
            _rppgSamples.removeAt(0);
          }
        });
      }
    });

    _serverErrorSub = _serverClient.errorStream.listen((err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    });

    _serverReportSub = _serverClient.reportStream.listen((data) {
      _serverReport = data.report;
      final raw = data.report['rppg_preprocessed_last_5s'] ??
          data.report['rppg_preprocessed_last_10s'];
      if (raw is List) {
        final parsed = raw.map((e) {
          if (e is num) return e.toDouble();
          return double.tryParse(e.toString()) ?? 0.0;
        }).where((v) => v.isFinite).toList();
        if (parsed.length >= 2) {
          _cachedRppgPreprocessedLast5s = parsed.length <= _rppgDisplaySampleCount
              ? parsed
              : parsed.sublist(parsed.length - _rppgDisplaySampleCount);
        }
      }
    });
  }

  Uint8List? _cameraImageToJpeg(CameraImage image) {
    // Android yuv420 -> RGB 변환 후 JPEG 인코딩
    if (image.format.group != ImageFormatGroup.yuv420 || image.planes.length < 3) {
      return null;
    }
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final out = img.Image(width: width, height: height);
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final yRowStride = yPlane.bytesPerRow;

    for (int y = 0; y < height; y++) {
      final yRow = y * yRowStride;
      final uvRow = (y >> 1) * uvRowStride;
      for (int x = 0; x < width; x++) {
        final yIndex = yRow + x;
        final uvIndex = uvRow + (x >> 1) * uvPixelStride;

        final yp = yPlane.bytes[yIndex].toDouble();
        final up = uPlane.bytes[uvIndex].toDouble() - 128.0;
        final vp = vPlane.bytes[uvIndex].toDouble() - 128.0;

        final r = (yp + 1.402 * vp).round().clamp(0, 255);
        final g = (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255);
        final b = (yp + 1.772 * up).round().clamp(0, 255);

        out.setPixelRgb(x, y, r, g, b);
      }
    }
    // 검출 안정성 우선: 과도한 중앙 크롭은 얼굴 위치가 조금만 틀어져도
    // 검출 실패율을 높일 수 있어 전체 프레임 기반으로 리사이즈한다.
    final resized = img.copyResize(
      out,
      width: 400,
      height: 300,
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final measuring = controller.state == MeasureState.measuring;

        final buttonText = switch (controller.state) {
          MeasureState.idle => '측정 시작',
          MeasureState.measuring => '측정중',
          MeasureState.completed => '스트레스 상세',
        };

        return Scaffold(
          backgroundColor: const Color(0xFFEEF3F5),
          body: AdaptivePhoneCanvas(
            child: SizedBox(
              width: 390,
              height: 844,
              child: Stack(
                children: [
                  // 카메라
                  Positioned(
                    left: 0,
                    top: 28,
                    child: SizedBox(
                      width: 390,
                      height: 525,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: const Color(0xFFD2D2D2),
                              child: _buildCameraArea(),
                            ),
                          ),

                          // 상단 상태 오버레이
                          Positioned(
                            top: 12,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Text(
                                  widget.serverBaseUrl,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                if (measuring)
                                  Text(
                                    '남은 시간: ${controller.remainingSeconds} sec',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 실시간 rPPG 파형 (서버 HTML 테스트 페이지의 drawRppg 와 동일 소스)
                  Positioned(
                    left: 12,
                    top: 556,
                    child: SizedBox(
                      width: 366,
                      height: 90,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.12),
                              offset: Offset(-2, 2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              measuring ? '실시간 rPPG' : 'rPPG',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _rppgSamples.length >= 2
                                    ? RppgWaveformChart(
                                        samples: _rppgSamples,
                                        fixedWindowSize: _rppgSlidingWindowSamples,
                                      )
                                    : Container(
                                        color: const Color(0xFFF8FAFC),
                                        alignment: Alignment.center,
                                        child: Text(
                                          measuring ? '신호 대기중…' : '측정 시작 후 표시',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 정보
                  Positioned(
                    left: 0,
                    top: 654,
                    child: SizedBox(
                      width: 390,
                      height: 118,
                      child: Stack(
                        children: [
                          // 상태 및 심박수
                          Positioned(
                            left: 0,
                            top: 4,
                            child: SizedBox(
                              width: 390,
                              height: 114,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 203,
                                    top: 5,
                                    child: Container(
                                      width: 182,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color.fromRGBO(0, 0, 0, 0.2),
                                            offset: Offset(-3, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '상태',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            measuring
                                                ? '측정중'
                                                : controller.state ==
                                                MeasureState.completed
                                                ? '완료'
                                                : '대기중',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  Positioned(
                                    left: 6,
                                    top: 5,
                                    child: Container(
                                      width: 182,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color.fromRGBO(0, 0, 0, 0.2),
                                            offset: Offset(-3, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '심박수',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          Row(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                controller.liveHr == null
                                                    ? '--'
                                                    : controller.liveHr!
                                                    .toStringAsFixed(0),
                                                style: const TextStyle(
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Padding(
                                                padding:
                                                EdgeInsets.only(bottom: 4),
                                                child: Text(
                                                  'bpm',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 하단 버튼
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: SizedBox(
                      height: 45,
                      child: ElevatedButton(
                        onPressed: measuring ? null : _onButtonPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
