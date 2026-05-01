import 'package:flutter/material.dart';

class AppTheme {
  /// 深色主题配置
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _darkColorScheme,
      textTheme: _textTheme,
      appBarTheme: _appBarTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      cardTheme: _cardTheme,
      inputDecorationTheme: _inputDecorationTheme,
      checkboxTheme: _checkboxTheme,
      switchTheme: _switchTheme,
      dialogTheme: _dialogTheme,
      bottomSheetTheme: _bottomSheetTheme,
      snackBarTheme: _snackBarTheme,
      navigationBarTheme: _navigationBarTheme,
    );
  }

  /// 深色模式配色方案
  static const ColorScheme _darkColorScheme = ColorScheme.dark(
    primary: AppColors.primary,
    primaryContainer: AppColors.primaryContainer,
    secondary: AppColors.secondary,
    secondaryContainer: AppColors.secondaryContainer,
    tertiary: AppColors.tertiary,
    tertiaryContainer: AppColors.tertiaryContainer,
    surface: AppColors.surface,
    surfaceContainerHighest: AppColors.surfaceVariant,
    surfaceTint: Colors.transparent,
    error: AppColors.error,
    onPrimary: AppColors.onPrimary,
    onSecondary: AppColors.onSecondary,
    onTertiary: AppColors.onTertiary,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    onError: AppColors.onError,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    inverseSurface: AppColors.inverseSurface,
    inversePrimary: AppColors.inversePrimary,
    shadow: AppColors.shadow,
    scrim: AppColors.scrim,
  );

  /// 全局文本样式
  static final TextTheme _textTheme = TextTheme(
    displayLarge: _displayLarge,
    displayMedium: _displayMedium,
    displaySmall: _displaySmall,
    headlineLarge: _headlineLarge,
    headlineMedium: _headlineMedium,
    headlineSmall: _headlineSmall,
    titleLarge: _titleLarge,
    titleMedium: _titleMedium,
    titleSmall: _titleSmall,
    bodyLarge: _bodyLarge,
    bodyMedium: _bodyMedium,
    bodySmall: _bodySmall,
    labelLarge: _labelLarge,
    labelMedium: _labelMedium,
    labelSmall: _labelSmall,
  );

  /// AppBar 主题
  static final AppBarTheme _appBarTheme = AppBarTheme(
    backgroundColor: AppColors.surface,
    titleTextStyle: _titleLarge.copyWith(color: AppColors.onSurface),
    iconTheme: IconThemeData(color: AppColors.onSurfaceVariant),
    elevation: 2,
    shadowColor: AppColors.shadow,
  );

  /// 高强调按钮主题
  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
      disabledForegroundColor: AppColors.onPrimary.withOpacity(0.6),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.borderRadius),
      ),
      elevation: 2,
      shadowColor: AppColors.shadow,
    ),
  );

  /// 描边按钮主题
  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.onSurface,
      disabledForegroundColor: AppColors.onSurface.withOpacity(0.38),
      side: BorderSide(color: AppColors.outline),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.borderRadius),
      ),
    ),
  );

  /// 文本按钮主题
  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.onSurface,
      disabledForegroundColor: AppColors.onSurface.withOpacity(0.38),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.borderRadius),
      ),
    ),
  );

  /// 卡片主题
  static final CardThemeData _cardTheme = CardThemeData(
    color: AppColors.surface,
    elevation: 2,
    shadowColor: AppColors.shadow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.borderRadius),
      side: BorderSide(color: AppColors.outlineVariant),
    ),
    margin: EdgeInsets.zero,
  );

  /// 输入框主题
  static final InputDecorationTheme _inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceVariant,
    border: OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.outline),
      borderRadius: BorderRadius.circular(AppDimens.borderRadius),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.outline),
      borderRadius: BorderRadius.circular(AppDimens.borderRadius),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.primary, width: 2),
      borderRadius: BorderRadius.circular(AppDimens.borderRadius),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.error),
      borderRadius: BorderRadius.circular(AppDimens.borderRadius),
    ),
    disabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.outlineVariant),
      borderRadius: BorderRadius.circular(AppDimens.borderRadius),
    ),
    hintStyle: _bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
    labelStyle: _bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
    errorStyle: _bodySmall.copyWith(color: AppColors.error),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );

  /// 复选框主题
  static final CheckboxThemeData _checkboxTheme = CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.primary;
      if (states.contains(WidgetState.disabled)) return AppColors.onSurface.withOpacity(0.38);
      return null;
    }),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  );

  /// 开关主题
  static final SwitchThemeData _switchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.onPrimary;
      if (states.contains(WidgetState.disabled)) return AppColors.onSurface.withOpacity(0.38);
      return AppColors.onSurface;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.primary;
      if (states.contains(WidgetState.disabled)) return AppColors.onSurface.withOpacity(0.12);
      return AppColors.onSurface.withOpacity(0.38);
    }),
  );

  /// 对话框主题
  static final DialogThemeData _dialogTheme = DialogThemeData(
    backgroundColor: AppColors.surface,
    elevation: 4,
    shadowColor: AppColors.shadow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.borderRadius),
    ),
    titleTextStyle: _titleLarge,
    contentTextStyle: _bodyMedium,
  );

  /// 底部弹窗主题
  static final BottomSheetThemeData _bottomSheetTheme = BottomSheetThemeData(
    backgroundColor: AppColors.surface,
    elevation: 4,
    shadowColor: AppColors.shadow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.borderRadius)),
    ),
  );

  /// 提示条主题
  static final SnackBarThemeData _snackBarTheme = SnackBarThemeData(
    backgroundColor: AppColors.surfaceVariant,
    contentTextStyle: _bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
    actionTextColor: AppColors.primary,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.borderRadius),
    ),
  );

  /// 底部导航栏主题
  static final NavigationBarThemeData _navigationBarTheme = NavigationBarThemeData(
    backgroundColor: AppColors.surface,
    indicatorColor: AppColors.primary.withOpacity(0.2),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _labelSmall.copyWith(color: AppColors.primary);
      return _labelSmall.copyWith(color: AppColors.onSurfaceVariant);
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return IconThemeData(color: AppColors.primary);
      return IconThemeData(color: AppColors.onSurfaceVariant);
    }),
  );

  // 文本样式定义
  static final TextStyle _displayLarge = TextStyle(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25, color: AppColors.onBackground);
  static final TextStyle _displayMedium = TextStyle(fontSize: 45, fontWeight: FontWeight.w400, letterSpacing: 0, color: AppColors.onBackground);
  static final TextStyle _displaySmall = TextStyle(fontSize: 36, fontWeight: FontWeight.w400, letterSpacing: 0, color: AppColors.onBackground);
  static final TextStyle _headlineLarge = TextStyle(fontSize: 32, fontWeight: FontWeight.w400, letterSpacing: 0, color: AppColors.onBackground);
  static final TextStyle _headlineMedium = TextStyle(fontSize: 28, fontWeight: FontWeight.w400, letterSpacing: 0, color: AppColors.onBackground);
  static final TextStyle _headlineSmall = TextStyle(fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: 0, color: AppColors.onBackground);
  static final TextStyle _titleLarge = TextStyle(fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: 0, color: AppColors.onBackground);
  static final TextStyle _titleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15, color: AppColors.onBackground);
  static final TextStyle _titleSmall = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: AppColors.onBackground);
  static final TextStyle _bodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, color: AppColors.onBackground);
  static final TextStyle _bodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, color: AppColors.onBackground);
  static final TextStyle _bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, color: AppColors.onBackground);
  static final TextStyle _labelLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: AppColors.onBackground);
  static final TextStyle _labelMedium = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: AppColors.onBackground);
  static final TextStyle _labelSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: AppColors.onBackground);
}

class AppColors {
  static const Color primary = Color(0xFFdd9b49);
  static const Color primaryContainer = Color(0xFF443e34);
  static const Color secondary = Color(0xFFffbf00);
  static const Color secondaryContainer = Color(0xFF443e34);
  static const Color tertiary = Color(0xFF656565);
  static const Color tertiaryContainer = Color(0xFF2b2b2b);
  static const Color background = Color(0xFF1c1c1c);
  static const Color surface = Color(0xFF242424);
  static const Color surfaceVariant = Color(0xFF2b2b2b);
  static const Color error = Color(0xFFff4757);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF000000);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFFe0e0e0);
  static const Color onSurface = Color(0xFFf5f5f5);
  static const Color onSurfaceVariant = Color(0xFFababab);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFF656565);
  static const Color outlineVariant = Color(0xFF443e34);
  static const Color inverseSurface = Color(0xFFf5f5f5);
  static const Color inversePrimary = Color(0xFFffd580);
  static const Color shadow = Color(0x40000000);
  static const Color scrim = Color(0x80000000);
  static const Color success = Color(0xFF2ecc71);
  static const Color info = Color(0xFF3498db);
  static const Color warning = Color(0xFFf39c12);
}

class AppDimens {
  static const double borderRadius = 8.0;
  static const double buttonBorderRadius = 6.0;
  static const double smallBorderRadius = 4.0;
  static const double elevation = 2.0;
  static const double cardElevation = 2.0;
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 12.0;
  static const double paddingL = 16.0;
  static const double paddingXL = 24.0;
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 24.0;
  static const double spacingXXL = 32.0;
}