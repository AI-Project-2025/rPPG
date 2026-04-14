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
                          rangeTitle: '0점 ~ 20점',
                          badgeColor: Color(0xFF618AF0),
                          stateTitle: '회복 저하',
                          description: '스트레스 회복력이 낮아 충분한 휴식과 수면 보강이 필요합니다.',
                        ),
                        _RecoveryRangeCard(
                          top: 139,
                          rangeTitle: '21점 ~ 40점',
                          badgeColor: Color(0xFF6DF061),
                          stateTitle: '회복 부족',
                          description: '회복 반응이 둔화된 상태로 일상 피로 누적 가능성이 큽니다.',
                        ),
                        _RecoveryRangeCard(
                          top: 276,
                          rangeTitle: '41점 ~ 60점',
                          badgeColor: Color(0xFFF0E461),
                          stateTitle: '보통',
                          description: '기본적인 회복은 가능하지만 컨디션 변동성에 주의가 필요합니다.',
                        ),
                        _RecoveryRangeCard(
                          top: 413,
                          rangeTitle: '61점 ~ 80점',
                          badgeColor: Color(0xFFF06161),
                          stateTitle: '양호',
                          description: '스트레스 이후 회복이 비교적 원활하게 진행되는 상태입니다.',
                        ),
                        _RecoveryRangeCard(
                          top: 550,
                          rangeTitle: '81점 ~ 100점',
                          badgeColor: Color(0xFF515151),
                          stateTitle: '매우 양호',
                          description: '회복 탄력성이 뛰어나며 자율신경 회복 능력이 우수합니다.',
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
