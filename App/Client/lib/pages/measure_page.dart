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
import 'result_page.dart';

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

  CameraController? cam;

  bool _processing = false;
  DateTime _lastInfer = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _sendIntervalMs = 33; // 전송 FPS 약 30

  Timer? _measureTimer;
  Timer? _tickTimer;
  bool _navigatedToResult = false;

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

    // 30초 종료 시점과 report_ready 전송 시점이 거의 겹쳐 레이스가 날 수 있다.
    // 서버 점수를 우선 사용하기 위해 짧게 대기 후 종료한다.
    if (_serverReport == null) {
      final waitUntil = DateTime.now().add(const Duration(milliseconds: 1800));
      while (_serverReport == null && DateTime.now().isBefore(waitUntil)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    _serverClient.stopStreaming();
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
    _goToResult(serverReport: _serverReport);

    await WakelockPlus.disable();
  }

  void _goToResult({Map<String, dynamic>? serverReport}) {
    if (!mounted || _navigatedToResult) return;
    _navigatedToResult = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DataExtractionResultScreen(
          avgHr: controller.avgHr ?? 0.0,
          stressIndex: controller.stressIndex ?? 0.0,
          serverReport: serverReport,
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
        _goToResult();
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
        controller.updateLiveHr(
          hr,
          quality: _qualityFromSignalStrength(data.signalStrength),
        );
      }

      // 성능 최적화 + 반영 안정성:
      // 1) bvp 단일 샘플 우선
      // 2) bvp가 없으면 rppg_signal 마지막 샘플을 즉시 반영
      final bvp = data.bvp;
      if (bvp != null) {
        controller.appendRppgSample(bvp);
      } else if (data.rppgSignal != null && data.rppgSignal!.isNotEmpty) {
        controller.appendRppgSample(data.rppgSignal!.last);
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
    });
  }

  int _qualityFromSignalStrength(double? strength) {
    if (strength == null) return 0;
    if (strength >= 1.2) return 5;
    if (strength >= 0.9) return 4;
    if (strength >= 0.6) return 3;
    if (strength >= 0.3) return 2;
    return 1;
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
          MeasureState.completed => '결과 보기',
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
                                _QualityDots(value: controller.quality),
                                const SizedBox(height: 8),
                                if (measuring)
                                  Text(
                                    '남은 시간: ${controller.remainingSeconds}s',
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

                  // 정보
                  Positioned(
                    left: 0,
                    top: 552,
                    child: SizedBox(
                      width: 390,
                      height: 231,
                      child: Stack(
                        children: [
                          // 파형 박스
                          Positioned(
                            left: 4,
                            top: 4,
                            child: Container(
                              width: 382,
                              height: 99,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFF6F8F9),
                                    Color(0xFFF6F8F8),
                                    Color(0xFFE2E3E4),
                                  ],
                                  stops: [0.4471, 0.5982, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(0, 0, 0, 0.12),
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                child: _SignalWaveform(samples: controller.rppgSamples),
                              ),
                            ),
                          ),

                          // 상태 및 심박수
                          Positioned(
                            left: 0,
                            top: 117,
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
                      height: 52,
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

class _QualityDots extends StatelessWidget {
  final int value;
  const _QualityDots({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final on = i < value;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? const Color(0xFF2ECC71) : Colors.white38,
          ),
        );
      }),
    );
  }
}

class _SignalWaveform extends StatelessWidget {
  final List<double> samples;

  const _SignalWaveform({required this.samples});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SignalWavePainter(samples: samples),
      child: const SizedBox.expand(),
    );
  }
}

class _SignalWavePainter extends CustomPainter {
  final List<double> samples;
  static const int _displayWindowSamples = 20; // 약 2초(전송 주기 100ms 기준)

  _SignalWavePainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    final baselineY = size.height / 2;

    final axisPaint = Paint()
      ..color = const Color(0xFFB6BEC8)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      axisPaint,
    );

    if (samples.isEmpty) return;

    final points = samples.length > _displayWindowSamples
        ? samples.sublist(samples.length - _displayWindowSamples)
        : samples;
    final normalizedPoints = _normalizeForWave(points);

    final path = Path();
    final amp = size.height * 0.33;
    final dx = normalizedPoints.length > 1
        ? size.width / (normalizedPoints.length - 1)
        : size.width;

    for (int i = 0; i < normalizedPoints.length; i++) {
      final x = i * dx;
      final y = baselineY - (normalizedPoints[i] * amp);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final wavePaint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, wavePaint);
  }

  List<double> _normalizeForWave(List<double> values) {
    if (values.isEmpty) return const [];
    if (values.length == 1) return const [0.0];

    final sorted = List<double>.from(values)..sort();
    final q1 = _percentile(sorted, 0.25);
    final q2 = _percentile(sorted, 0.50); // median
    final q3 = _percentile(sorted, 0.75);
    final iqr = (q3 - q1).abs();

    // 이상치가 스케일을 망가뜨리지 않도록 IQR 기반으로 완만하게 절단
    final lower = q1 - (1.5 * iqr);
    final upper = q3 + (1.5 * iqr);
    final clipped = values.map((v) => v.clamp(lower, upper).toDouble()).toList();

    // 중앙값 기준 zero-center
    final centered = clipped.map((v) => v - q2).toList();
    double maxAbs = 0.0;
    for (final v in centered) {
      final a = v.abs();
      if (a > maxAbs) maxAbs = a;
    }

    if (maxAbs < 1e-6) {
      return List<double>.filled(values.length, 0.0);
    }
    return centered.map((v) => (v / maxAbs).clamp(-1.0, 1.0)).toList();
  }

  double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0.0;
    final rank = p.clamp(0.0, 1.0) * (sorted.length - 1);
    final low = rank.floor();
    final high = rank.ceil();
    if (low == high) return sorted[low];
    final t = rank - low;
    return sorted[low] * (1.0 - t) + sorted[high] * t;
  }

  @override
  bool shouldRepaint(covariant _SignalWavePainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}
