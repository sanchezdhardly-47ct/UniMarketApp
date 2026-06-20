import 'package:flutter/material.dart';

class AppColors {
  // 🎨 NUEVA PALETA UNIMARKET - PREDOMINIO CELESTE
  static const Color primario = Color(0xFF32B3DF);      // Celeste principal
  static const Color secundario = Color(0xFF9EC12E);    // Verde lima
  static const Color acento = Color(0xFFFF6B35);        // Naranja coral (para acentos)
  static const Color fondo = Color(0xFFF0F9FF);         // Celeste muy claro
  static const Color textoPrincipal = Color(0xFF1E3A5F); // Azul oscuro
  
  // 🎨 COLORES COMPLEMENTARIOS
  static const Color textoSecundario = Color(0xFF5A6B82);
  static const Color fondoGris = Color(0xFFF8FAFC);
  static const Color borde = Color(0xFFE2E8F0);
  static const Color exito = Color(0xFF27AE60);
  static const Color error = Color(0xFFE74C3C);
  static const Color advertencia = Color(0xFFF39C12);
  
  // 🎨 VARIANTES CLARAS DEL CELESTE
  static const Color primarioClaro = Color(0xFF4FC3F7);
  static const Color primarioMuyClaro = Color(0xFFE1F5FE);
  static const Color secundarioClaro = Color(0xFFB9D96C);
  static const Color acentoClaro = Color(0xFFFF8A65);
  
  // 🎨 GRADIENTES (opcional)
  static const Gradient gradientePrimario = LinearGradient(
    colors: [Color(0xFF32B3DF), Color(0xFF4FC3F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}