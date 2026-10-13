import 'package:flutter/material.dart';

/// The app palette, carried on ThemeData so every colour resolves from the
/// active theme instead of a global constant.
///
/// Names are semantic (surface / textPrimary) rather than literal (white /
/// black): in dark mode `surface` is nearly black, and a field called `white`
/// returning black is how colour systems become unreadable.
@immutable
class BodifyColors extends ThemeExtension<BodifyColors> {
  /// Page and card background.
  final Color surface;

  /// Subtle fills: input fields, chips, list rows.
  final Color surfaceVariant;

  /// Body copy and headings.
  final Color textPrimary;

  /// Captions, hints, secondary labels.
  final Color textSecondary;

  /// Brand accents. These stay the same in both themes - they are the
  /// identity of the app and read well on light and dark alike.
  final Color primary1;
  final Color primary2;
  final Color secondary1;
  final Color secondary2;

  /// Colour used for text/icons placed on top of a brand gradient.
  final Color onPrimary;

  const BodifyColors({
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary1,
    required this.primary2,
    required this.secondary1,
    required this.secondary2,
    required this.onPrimary,
  });

  List<Color> get primaryGradient => [primary2, primary1];
  List<Color> get secondaryGradient => [secondary2, secondary1];

  static const light = BodifyColors(
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF7F8F8),
    textPrimary: Color(0xFF1D1617),
    textSecondary: Color(0xFF786F72),
    primary1: Color(0xFF92A3FD),
    primary2: Color(0xFF9DCEFF),
    secondary1: Color(0xFFC58BF2),
    secondary2: Color(0xFFEEA4CE),
    onPrimary: Color(0xFF1D1617),
  );

  static const dark = BodifyColors(
    // Not pure black: a slightly lifted surface keeps the elevated cards and
    // the page background distinguishable.
    surface: Color(0xFF17171F),
    surfaceVariant: Color(0xFF23232E),
    textPrimary: Color(0xFFF2F2F5),
    textSecondary: Color(0xFF9A9AA8),
    primary1: Color(0xFF92A3FD),
    primary2: Color(0xFF9DCEFF),
    secondary1: Color(0xFFC58BF2),
    secondary2: Color(0xFFEEA4CE),
    onPrimary: Color(0xFF1D1617),
  );

  @override
  BodifyColors copyWith({
    Color? surface,
    Color? surfaceVariant,
    Color? textPrimary,
    Color? textSecondary,
    Color? primary1,
    Color? primary2,
    Color? secondary1,
    Color? secondary2,
    Color? onPrimary,
  }) {
    return BodifyColors(
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      primary1: primary1 ?? this.primary1,
      primary2: primary2 ?? this.primary2,
      secondary1: secondary1 ?? this.secondary1,
      secondary2: secondary2 ?? this.secondary2,
      onPrimary: onPrimary ?? this.onPrimary,
    );
  }

  @override
  BodifyColors lerp(ThemeExtension<BodifyColors>? other, double t) {
    if (other is! BodifyColors) return this;
    return BodifyColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      primary1: Color.lerp(primary1, other.primary1, t)!,
      primary2: Color.lerp(primary2, other.primary2, t)!,
      secondary1: Color.lerp(secondary1, other.secondary1, t)!,
      secondary2: Color.lerp(secondary2, other.secondary2, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
    );
  }
}

extension BodifyColorsX on BuildContext {
  /// `context.colors.surface` - the palette for the theme in effect here.
  BodifyColors get colors =>
      Theme.of(this).extension<BodifyColors>() ?? BodifyColors.light;
}

ThemeData buildBodifyTheme(Brightness brightness) {
  final palette =
      brightness == Brightness.dark ? BodifyColors.dark : BodifyColors.light;

  return ThemeData(
    brightness: brightness,
    fontFamily: "BeVietnamPro",
    scaffoldBackgroundColor: palette.surface,
    primaryColor: palette.primary1,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.primary1,
      brightness: brightness,
      surface: palette.surface,
    ),
    // Dialogs and sheets are built by Material, not by our widgets, so they
    // need the palette wired into the standard slots too.
    dialogTheme: DialogThemeData(backgroundColor: palette.surfaceVariant),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.textPrimary,
      contentTextStyle: TextStyle(color: palette.surface),
    ),
    extensions: <ThemeExtension<dynamic>>[palette],
  );
}
