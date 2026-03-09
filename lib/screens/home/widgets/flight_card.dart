import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/flight.dart';

class FlightCard extends StatelessWidget {
  final Flight flight;

  const FlightCard({super.key, required this.flight});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d').format(flight.date);
    final emissionsTons = (flight.emissionsKg / 1000).toStringAsFixed(2);
    final airlineInfo = flight.AirlineCode.isNotEmpty
        ? '${flight.AirlineCode} ${flight.AirlineNumber}'
        : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Airline logo placeholder
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                flight.AirlineCode.isNotEmpty ? flight.AirlineCode : '??',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF616161),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Flight route info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${flight.originCode} \u2192 ${flight.destinationCode}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$airlineInfo  \u2022  $dateStr',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
          // Emissions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${emissionsTons}t',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Text(
                'CO\u2082',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
