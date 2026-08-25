import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color primary;
  final Color primarySoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color text;
  final Color textMuted;
  final Color textSubtle;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.primary,
    required this.primarySoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
  });

  static const dark = AppPalette(
    background: Color(0xFF08111F),
    surface: Color(0xFF101C2D),
    surfaceHigh: Color(0xFF17263A),
    border: Color(0xFF24364D),
    primary: Color(0xFF4F8CFF),
    primarySoft: Color(0xFF182E52),
    success: Color(0xFF36D399),
    warning: Color(0xFFFFB547),
    danger: Color(0xFFFF6577),
    text: Color(0xFFF4F7FB),
    textMuted: Color(0xFF91A3BB),
    textSubtle: Color(0xFF60738C),
  );

  static const light = AppPalette(
    background: Color(0xFFF4F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEAF0F7),
    border: Color(0xFFD7E0EB),
    primary: Color(0xFF2563EB),
    primarySoft: Color(0xFFDFEAFE),
    success: Color(0xFF07865F),
    warning: Color(0xFFB86600),
    danger: Color(0xFFD92D45),
    text: Color(0xFF142033),
    textMuted: Color(0xFF53657C),
    textSubtle: Color(0xFF78889B),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? border,
    Color? primary,
    Color? primarySoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? text,
    Color? textMuted,
    Color? textSubtle,
  }) =>
      AppPalette(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceHigh: surfaceHigh ?? this.surfaceHigh,
        border: border ?? this.border,
        primary: primary ?? this.primary,
        primarySoft: primarySoft ?? this.primarySoft,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        text: text ?? this.text,
        textMuted: textMuted ?? this.textMuted,
        textSubtle: textSubtle ?? this.textSubtle,
      );

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get appColors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}

class AppThemeController extends ValueNotifier<ThemeMode> {
  static const _preferenceKey = 'app_theme_mode';
  SharedPreferences? _preferences;

  AppThemeController() : super(ThemeMode.light);

  Future<void> initialize() async {
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    value = switch (preferences.getString(_preferenceKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  void setMode(ThemeMode mode) {
    if (value == mode) return;
    value = mode;
    final preferences = _preferences;
    if (preferences != null) {
      unawaited(preferences.setString(_preferenceKey, mode.name));
    }
  }
}

final appThemeController = AppThemeController();

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppPalette.light);
  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final base =
        brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      primary: palette.primary,
      surface: palette.surface,
      error: palette.danger,
    );
    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: palette.text, displayColor: palette.text);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [palette],
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: palette.background,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: palette.background,
              ),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: palette.text,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceHigh,
        labelStyle: TextStyle(color: palette.textMuted),
        hintStyle: TextStyle(color: palette.textSubtle),
        prefixIconColor: palette.textMuted,
        suffixIconColor: palette.textMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.danger),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: palette.surfaceHigh,
          disabledForegroundColor: palette.textSubtle,
          minimumSize: const Size(48, 52),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: palette.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.primary),
      ),
      iconTheme: IconThemeData(color: palette.textMuted),
      listTileTheme: ListTileThemeData(
        textColor: palette.text,
        iconColor: palette.textMuted,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.primary,
        unselectedLabelColor: palette.textMuted,
        dividerColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: palette.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: palette.border),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: palette.primary),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: palette.text),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: palette.text),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.surface),
        ),
      ),
    );
  }
}
