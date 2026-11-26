import 'package:flutter/material.dart';
import '../theme/anon_theme.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final shieldSize = compact ? 72.0 : 110.0;
    final letterSize = compact ? 28.0 : 44.0;
    return Column(
      children: [
        SizedBox(
          width: shieldSize,
          height: shieldSize + 8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: shieldSize * 0.7,
                height: shieldSize * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AnonColors.purple.withOpacity(0.28),
                  boxShadow: [
                    BoxShadow(
                      color: AnonColors.purple.withOpacity(0.35),
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.shield_outlined,
                size: shieldSize * 0.95,
                color: AnonColors.purpleSoft,
                shadows: const [Shadow(color: Color(0xFFA23DFF), blurRadius: 12)],
              ),
              Text(
                'A',
                style: wordmarkStyle(size: letterSize).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('ANON', style: wordmarkStyle(size: compact ? 28 : 40)),
        const SizedBox(height: 10),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AnonColors.purple),
            gradient: const LinearGradient(
              colors: [Color(0x8828143C), Color(0x88110D1B)],
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user, size: 18, color: AnonColors.purpleSoft),
              SizedBox(width: 8),
              Text(
                'PROTECTED BY ANON',
                style: TextStyle(
                  color: Color(0xFFF1DCFF),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
