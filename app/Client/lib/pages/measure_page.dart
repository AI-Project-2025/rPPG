import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/hr_simulator.dart';
import '../state/measure_controller.dart';
import '../utils/stats.dart';
import 'result_page.dart';

class MeasurePage extends StatefulWidget {
  const MeasurePage({super.key});

  @override
  State<MeasurePage> createState() => _MeasurePageState();
}

class _MeasurePageState extends State<MeasurePage> {
  final MeasureController controller = MeasureController();
  final HrSimulator hrEngine = HrSimulator();

  CameraController? cam;

  bool _processing = false;
  DateTime _lastInfer = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _measureTimer;
  Timer? _tickTimer;

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
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final preview = CameraPreview(cam!);
    final size = cam!.value.previewSize;
    if (size == null) return preview;

    final previewW = size.height;
    final previewH = size.width;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewW,
            height: previewH,
            child: preview,
          ),
        ),
      ),
    );
  }

  Future<void> _startMeasuring() async {
    if (cam == null || cam!.value.isInitialized != true) return;
    if (controller.state == MeasureState.measuring) return;

    controller.start(durationSeconds: measureDurationSeconds);

    await WakelockPlus.enable();

    _tickTimer?.cancel();
    _tickTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => controller.tick());

    _measureTimer?.cancel();
    _measureTimer = Timer(const Duration(seconds: measureDurationSeconds),
            () async {
          if (controller.state == MeasureState.measuring) {
            await _stopAndFinalize();
          }
        });

    await cam!.startImageStream((CameraImage image) async {
      if (controller.state != MeasureState.measuring) return;

      final now = DateTime.now();
      if (now.difference(_lastInfer).inMilliseconds < 100) return;
      _lastInfer = now;

      if (_processing) return;
      _processing = true;

      try {
        // ======= 여기서 TFLite 모델 추론으로 교체 =======
        final result = hrEngine.infer(image, now);
        controller.updateLiveHr(result.hr, quality: result.quality);
        // ==============================================
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

    await WakelockPlus.disable();
  }

  void _onButtonPressed() {
    switch (controller.state) {
      case MeasureState.idle:
        _startMeasuring();
        break;
      case MeasureState.measuring:
        break;
      case MeasureState.completed:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultPage(
              avgHr: controller.avgHr ?? 0.0,
              stressIndex: controller.stressIndex ?? 0.0,
            ),
          ),
        );
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
    final safePadding = MediaQuery.of(context).padding;

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final measuring = controller.state == MeasureState.measuring;

        final buttonText = switch (controller.state) {
          MeasureState.idle => '측정 시작',
          MeasureState.measuring => '측정중',
          MeasureState.completed => '결과 보기',
        };

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenW = constraints.maxWidth;
                final cameraH = screenW * (4 / 3); // 3:4
                final totalH = constraints.maxHeight;

                final remainingH = (totalH - cameraH).clamp(0.0, totalH);
                final bottomSafe = safePadding.bottom;

                return Column(
                  children: [
                    // 상단 카메라
                    SizedBox(
                      width: double.infinity,
                      height: cameraH,
                      child: Stack(
                        children: [
                          Positioned.fill(child: _buildCameraArea()),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                color: Colors.black.withOpacity(0.15),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 12,
                            child: Column(
                              children: [
                                _QualityDots(value: controller.quality),
                                const SizedBox(height: 10),
                                if (measuring)
                                  Text(
                                    '남은 시간: ${controller.remainingSeconds}s',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 하단 여백 영역: "그냥 하얀 배경" + 스크롤 없음
                    SizedBox(
                      width: double.infinity,
                      height: remainingH,
                      child: Container(
                        color: Colors.white,
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 12,
                          bottom: 12 + bottomSafe,
                        ),
                        child: AbsorbPointer(
                          absorbing: measuring, // 측정 중 터치 비활성
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 위쪽은 여유 공간, 패널은 아래로 붙임
                              const Spacer(),

                              // HR 표시 (추가 형태 없이)
                              Row(
                                children: [
                                  _MetricBox(
                                    title: 'PULSE',
                                    value: controller.liveHr == null
                                        ? '--'
                                        : controller.liveHr!.toStringAsFixed(0),
                                    unit: 'bpm',
                                  ),
                                  _MetricBox(
                                    title: 'STATE',
                                    value: measuring ? 'MEAS' : 'READY',
                                    unit: '',
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // 버튼
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  onPressed:
                                  measuring ? null : _onButtonPressed,
                                  child: Text(
                                    buttonText,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),

                              if (controller.state == MeasureState.idle) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  '버튼을 누르면 30초간 측정합니다.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _QualityDots extends StatelessWidget {
  final int value; // 0~5
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

class _MetricBox extends StatelessWidget {
  final String title;
  final String value;
  final String unit;

  const _MetricBox({
    required this.title,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(10),
        // 형태 제거 요청이 "패널 배경"에 대한 것이었으므로,
        // 지표 영역은 최소한의 구분만 유지(완전 제거 원하면 decoration/색도 없앨 수 있음)
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 6),
                Text(
                  unit,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
