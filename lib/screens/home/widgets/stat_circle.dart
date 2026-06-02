import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class StatCircle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const StatCircle({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final themeColors = context.appColors;

    return Column(
      children: [
        // Circle with icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: themeColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: themeColors.outlineSoft),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 26),
        ),
        const SizedBox(height: 10),

        // Value
        Text(
          value,
          style: TextStyle(
            color: themeColors.onCard,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),

        // Label
        Text(
          label,
          style: TextStyle(
            color: themeColors.onCardMuted,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
