import 'package:flutter/foundation.dart';

enum MeasureState { idle, measuring, completed }

class MeasureController extends ChangeNotifier {
  MeasureState state = MeasureState.idle;

  double? liveHr;
  final List<double> hrSamples = [];

  double? avgHr;
  double? stressIndex; // 0~4 (MVP)

  int remainingSeconds = 0;

  void reset() {
    state = MeasureState.idle;
    liveHr = null;
    hrSamples.clear();
    avgHr = null;
    stressIndex = null;
    remainingSeconds = 0;
    notifyListeners();
  }

  void start({required int durationSeconds}) {
    state = MeasureState.measuring;
    liveHr = null;
    hrSamples.clear();
    avgHr = null;
    stressIndex = null;
    remainingSeconds = durationSeconds;
    notifyListeners();
  }

  void tick() {
    if (state != MeasureState.measuring) return;
    if (remainingSeconds > 0) remainingSeconds--;
    notifyListeners();
  }

  void updateLiveHr(double hr) {
    if (state != MeasureState.measuring) return;
    liveHr = hr;
    hrSamples.add(hr);
    notifyListeners();
  }

  void complete({required double avgHr, required double stressIndex}) {
    this.avgHr = avgHr;
    this.stressIndex = stressIndex;
    state = MeasureState.completed;
    remainingSeconds = 0;
    notifyListeners();
  }
}

