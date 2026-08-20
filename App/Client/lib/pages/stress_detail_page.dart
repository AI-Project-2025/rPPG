import 'package:flutter/material.dart';

import '../widgets/adaptive_phone_canvas.dart';
import '../widgets/rppg_waveform_chart.dart';
import 'ppg_stress_simulator_page.dart';

/// 스트레스 점수(0~100) 3구간 분류.
enum StressResultTier {
  /// 0~33
  stable,

  /// 34~66
  suspected,

  /// 67~100
  high,
}

StressResultTier stressTierFromScore(int score) {
  final s = score.clamp(0, 100);
  if (s <= 33) return StressResultTier.stable;
  if (s <= 66) return StressResultTier.suspected;
  return StressResultTier.high;
}

extension StressResultTierDisplay on StressResultTier {
  String get title => switch (this) {
        StressResultTier.stable => '안정',
        StressResultTier.suspected => '스트레스 의심',
        StressResultTier.high => '스트레스',
      };

  String get headerLabel => title;

  Color get accentColor => switch (this) {
        StressResultTier.stable => const Color(0xFF61F097),
        StressResultTier.suspected => const Color(0xFFF0EA3F),
        StressResultTier.high => const Color(0xFFF06161),
      };

  double get bodyFontSize => switch (this) {
        StressResultTier.high => 16,
        StressResultTier.suspected => 17,
        StressResultTier.stable => 17,
      };

  String get description => switch (this) {
        StressResultTier.high =>
          '높은 수준의 스트레스와 신체적 긴장 상태가 감지됩니다. 혼자서 감내하기보다는, 정확한 상태 파악과 심리적 안정을 위해 가까운 의료 기관(정신건강의학과)이나 전문 상담 센터에 방문하시어 진료를 받아보시기를 바랍니다.',
        StressResultTier.suspected =>
          '현재 약한 수준의 스트레스 반응이 감지되었습니다. 우선 충분한 휴식과 수면을 취하며 컨디션을 조절해 주세요. 예방 차원에서 전문가와 가벼운 상담을 받아보시는 것을 권장합니다.',
        StressResultTier.stable =>
          '차분하고 안정적인 상태를 유지하고 있습니다. 과도한 긴장 없이 편안하게 일에 집중하기 좋은 컨디션입니다.',
      };
}

class StressDetailScreen extends StatelessWidget {
  final int stressScore;
  final List<double> rppgPreprocessedLast5s;

  const StressDetailScreen({
    super.key,
    required this.stressScore,
    this.rppgPreprocessedLast5s = const [],
  });

  StressResultTier get _tier => stressTierFromScore(stressScore);

  @override
  Widget build(BuildContext context) {
    final score = stressScore.clamp(0, 100);
    return Scaffold(
      backgroundColor: const Color(0xFFEEF3F5),
      body: SafeArea(
        child: AdaptivePhoneCanvas(
          child: SizedBox(
            width: 390,
            height: 844,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 8, 13, 16),
              child: Column(
                children: [
                  Expanded(
                    child: _PreprocessedRppgSection(
                      samples: rppgPreprocessedLast5s,
                      onOpenSimulator: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PpgStressSimulatorPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: _StressTierCard(tier: _tier),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _ScoreResultPanel(
                      score: score,
                      currentTier: _tier,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreprocessedRppgSection extends StatelessWidget {
  static const Color _rppgLineColor = Color(0xFFE53935);

  final List<double> samples;
  final VoidCallback onOpenSimulator;

  const _PreprocessedRppgSection({
    required this.samples,
    required this.onOpenSimulator,
  });

  @override
  Widget build(BuildContext context) {
    final hasSignal = samples.length >= 2;

    final content = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  '전처리 rPPG',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 16,
                color: Color(0xFF64748B),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasSignal
                  ? RppgWaveformChart(
                      samples: samples,
                      lineColor: _rppgLineColor,
                    )
                  : Container(
                      color: const Color(0xFFF8FAFC),
                      alignment: Alignment.center,
                      child: const Text(
                        '신호 데이터 없음',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenSimulator,
        borderRadius: BorderRadius.circular(18),
        child: content,
      ),
    );
  }
}

class _ScoreResultPanel extends StatelessWidget {
  final int score;
  final StressResultTier currentTier;

  const _ScoreResultPanel({
    required this.score,
    required this.currentTier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '스트레스 점수',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${currentTier.headerLabel} · $score점',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: _ScoreStatusBar(
                score: score,
                min: 0,
                max: 100,
                accentColor: currentTier.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreStatusBar extends StatelessWidget {
  final int score;
  final int min;
  final int max;
  final Color accentColor;

  const _ScoreStatusBar({
    required this.score,
    this.min = 0,
    this.max = 100,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final minV = min;
    final maxV = max <= minV ? minV + 1 : max;
    final s = score.clamp(minV, maxV);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final range = (maxV - minV).toDouble();
        final t = (w <= 0 || range <= 0) ? 0.0 : ((s - minV) / range);
        final markerX = (w * t).clamp(0.0, w);

        // 바 두께(기존 대비 2배 수준)
        const barTop = 16.0;
        const barBottom = 16.0;
        final barHeight = 64 - barTop - barBottom; // 실제 바 두께(px)
        final markerSize = (barHeight - 4).clamp(14.0, barHeight); // 바 규격에 맞춘 원
        const scoreLabelWidth = 62.0;

        return SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 바
              Positioned.fill(
                top: barTop,
                bottom: barBottom,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    decoration: const BoxDecoration(
                      // 입체감: 살짝 밝->어두운 세로 그라데이션
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFF3F4F6),
                          Color(0xFFE5E7EB),
                          Color(0xFFD1D5DB),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 채워진 부분(점수)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: t,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    accentColor.withValues(alpha: 0.95),
                                    accentColor.withValues(alpha: 0.78),
                                    accentColor.withValues(alpha: 0.92),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 구간 구분선 (0~33 / 34~66 / 67~100)
                        Positioned(
                          left: w * 0.33,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        Positioned(
                          left: w * 0.66,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        // 하이라이트 라인 (상단 광택)
                        Positioned.fill(
                          top: 2,
                          bottom: null,
                          child: Container(
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 점수 텍스트 (바 상단, 마커 x축에 정렬)
              Positioned(
                left: (markerX - (scoreLabelWidth / 2)).clamp(0.0, (w - scoreLabelWidth).clamp(0.0, w)),
                top: 0,
                child: Container(
                  width: scoreLabelWidth,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$s점',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              // 마커 (바 내부)
              Positioned(
                left: (markerX - (markerSize / 2)).clamp(0.0, (w - markerSize).clamp(0.0, w)),
                top: barTop + (barHeight - markerSize) / 2,
                child: Container(
                  width: markerSize,
                  height: markerSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF111827), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.22),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              // 스케일 라벨 (min/max)
              Positioned(
                left: 0,
                bottom: 0,
                child: Text(
                  '$minV',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Text(
                  '$maxV',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StressTierCard extends StatelessWidget {
  final StressResultTier tier;

  const _StressTierCard({
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            decoration: ShapeDecoration(
              gradient: const LinearGradient(
                begin: Alignment(0.5, 0),
                end: Alignment(0.5, 1),
                colors: [
                  Color(0xFFF2F4F8),
                  Color(0xFFEDEDED),
                  Color(0xFFE2E8EA),
                ],
              ),
              shape: RoundedRectangleBorder(
                side: const BorderSide(
                  width: 2,
                  color: Color(0xFF2563EB),
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x6D000000),
                  blurRadius: 2.8,
                  offset: Offset(-1, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 42),
                      Expanded(
                        child: Text(
                          tier.title,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '내 결과',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tier.description,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: tier.bodyFontSize,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 28,
          child: Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: tier.accentColor,
              shape: const OvalBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
