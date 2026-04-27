import 'package:flutter/foundation.dart';

enum MeasureState { idle, measuring, completed }

class MeasureController extends ChangeNotifier {
  static const int _maxRppgSamples = 300;
  MeasureState state = MeasureState.idle;

  double? liveHr;
  final List<double> hrSamples = [];
  final List<double> rppgSamples = [];

  double? avgHr;
  double? stressIndex; // 0~4 (MVP)
  int quality = 0; // 0~5

  int remainingSeconds = 0;
  int _rppgNotifySkip = 0;

  void reset() {
    state = MeasureState.idle;
    liveHr = null;
    hrSamples.clear();
    rppgSamples.clear();
    avgHr = null;
    stressIndex = null;
    quality = 0;
    remainingSeconds = 0;
    notifyListeners();
  }

  void start({required int durationSeconds}) {
    state = MeasureState.measuring;
    liveHr = null;
    hrSamples.clear();
    rppgSamples.clear();
    avgHr = null;
    stressIndex = null;
    quality = 0;
    remainingSeconds = durationSeconds;
    notifyListeners();
  }

  void tick() {
    if (state != MeasureState.measuring) return;
    if (remainingSeconds > 0) remainingSeconds--;
    notifyListeners();
  }

  void updateLiveHr(double hr, {required int quality}) {
    if (state != MeasureState.measuring) return;
    liveHr = hr;
    hrSamples.add(hr);
    this.quality = quality;
    notifyListeners();
  }

  void updateRppg(List<double> samples) {
    if (state != MeasureState.measuring) return;
    if (samples.isEmpty) return;
    final start = samples.length > _maxRppgSamples ? samples.length - _maxRppgSamples : 0;
    rppgSamples
      ..clear()
      ..addAll(samples.sublist(start));
    _rppgNotifySkip = (_rppgNotifySkip + 1) % 3;
    if (_rppgNotifySkip == 0) {
      notifyListeners();
    }
  }

  void appendRppgSample(double sample) {
    if (state != MeasureState.measuring) return;
    rppgSamples.add(sample);
    if (rppgSamples.length > _maxRppgSamples) {
      rppgSamples.removeAt(0);
    }
    _rppgNotifySkip = (_rppgNotifySkip + 1) % 3;
    if (_rppgNotifySkip == 0) {
      notifyListeners();
    }
  }

  void complete({required double avgHr, required double stressIndex}) {
    this.avgHr = avgHr;
    this.stressIndex = stressIndex;
    state = MeasureState.completed;
    remainingSeconds = 0;
    notifyListeners();
  }
}

