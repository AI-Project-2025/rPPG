import 'package:flutter/material.dart';

class ResultPage extends StatelessWidget {
  final double avgHr;
  final double stressIndex; // 0~4

  const ResultPage({
    super.key,
    required this.avgHr,
    required this.stressIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('분석 결과')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ResultCard(
              title: '평균 HR',
              value: '${avgHr.toStringAsFixed(0)} bpm',
              subtitle: '측정 구간 평균 HR',
            ),
            const SizedBox(height: 16),
            _ResultCard(
              title: '스트레스 지수',
              value: stressIndex.toStringAsFixed(1),
              subtitle: 'MVP 점수(0~4)',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('측정 화면으로'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _ResultCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 6),
            color: Color(0x22000000),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(value,
              style:
              const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
