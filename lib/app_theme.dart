import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false,
      
      // 🎨 COLOR SCHEME ACTUALIZADO
      colorScheme: const ColorScheme.light(
        primary: AppColors.primario,        // Celeste principal
        secondary: AppColors.secundario,     // Verde lima
        surface: Colors.white,
        background: AppColors.fondo,         // Celeste muy claro
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textoPrincipal, // Azul oscuro
        onBackground: AppColors.textoPrincipal,
      ),

      scaffoldBackgroundColor: AppColors.fondo,
      
      // 📱 APP BAR THEME ACTUALIZADO
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primario,  // Celeste
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // 🔘 BOTONES ACTUALIZADOS
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primario,  // Celeste para botones principales
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primario,  // Celeste para text buttons
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primario,  // Celeste para outlined buttons
          side: const BorderSide(color: AppColors.primario),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // 📝 INPUT DECORATION ACTUALIZADO
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.primario, width: 2), // Celeste
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: AppColors.textoSecundario),
        hintStyle: TextStyle(color: AppColors.textoSecundario),
      ),

      // 📄 TEXT THEME ACTUALIZADO
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textoPrincipal),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textoPrincipal),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textoPrincipal),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textoPrincipal),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textoPrincipal),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textoPrincipal),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textoPrincipal),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textoPrincipal),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
      ),

      // 🎯 ICON THEME ACTUALIZADO
      iconTheme: const IconThemeData(color: AppColors.primario), // Celeste
      
      // 📦 CARD THEME
      cardTheme: const CardThemeData(
        elevation: 2,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // ➕ FLOATING ACTION BUTTON ACTUALIZADO
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.secundario, // Verde lima para FAB
        foregroundColor: Colors.white,
      ),

      // 📱 BOTTOM NAVIGATION BAR ACTUALIZADO
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primario,    // Celeste para ítem seleccionado
        unselectedItemColor: AppColors.textoSecundario,
        elevation: 8,
      ),

      // 📊 PROGRESS INDICATOR ACTUALIZADO
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primario, // Celeste para loaders
      ),

      // 🎪 DIALOG THEME
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // 🎨 BOTTOM SHEET THEME
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }

  // 🎨 TEMA OSCURO (opcional - para futuro)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      // ... configuración para tema oscuro
    );
  }
}