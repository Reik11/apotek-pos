import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class DrugCategoryBadge extends StatelessWidget {
  final String category;
  const DrugCategoryBadge({required this.category, super.key});

  @override
  Widget build(BuildContext context) {
    final style = _getStyle(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: style.accentColor, width: 3)),
      ),
      child: Text(
        category.replaceAll('_', ' '),
        style: TextStyle(
          color: style.accentColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _BadgeStyle _getStyle(String category) {
    switch (category.toUpperCase()) {
      case 'BEBAS':
        return _BadgeStyle(
          bgColor: const Color(0xFFD1FAE5),
          accentColor: const Color(0xFF16A34A),
        );
      case 'BEBAS_TERBATAS':
        return _BadgeStyle(
          bgColor: const Color(0xFFFEF3C7),
          accentColor: const Color(0xFFD97706),
        );
      case 'KERAS':
        return _BadgeStyle(
          bgColor: const Color(0xFFFEE2E2),
          accentColor: const Color(0xFFDC2626),
        );
      case 'NARKOTIKA':
      case 'PSIKOTROPIKA':
        return _BadgeStyle(
          bgColor: const Color(0xFFEDE9FE),
          accentColor: const Color(0xFF7C3AED),
        );
      default:
        return _BadgeStyle(
          bgColor: const Color(0xFFF1F5F9),
          accentColor: const Color(0xFF64748B),
        );
    }
  }
}

class _BadgeStyle {
  final Color bgColor;
  final Color accentColor;
  const _BadgeStyle({required this.bgColor, required this.accentColor});
}
