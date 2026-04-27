import 'package:flutter/material.dart';

import '../widgets/adaptive_phone_canvas.dart';

class SignalQualityDetailScreen extends StatelessWidget {
  final int qualityScore;

  const SignalQualityDetailScreen({
    super.key,
    required this.qualityScore,
  });

  int get _score100 => (qualityScore * 20).clamp(0, 100);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF3F5),
      body: SafeArea(
        child: AdaptivePhoneCanvas(
          child: SizedBox(
            width: 390,
            height: 844,
            child: Stack(
              children: [
                Positioned(
                  left: 13,
                  top: 0,
                  child: SizedBox(
                    width: 364,
                    height: 135,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 23,
                          child: SizedBox(
                            width: 32,
                            height: 31,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.chevron_left, size: 32),
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 142,
                          top: 26,
                          child: Text(
                            '신호 품질',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 105,
                          top: 73,
                          child: SizedBox(
                            width: 154,
                            height: 49,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 29,
                                  top: 5,
                                  child: Text(
                                    '$_score100',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  left: 103,
                                  top: 19,
                                  child: Text(
                                    '점',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
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
                Positioned(
                  left: 13,
                  top: 133,
                  child: SizedBox(
                    width: 364,
                    height: 672,
                    child: Stack(
                      children: const [
                        _QualityRangeCard(
                          top: 2,
                          rangeTitle: '90점 ~ 100점',
                          badgeColor: Color(0xFF618AF0),
                          stateTitle: '최우수 품질',
                          description: '측정 환경이 매우 안정적이며 신호 품질이 우수합니다.',
                        ),
                        _QualityRangeCard(
                          top: 139,
                          rangeTitle: '70점 ~ 89점',
                          badgeColor: Color(0xFF6DF061),
                          stateTitle: '양호한 품질',
                          description: '약간의 미세한 움직임이나 조명 변화가 감지되었으나, 건강 지표를 분석하기에는 충분한 상태입니다.',
                        ),
                        _QualityRangeCard(
                          top: 276,
                          rangeTitle: '40점 ~ 69점',
                          badgeColor: Color(0xFFF0E461),
                          stateTitle: '신호 불안정',
                          description: '잦은 움직임이나 센서(카메라)의 흔들림으로 인해 생체 신호에 노이즈가 섞여 들어오고 있습니다.',
                        ),
                        _QualityRangeCard(
                          top: 413,
                          rangeTitle: '0점 ~ 39점',
                          badgeColor: Color(0xFFF06161),
                          stateTitle: '측정 불가',
                          description: '큰 움직임이 발생했거나 환경적 요인으로 인해 유의미한 심박 패턴을 찾을 수 없습니다.',
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

class _QualityRangeCard extends StatelessWidget {
  final double top;
  final String rangeTitle;
  final Color badgeColor;
  final String stateTitle;
  final String description;

  const _QualityRangeCard({
    required this.top,
    required this.rangeTitle,
    required this.badgeColor,
    required this.stateTitle,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: top,
      child: SizedBox(
        width: 364,
        height: 122,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: 364,
                height: 122,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF3F4F9), Color(0xFFEEEEEE), Color(0xFFE2E9EA)],
                    stops: [0.2212, 0.5192, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFFACAFB8)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.43),
                      offset: Offset(-1, 2),
                      blurRadius: 2.8,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 17,
              top: 16,
              child: SizedBox(
                width: 325,
                height: 40,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 66,
                      top: 5,
                      child: Text(
                        rangeTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 60,
              top: 63,
              child: SizedBox(
                width: 293,
                height: 57,
                child: Stack(
                  children: [
                    Positioned(
                      left: 3,
                      top: -1,
                      child: Text(
                        stateTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 21,
                      child: SizedBox(
                        width: 286,
                        child: Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.25,
                            color: Colors.black,
                          ),
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
    );
  }
}
