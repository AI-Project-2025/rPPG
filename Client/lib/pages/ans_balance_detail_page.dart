import 'package:flutter/material.dart';

import '../widgets/adaptive_phone_canvas.dart';

class AnsBalanceDetailScreen extends StatelessWidget {
  final int ansScore;

  const AnsBalanceDetailScreen({
    super.key,
    required this.ansScore,
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
                        Positioned(
                          left: 114,
                          top: 26,
                          child: SizedBox(
                            width: 134,
                            height: 41,
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: Colors.black,
                                ),
                                children: [
                                  TextSpan(text: '자율신경 균형도\n'),
                                  TextSpan(
                                    text: '(ANS Balance)',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ],
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
                                    '$ansScore',
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
                        _AnsRangeCard(
                          top: 2,
                          rangeTitle: '80점 ~ 100점',
                          badgeColor: Color(0xFF618AF0),
                          stateTitle: '극심한 스트레스 및 긴장 상태',
                          description: '현재 교감신경이 과도하게 활성화되어 몸이 잔뜩 긴장하고 있습니다.',
                        ),
                        _AnsRangeCard(
                          top: 139,
                          rangeTitle: '60점 ~ 79점',
                          badgeColor: Color(0xFF6DF061),
                          stateTitle: '가벼운 스트레스 및 집중 상태',
                          description: '활동적이고 집중력이 높은 상태이나, 약간의 스트레스가 감지됩니다.',
                        ),
                        _AnsRangeCard(
                          top: 276,
                          rangeTitle: '40점 ~ 59점',
                          badgeColor: Color(0xFFF0E461),
                          stateTitle: '최적의 자율신경 균형 상태',
                          description: '긴장과 이완이 완벽한 조화를 이루고 있습니다.',
                        ),
                        _AnsRangeCard(
                          top: 413,
                          rangeTitle: '20점 ~ 39점',
                          badgeColor: Color(0xFFF06161),
                          stateTitle: '피로 누적 및 깊은 이완 상태',
                          description: '부교감신경이 활성화되어 몸이 휴식을 강하게 요구하고 있습니다.',
                        ),
                        _AnsRangeCard(
                          top: 550,
                          rangeTitle: '0점 ~ 19점',
                          badgeColor: Color(0xFF515151),
                          stateTitle: '극심한 무기력 및 번아웃 상태',
                          description: '신체 에너지가 바닥나 짙은 무기력감을 느낄 수 있는 상태입니다.',
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

class _AnsRangeCard extends StatelessWidget {
  final double top;
  final String rangeTitle;
  final Color badgeColor;
  final String stateTitle;
  final String description;

  const _AnsRangeCard({
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
                            color: Colors.black,
                            height: 1.25,
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
