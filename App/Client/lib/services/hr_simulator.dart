import 'dart:math';
import 'package:camera/camera.dart';

class HrSimulatorResult {
  final double hr;
  final int quality; // 0~5
  HrSimulatorResult({required this.hr, required this.quality});
}

class HrSimulator {
  final Random _rng = Random();

  int estimateQualityFromFrame(CameraImage image) {
    final plane = image.planes[0];
    final bytes = plane.bytes;

    const step = 1000;
    int count = 0;
    int sum = 0;

    for (int i = 0; i < bytes.length; i += step) {
      sum += bytes[i];
      count++;
      if (count >= 200) break;
    }
    if (count == 0) return 0;

    final avgY = sum / count; // 0~255

    if (avgY < 40 || avgY > 220) return 1;
    if (avgY < 60 || avgY > 200) return 2;
    if (avgY < 80 || avgY > 190) return 3;
    if (avgY < 100 || avgY > 180) return 4;
    return 5;
  }

  HrSimulatorResult infer(CameraImage image, DateTime now) {
    final q = estimateQualityFromFrame(image);

    final t = now.millisecondsSinceEpoch / 1000.0;
    final base = 78.0 + 6.0 * sin(t * 1.3);
    final noise = (_rng.nextDouble() - 0.5) * (q >= 4 ? 2.0 : 6.0);

    final hr = (base + noise).clamp(50.0, 130.0);
    return HrSimulatorResult(hr: hr, quality: q);
  }
}
