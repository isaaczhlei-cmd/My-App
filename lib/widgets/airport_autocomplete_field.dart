import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../screens/book_flight/airport_directory.dart';

class AirportAutocompleteField extends StatelessWidget {
  const AirportAutocompleteField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.matches,
    required this.onChanged,
    required this.onSelected,
    this.prefixIcon,
    this.textCapitalization = TextCapitalization.words,
    this.textStyle,
    this.hintStyle,
    this.fillColor = const Color(0xFFF2F3F7),
    this.dropdownColor = const Color(0xFFF7F8FB),
    this.borderColor = Colors.transparent,
    this.dropdownBorderColor = const Color(0xFFE2E5EE),
    this.borderRadius = 14,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 16,
    ),
    this.showClearButton = true,
    this.showNoMatches = true,
    this.noMatchesText = 'No matches - try the IATA code',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final List<AirportOption> matches;
  final ValueChanged<String> onChanged;
  final ValueChanged<AirportOption> onSelected;
  final IconData? prefixIcon;
  final TextCapitalization textCapitalization;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final Color fillColor;
  final Color dropdownColor;
  final Color borderColor;
  final Color dropdownBorderColor;
  final double borderRadius;
  final EdgeInsetsGeometry contentPadding;
  final bool showClearButton;
  final bool showNoMatches;
  final String noMatchesText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          style:
              textStyle ??
              const TextStyle(
                color: Color(0xFF30324A),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle:
                hintStyle ??
                const TextStyle(color: Color(0xFF8A8FA7), fontSize: 15),
            filled: true,
            fillColor: fillColor,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, color: const Color(0xFF737896)),
            suffixIcon: showClearButton && controller.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close, color: Color(0xFF737896)),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: borderColor),
            ),
            contentPadding: contentPadding,
          ),
        ),
        if (focusNode.hasFocus && controller.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: dropdownColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dropdownBorderColor),
            ),
            child: matches.isNotEmpty
                ? SingleChildScrollView(
                    child: Column(
                      children: matches.map((airport) {
                        return ListTile(
                          leading: const Icon(
                            Icons.flight,
                            color: AppColors.primaryGreen,
                          ),
                          title: Text(
                            airport.shortLabel,
                            style: const TextStyle(
                              color: Color(0xFF30324A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${airport.name} • ${airport.country}',
                            style: const TextStyle(color: Color(0xFF737896)),
                          ),
                          onTap: () => onSelected(airport),
                        );
                      }).toList(),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      showNoMatches ? noMatchesText : '',
                      style: const TextStyle(color: Color(0xFF8A8FA7)),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}
