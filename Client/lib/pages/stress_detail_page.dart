import 'package:flutter/material.dart';

import '../widgets/adaptive_phone_canvas.dart';

class StressDetailScreen extends StatelessWidget {
  final int stressScore;

  const StressDetailScreen({
    super.key,
    required this.stressScore,
  });

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
                          left: 94,
                          top: 26,
                          child: SizedBox(
                            width: 175,
                            height: 24,
                            child: Text(
                              '실시간 스트레스 점수',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
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
                                    '$stressScore',
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
                        _StressRangeCard(
                          top: 2,
                          rangeTitle: '44점 ~ 100점',
                          badgeColor: Color(0xFFF06161),
                          stateTitle: '스트레스 상태',
                          description: '높은 수준의 스트레스와 신체적 긴장이 감지됩니다. 잠시 하던 일을 멈추고 가벼운 스트레칭이나 심호흡을 권장합니다.',
                        ),
                        _StressRangeCard(
                          top: 139,
                          rangeTitle: '0점 ~ 43점',
                          badgeColor: Color(0xFF61F098),
                          stateTitle: '안정 상태',
                          description: '차분하고 안정적인 상태를 유지하고 있습니다. 과도한 긴장 없이 편안하게 일에 집중하기 좋은 컨디션입니다.',
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

class _StressRangeCard extends StatelessWidget {
  final double top;
  final String rangeTitle;
  final Color badgeColor;
  final String stateTitle;
  final String description;

  const _StressRangeCard({
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
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                            height: 1.2,
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
