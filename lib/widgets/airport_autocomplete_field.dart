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
    final themeColors = context.appColors;
    final accent = Theme.of(context).colorScheme.primary;
    final effectiveFillColor = fillColor == const Color(0xFFF2F3F7)
        ? themeColors.cardMuted
        : fillColor;
    final effectiveDropdownColor = dropdownColor == const Color(0xFFF7F8FB)
        ? themeColors.elevatedSurface
        : dropdownColor;
    final effectiveBorderColor = borderColor == Colors.transparent
        ? themeColors.outlineSoft
        : borderColor;
    final effectiveDropdownBorderColor =
        dropdownBorderColor == const Color(0xFFE2E5EE)
        ? themeColors.outlineSoft
        : dropdownBorderColor;
    final effectiveTextStyle =
        textStyle ??
        TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w700);
    final effectiveHintStyle =
        hintStyle ?? TextStyle(color: themeColors.onCardMuted, fontSize: 15);

    return Column(
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          cursorColor: accent,
          style: effectiveTextStyle,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: effectiveHintStyle,
            filled: true,
            fillColor: effectiveFillColor,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, color: themeColors.onCardMuted),
            suffixIcon: showClearButton && controller.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: Icon(Icons.close, color: themeColors.onCardMuted),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: effectiveBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: accent, width: 1.5),
            ),
            contentPadding: contentPadding,
          ),
        ),
        if (focusNode.hasFocus) ...[
          const SizedBox(height: 8),
          // If the user hasn't typed yet, show an A-Z quick index so they can
          // pick a letter to browse that section without loading the whole
          // airport list.
          if (controller.text.trim().isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: effectiveDropdownColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: effectiveDropdownBorderColor),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(26, (i) {
                    final letter = String.fromCharCode(65 + i);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: GestureDetector(
                        onTap: () {
                          // Update the controller and notify parent to trigger
                          // a search for the selected letter.
                          controller.text = letter;
                          onChanged(letter);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: themeColors.cardMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: themeColors.outlineSoft),
                          ),
                          child: Text(
                            letter,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color: effectiveDropdownColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: effectiveDropdownBorderColor),
              ),
              child: matches.isNotEmpty
                  ? SingleChildScrollView(
                      child: Column(
                        children: matches.map((airport) {
                          return ListTile(
                            leading: Icon(Icons.flight, color: accent),
                            title: Text(
                              airport.shortLabel,
                              style: TextStyle(
                                color: themeColors.onCard,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${airport.name} • ${airport.country}',
                              style: TextStyle(color: themeColors.onCardMuted),
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
                        style: TextStyle(color: themeColors.onCardMuted),
                      ),
                    ),
            ),
        ],
      ],
    );
  }
}
