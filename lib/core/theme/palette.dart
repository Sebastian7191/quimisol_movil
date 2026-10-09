import 'package:flutter/material.dart';

class Palette {
  // Colores principales
  static const Color primary   = Color(0xFF1DA1F2); // #1DA1F2 (azul)
  static const Color secondary = Color(0xFF1DF2CB); // #1DF2CB (aqua)

  // Card / superficies (suaves para que combine con el fondo)
  static const Color card    = Color(0xFFEAF6F7);   // muy claro, frío
  static const Color fieldBg = Color(0xFFFFFFFF);   // blanco

  // Botones
  static const Color button    = Color(0xFF1DCBF2); // #1DCBF2 (celeste)
  static const Color secButton = Color(0xFF1DF2A4); // #1DF2A4 (menta)

  // Fondo (body) degradado
  static const Color gradientStart = Color(0xFF1DA1F2); // azul
  static const Color gradientEnd   = Color(0xFF1DF268); // verde

  // De uso general
  static const Color white = Color(0xFFFFFFFF);
  static const Color ink   = Color(0xFF16324A); // texto oscuro azulado (para legibilidad)

  // Colores para estadísticas y gráficos
  static const Color statsSuccess = Color(0xFF1DF268); // verde
  static const Color statsWarning = Color(0xFFF59E0B); // warning estándar
  static const Color statsDanger  = Color(0xFFDC2626); // danger estándar
  static const Color statsNeutral = Color(0xFF0F172A); // neutral oscuro
}

/*
import 'package:flutter/material.dart';

// Paleta centralizada
class Palette {
  // Colores principales
  static const Color primary = Color.fromARGB(255,149,103,228);   // textos/íconos
  static const Color secondary = Color.fromARGB(255,207,143,228); // morado claro
  static const Color card = Color.fromARGB(255, 243, 218, 247);   // card pastel
  static const Color fieldBg = Color.fromARGB(255,249,248,250);   // fondo inputs
  static const Color button = Color(0xFFE1AEE8);                  // botón rosa suave primario
  static const Color secButton = Color.fromARGB(255,176,133,252); // botón secundario morado

  // Fondo (body) degradado
  static const Color gradientStart = Color(0xFFD2A1E2); // #d2a1e2
  static const Color gradientEnd = Color(0xFFEACCEE); // #eaccee

  // De uso general
  static const Color white = Color(0xFFFFFFFF); // #FFFFFF
  static const Color ink = Color(0xFF4A3B59); // púrpura grisáceo oscuro

  // Colores para estadísticas y gráficos
  static const Color statsSuccess = Color(0xFF16A34A); // verde para métricas positivas
  static const Color statsWarning = Color(0xFFF59E0B); // naranja para advertencias
  static const Color statsDanger = Color(0xFFDC2626); // rojo para alertas
  static const Color statsNeutral = Color(0xFF0F172A); // gris oscuro neutral
}
*/