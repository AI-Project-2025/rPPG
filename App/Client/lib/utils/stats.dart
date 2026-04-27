import 'dart:math';

double mean(List<double> values) {
  if (values.isEmpty) return 0.0;
  final sum = values.fold<double>(0.0, (a, b) => a + b);
  return sum / values.length;
}

double stdDev(List<double> values) {
  if (values.length < 2) return 0.0;
  final m = mean(values);
  final variance = values
      .map((x) => pow(x - m, 2))
      .fold<double>(0.0, (a, b) => a + b) /
      (values.length - 1);
  return sqrt(variance);
}

/// MVP 스트레스 지수(0~4): HR 변동성 기반.
/// 실제 제품화 시 HRV(IBI 기반)로 개선 권장.
double stressIndexFromHrSamples(List<double> hrSamples,
    {double scaleStdDev = 10.0}) {
  final s = stdDev(hrSamples);
  final raw = (s / scaleStdDev) * 4.0;
  return raw.clamp(0.0, 4.0);
}
