import 'package:flutter/material.dart';

class NotificationBadge extends StatelessWidget {
  final int count;

  const NotificationBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    // Always show the red badge circle. The white label inside reflects the
    // number of notifications (blank when zero). This matches the UI request
    // to keep the red dot visible while the white number updates.
    final hasNumber = count > 0;
    final label = hasNumber ? (count > 99 ? '99+' : '$count') : '';

    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: EdgeInsets.symmetric(horizontal: hasNumber ? 6 : 0),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
