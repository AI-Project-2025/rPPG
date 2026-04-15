import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/hr_simulator.dart';
import '../state/measure_controller.dart';
import '../utils/stats.dart';
import '../widgets/adaptive_phone_canvas.dart';
import 'result_page.dart';

class DataExtractionScreen extends StatefulWidget {
  const DataExtractionScreen({super.key});

  @override
  State<DataExtractionScreen> createState() => _DataExtractionScreenState();
}

class _DataExtractionScreenState extends State<DataExtractionScreen> {
  final MeasureController controller = MeasureController();
  final HrSimulator hrEngine = HrSimulator();

  CameraController? cam;

  bool _processing = false;
  DateTime _lastInfer = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _measureTimer;
  Timer? _tickTimer;
  bool _navigatedToResult = false;

  static const int measureDurationSeconds = 30;

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

    await cam!.startImageStream((CameraImage image) async {
      if (controller.state != MeasureState.measuring) return;

      final now = DateTime.now();
      if (now.difference(_lastInfer).inMilliseconds < 100) return;
      _lastInfer = now;

      if (_processing) return;
      _processing = true;

      try {
        final result = hrEngine.infer(image, now);
        controller.updateLiveHr(result.hr, quality: result.quality);
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

    final samples = List<double>.from(controller.hrSamples);
    final avg = mean(samples);
    final stress = stressIndexFromHrSamples(samples, scaleStdDev: 10.0);

    controller.complete(avgHr: avg, stressIndex: stress);
    _goToResult();

    await WakelockPlus.disable();
  }

  void _goToResult() {
    if (!mounted || _navigatedToResult) return;
    _navigatedToResult = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DataExtractionResultScreen(
          avgHr: controller.avgHr ?? 0.0,
          stressIndex: controller.stressIndex ?? 0.0,
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
    cam?.dispose();
    controller.dispose();
    super.dispose();
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
                                child: _SignalWaveform(samples: controller.hrSamples),
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

    final points = samples.length > 90 ? samples.sublist(samples.length - 90) : samples;
    double minV = points.first;
    double maxV = points.first;
    for (final v in points) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }

    final path = Path();
    final span = (maxV - minV).abs();
    final amp = size.height * 0.33;
    final dx = points.length > 1 ? size.width / (points.length - 1) : size.width;

    for (int i = 0; i < points.length; i++) {
      final x = i * dx;
      final normalized = span < 0.0001 ? 0.0 : ((points[i] - minV) / span) * 2 - 1;
      final y = baselineY - (normalized * amp);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final wavePaint = Paint()
      ..color = const Color(0xFF2E7BEA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _SignalWavePainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}
