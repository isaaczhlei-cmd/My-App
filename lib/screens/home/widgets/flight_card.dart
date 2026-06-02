import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../models/flight.dart';

class FlightCard extends StatelessWidget {
  final Flight flight;
  final bool compact;

  const FlightCard({super.key, required this.flight, this.compact = false});

  String get _airlineCode => flight.AirlineCode.trim().toUpperCase();

  String get _airlineLogoUrl {
    if (_airlineCode.isEmpty) return '';
    return 'https://www.gstatic.com/flights/airline_logos/70px/$_airlineCode.png';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d').format(flight.date);
    final emissionsTons = (flight.emissionsKg / 1000).toStringAsFixed(2);
    final airlineInfo = _airlineCode.isNotEmpty
        ? '$_airlineCode ${flight.AirlineNumber}'
        : 'Unknown';
    final logoSize = compact ? 40.0 : 44.0;
    final themeColors = context.appColors;

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 10 : 12),
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: themeColors.logoPlate,
              borderRadius: BorderRadius.circular(10),
            ),
            child: _airlineCode.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.flight,
                      size: 22,
                      color: Color(0xFF616161),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _airlineLogoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            _airlineCode,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                          color: Color(0xFF616161),
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${flight.originCode} \u2192 ${flight.destinationCode}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w600,
                    color: themeColors.onCard,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$airlineInfo  \u2022  $dateStr',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    color: themeColors.onCardMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Container(
            constraints: BoxConstraints(minWidth: compact ? 66 : 0),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${emissionsTons}t',
                  style: TextStyle(
                    fontSize: compact ? 14 : 17,
                    fontWeight: FontWeight.bold,
                    color: themeColors.onCard,
                  ),
                ),
                Text(
                  'CO\u2082',
                  style: TextStyle(fontSize: 12, color: themeColors.onCardMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
