import 'package:flutter/material.dart';

import '../widgets/adaptive_phone_canvas.dart';

class RecoveryDetailScreen extends StatelessWidget {
  final int recoveryScore;

  const RecoveryDetailScreen({
    super.key,
    required this.recoveryScore,
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
                          left: 114,
                          top: 26,
                          child: SizedBox(
                            width: 134,
                            height: 24,
                            child: Text(
                              '스트레스 회복력',
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
                                    '$recoveryScore',
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
                        _RecoveryRangeCard(
                          top: 2,
                          rangeTitle: '80점 ~ 100점',
                          badgeColor: Color(0xFF618AF0),
                          stateTitle: '최상의 컨디션',
                          description: '신체의 방어력이 극대화되어 스트레스를 쉽게 튕겨낼 수 있는 상태입니다.',
                        ),
                        _RecoveryRangeCard(
                          top: 139,
                          rangeTitle: '60점 ~ 79점',
                          badgeColor: Color(0xFF6DF061),
                          stateTitle: '좋은 회복력',
                          description: '자율신경계가 튼튼하고 외부 환경 변화에 유연하게 대처할 수 있습니다.',
                        ),
                        _RecoveryRangeCard(
                          top: 276,
                          rangeTitle: '40점 ~ 59점',
                          badgeColor: Color(0xFFF0E461),
                          stateTitle: '일반적인 활력 수준',
                          description: '방전되지는 않았지만, 에너지를 아껴 써야 하는 평범한 상태입니다.',
                        ),
                        _RecoveryRangeCard(
                          top: 413,
                          rangeTitle: '20점 ~ 39점',
                          badgeColor: Color(0xFFF06161),
                          stateTitle: '회복력 저하 및 피로 누적',
                          description: '피로가 누적되어 자율신경계의 융통성이 떨어지고 스트레스에 취약해졌습니다.',
                        ),
                        _RecoveryRangeCard(
                          top: 550,
                          rangeTitle: '0점 ~ 19점',
                          badgeColor: Color(0xFF515151),
                          stateTitle: '극도의 피로 및 방전',
                          description: '신체의 대처 능력이 바닥나 작은 스트레스에도 크게 흔들릴 수 있는 상태입니다.',
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

class _RecoveryRangeCard extends StatelessWidget {
  final double top;
  final String rangeTitle;
  final Color badgeColor;
  final String stateTitle;
  final String description;

  const _RecoveryRangeCard({
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
                      top: 2,
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
                      top: 24,
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
