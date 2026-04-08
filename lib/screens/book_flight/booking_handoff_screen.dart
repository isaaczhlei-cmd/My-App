import 'package:flutter/material.dart';

import '../../config/theme.dart';

class BookingHandoffScreen extends StatefulWidget {
  const BookingHandoffScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.outboundDate,
    required this.returnDate,
    required this.outboundUrl,
    required this.returnUrl,
    required this.onLaunchUrl,
  });

  final String origin;
  final String destination;
  final DateTime outboundDate;
  final DateTime returnDate;
  final Uri outboundUrl;
  final Uri returnUrl;
  final Future<void> Function(Uri url) onLaunchUrl;

  @override
  State<BookingHandoffScreen> createState() => _BookingHandoffScreenState();
}

class _BookingHandoffScreenState extends State<BookingHandoffScreen> {
  bool _outboundOpened = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text('Round Trip Booking'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Book each leg in order',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We will open the outbound flight first, then the return flight back to your original airport.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildStepCard(
                step: '1',
                title: 'Outbound flight',
                subtitle:
                    '${widget.origin} to ${widget.destination} • ${_formatDate(widget.outboundDate)}',
                buttonLabel: 'Open outbound search',
                onPressed: () async {
                  await widget.onLaunchUrl(widget.outboundUrl);
                  if (mounted) {
                    setState(() {
                      _outboundOpened = true;
                    });
                  }
                },
                isActive: true,
              ),
              const SizedBox(height: 14),
              _buildStepCard(
                step: '2',
                title: 'Return flight',
                subtitle:
                    '${widget.destination} to ${widget.origin} • ${_formatDate(widget.returnDate)}',
                buttonLabel: 'Open return search',
                onPressed: _outboundOpened
                    ? () async {
                        await widget.onLaunchUrl(widget.returnUrl);
                      }
                    : null,
                isActive: _outboundOpened,
              ),
              const Spacer(),
              Text(
                _outboundOpened
                    ? 'After you pick the outbound option, tap the return button to search flights back home.'
                    : 'Start with the outbound search. Once it opens, the return search becomes available.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback? onPressed,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primaryGreen
                      : const Color(0xFFE3E6EF),
                  borderRadius: BorderRadius.circular(17),
                ),
                alignment: Alignment.center,
                child: Text(
                  step,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF5F657A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF10131E),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF737896),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive
                    ? const Color(0xFF0A0B1C)
                    : const Color(0xFFC2C7D6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }
}
