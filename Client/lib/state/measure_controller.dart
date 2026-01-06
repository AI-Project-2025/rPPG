import 'package:flutter/foundation.dart';

enum MeasureState { idle, measuring, completed }

class MeasureController extends ChangeNotifier {
  MeasureState state = MeasureState.idle;

  double? liveHr;
  final List<double> hrSamples = [];

  double? avgHr;
  double? stressIndex; // 0~4 (MVP)
  int quality = 0; // 0~5

  int remainingSeconds = 0;

  void reset() {
    state = MeasureState.idle;
    liveHr = null;
    hrSamples.clear();
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

  void complete({required double avgHr, required double stressIndex}) {
    this.avgHr = avgHr;
    this.stressIndex = stressIndex;
    state = MeasureState.completed;
    remainingSeconds = 0;
    notifyListeners();
  }
}

