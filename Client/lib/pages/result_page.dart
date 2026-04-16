import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ans_balance_detail_page.dart';
import 'recovery_detail_page.dart';
import 'signal_quality_detail_page.dart';
import 'stress_detail_page.dart';
import '../widgets/adaptive_phone_canvas.dart';

class DataExtractionResultScreen extends StatelessWidget {
  final double avgHr;
  final double stressIndex;

  const DataExtractionResultScreen({
    super.key,
    required this.avgHr,
    required this.stressIndex,
  });

  double get _stressScore => (stressIndex * 25).clamp(0, 100);
  double get _recoveryScore => (100 - _stressScore).clamp(0, 100);

  String get _stressLabel {
    if (_stressScore > 43) return '스트레스 상태';
    return '안정 상태';
  }

  String get _recoveryLabel {
    if (_recoveryScore >= 80) return '최상의 컨디션';
    if (_recoveryScore >= 60) return '좋은 회복력';
    if (_recoveryScore >= 40) return '일반적인 활력 수준';
    if (_recoveryScore >= 20) return '회복력 저하 및 피로 누적';
    return '극도의 피로 및 방전';
  }

  String get _ansStateLabel {
    if (_stressScore >= 80) return '극심한 스트레스 및 긴장 상태';
    if (_stressScore >= 60) return '가벼운 스트레스 및 집중 상태';
    if (_stressScore >= 40) return '최적의 자율신경 균형 상태';
    if (_stressScore >= 20) return '피로 누적 및 깊은 이완 상태';
    return '극심한 무기력 및 번아웃 상태';
  }

  @override
  Widget build(BuildContext context) {
    final ansMarkerX = (_stressScore / 100) * 318;
    final qualityScore5 = math.max(1, (5 - stressIndex).round());
    final qualityScore100 = qualityScore5 * 20;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF3F5),
      body: SafeArea(
        child: AdaptivePhoneCanvas(
          child: SizedBox(
            width: 390,
            height: 844,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(color: const Color(0xFFEEF3F5)),
                ),
                Positioned(
                  left: 14,
                  top: 55,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.chevron_left, size: 24),
                  ),
                ),
                const Positioned(
                  left: 52,
                  top: 44,
                  child: SizedBox(
                    width: 185,
                    height: 36,
                    child: Text(
                      '건강 리포트',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 116,
                  child: SizedBox(
                    width: 370,
                    height: 688,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 1,
                          child: _MiniCard(
                            title: '신호 품질',
                            value: '$qualityScore100',
                            unit: '점',
                            info: true,
                            onInfoTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SignalQualityDetailScreen(
                                    qualityScore: qualityScore5,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          left: 185,
                          top: 1,
                          child: _MiniCard(
                            title: '평균 심박수',
                            value: avgHr.toStringAsFixed(0),
                            unit: 'BPM',
                          ),
                        ),
                        Positioned(
                          left: 1,
                          top: 105,
                          child: _LargeMetricCard(
                            icon: Icons.self_improvement,
                            title: '스트레스',
                            score: _stressScore.toStringAsFixed(0),
                            label: _stressLabel,
                            onInfoTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StressDetailScreen(
                                    stressScore: _stressScore.round().clamp(0, 100),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          left: 1,
                          top: 254,
                          child: _LargeMetricCard(
                            icon: Icons.monitor_heart_outlined,
                            title: '스트레스 회복력',
                            score: _recoveryScore.toStringAsFixed(0),
                            label: _recoveryLabel,
                            onInfoTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RecoveryDetailScreen(
                                    recoveryScore: _recoveryScore.round().clamp(0, 100),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 402,
                          child: _AnsCard(
                            markerX: ansMarkerX,
                            stateLabel: _ansStateLabel,
                            onInfoTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AnsBalanceDetailScreen(
                                    ansScore: (100 - _stressScore).round().clamp(0, 100),
                                  ),
                                ),
                              );
                            },
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
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final bool info;
  final VoidCallback? onInfoTap;

  const _MiniCard({
    required this.title,
    required this.value,
    required this.unit,
    this.info = false,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 185,
      height: 104,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 180,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFEAEAEA), Color(0xFFCED2D9)],
                  stops: [0.1202, 0.7692, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 9,
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          if (info)
            Positioned(
              left: 146,
              top: 2,
              child: IconButton(
                onPressed: onInfoTap,
                splashRadius: 14,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.info_outline, size: 16),
              ),
            ),
          Positioned(
            left: 10,
            top: 36,
            child: SizedBox(
              width: 159,
              height: 64,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 14,
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Positioned(
                    left: 132,
                    top: 32,
                    child: Text(
                      unit,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String score;
  final String label;
  final VoidCallback? onInfoTap;

  const _LargeMetricCard({
    required this.icon,
    required this.title,
    required this.score,
    required this.label,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 368,
      height: 149,
      child: Stack(
        children: [
          Positioned(
            top: 16,
            child: Container(
              width: 368,
              height: 123,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFEAEAEA), Color(0xFFCED2D9)],
                  stops: [0.1202, 0.7692, 1.0],
                ),
              ),
            ),
          ),
          Positioned(left: 8, top: 22, child: Icon(icon, size: 24)),
          Positioned(
            left: 40,
            top: 26,
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Positioned(
            left: 332,
            top: 20,
            child: IconButton(
              onPressed: onInfoTap,
              splashRadius: 14,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.info_outline, size: 16),
            ),
          ),
          Positioned(
            left: 28,
            top: 90,
            child: Text(
              score,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
          ),
          Positioned(
            right: 0,
            top: 106,
            width: 120,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF00D0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnsCard extends StatelessWidget {
  final double markerX;
  final String stateLabel;
  final VoidCallback? onInfoTap;

  const _AnsCard({
    required this.markerX,
    required this.stateLabel,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final clampedX = markerX.clamp(0, 318);

    return SizedBox(
      width: 368,
      height: 149,
      child: Stack(
        children: [
          Positioned(
            top: 16,
            child: Container(
              width: 368,
              height: 123,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFEAEAEA), Color(0xFFCED2D9)],
                  stops: [0.1202, 0.7692, 1.0],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 16,
            top: 26,
            child: Text(
              '자율신경 균형도(ANS)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Positioned(
            left: 332,
            top: 20,
            child: IconButton(
              onPressed: onInfoTap,
              splashRadius: 14,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.info_outline, size: 16),
            ),
          ),
          Positioned(
            left: 20,
            top: 61,
            child: SizedBox(
              width: 326,
              height: 36,
              child: Stack(
                children: [
                  Positioned(
                    left: 4,
                    top: 7,
                    child: Container(
                      width: 318,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2DBE3),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [
                          BoxShadow(
                            offset: Offset(0, 2),
                            blurRadius: 0.8,
                            color: Color.fromRGBO(0, 0, 0, 0.13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    top: 7,
                    child: Container(
                      width: 318,
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF61AFEE), Color(0xFF75F2C0), Color(0xFFB657F5)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4 + clampedX - 3,
                    top: 4,
                    child: Container(
                      width: 6,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    top: 22,
                    child: Text(
                      '부교감(이완)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF72B1B3),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 272,
                    top: 21,
                    child: Text(
                      '교감(긴장)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD35252),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 99,
            child: Text(
              stateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF00E6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
