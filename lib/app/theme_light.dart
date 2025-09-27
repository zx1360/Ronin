import 'package:flutter/material.dart';

class AppTheme {
  // 主色调 - 采用清新蓝色作为主色调，适合明亮主题
  static const primaryColor = Color(0xFF42A5F5);
  static const primaryColorDark = Color(0xFF1E88E5);
  static const primaryColorLight = Color(0xFFBBDEFB);
  
  // 辅助色 - 用于强调和交互元素
  static const secondaryColor = Color(0xFF7E57C2);
  
  // 中性色 - 用于文本和背景
  static const lightBackgroundColor = Color(0xFFF5F7FA);
  static const lightCardColor = Color(0xFFFFFFFF);
  static const lightSurfaceColor = Color(0xFFECEFF1);
  static const darkTextColor = Color(0xFF263238);
  static const mediumTextColor = Color(0xFF546E7A);
  static const disabledTextColor = Color(0xFF90A4AE);

  // 全局明亮主题
  static ThemeData lightTheme() {
    return ThemeData(
      // 基础配置
      brightness: Brightness.light,
      primaryColor: primaryColor,
      primaryColorDark: primaryColorDark,
      primaryColorLight: primaryColorLight,
      secondaryHeaderColor: secondaryColor,
      
      // 颜色方案
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surfaceBright: lightBackgroundColor,
        surface: lightSurfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurfaceVariant: darkTextColor,
        onSurface: darkTextColor,
      ),
      
      // 背景色
      scaffoldBackgroundColor: lightBackgroundColor,
      canvasColor: lightBackgroundColor,
      
      // 卡片样式
      cardTheme: CardThemeData(
        color: lightCardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // 文本样式
      textTheme: const TextTheme(
        // 标题样式
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: darkTextColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkTextColor,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: darkTextColor,
        ),
        
        // 副标题样式
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkTextColor,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkTextColor,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: darkTextColor,
        ),
        
        // 正文样式
        bodyLarge: TextStyle(
          fontSize: 16,
          color: darkTextColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: darkTextColor,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: mediumTextColor,
        ),
        
        // 标签样式
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: darkTextColor,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: mediumTextColor,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: disabledTextColor,
        ),
      ),
      
      // 按钮样式
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: lightSurfaceColor,
          disabledForegroundColor: disabledTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          disabledForegroundColor: disabledTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          disabledForegroundColor: disabledTextColor,
        ),
      ),
      
      // 输入框样式
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: mediumTextColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: mediumTextColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: disabledTextColor),
        ),
        hintStyle: TextStyle(color: mediumTextColor),
        labelStyle: TextStyle(color: darkTextColor),
        prefixIconColor: mediumTextColor,
        suffixIconColor: mediumTextColor,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        errorStyle: TextStyle(color: Colors.red),
      ),
      
      // 滑块样式
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: lightSurfaceColor,
        thumbColor: primaryColor,
        overlayColor: primaryColorLight.withValues(alpha: .2),
        valueIndicatorColor: primaryColor,
        valueIndicatorTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      // 开关样式
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return mediumTextColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return lightSurfaceColor;
        }),
      ),
      
      // 复选框样式
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: mediumTextColor),
      ),
      
      // 单选按钮样式
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        overlayColor: WidgetStateProperty.all(primaryColorLight.withValues(alpha: 0.2)),
      ),
      
      // 进度指示器样式
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        circularTrackColor: lightSurfaceColor,
        linearTrackColor: lightSurfaceColor,
      ),
    );
  }
}
