import 'package:flutter/material.dart';

class AppColors {
  // 1. Fondos y Superficies (Tema Claro Cálido)
  static const Color scaffoldBackground = Color(0xFFF5F9F8); // Fondo general suave
  static const Color surfaceCard = Color(0xFFFFFFFF);        // Tarjetas y dial blanco
  static const Color surfaceMuted = Color(0xFFEAF1EF);       // Chips y fondos secundarios
  static const Color borderSubtle = Color(0xFFE2EAE7);       // Bordes suaves

  // 2. Primario y Marca (Verde Salvia)
  static const Color primarySage = Color(0xFF7EAE9B);        // Botón CTA y anillo activo
  static const Color primarySageDark = Color(0xFF659683);    // Hover / Pressed
  static const Color primarySageLight = Color(0xFFBED6CD);   // Botones secundarios / Anillo fondo

  // 3. Tipografía y Textos
  static const Color textPrimary = Color(0xFF192A24);        // Títulos y números (Bosque profundo)
  static const Color textSecondary = Color(0xFF62756E);      // Subtítulos y etiquetas
  static const Color textMuted = Color(0xFF8B9E97);          // Textos desactivados

  // 4. Mascota Locky y Acentos Lúdicos
  static const Color terracottaBrown = Color(0xFFA67358);    // Pelaje de Locky
  static const Color terracottaDark = Color(0xFF7D4F38);     // Contornos / Ojos
  static const Color peachCream = Color(0xFFF5DACB);         // Hocico / Tarjetas de premio

  // 5. Estados de Sesión (FSM)
  static const Color focusChipBg = Color(0xFFFCEAE4);
  static const Color focusChipText = Color(0xFFD96B4F);      // Enfoque / Locked
  static const Color breakChipBg = Color(0xFFE2F1E8);
  static const Color breakChipText = Color(0xFF489468);      // Descanso / Unlocked
  static const Color graceChipBg = Color(0xFFFFF0D9);
  static const Color graceChipText = Color(0xFFE08A26);      // Ventana de gracia

  // 6. Categorías de Agenda (Figma)
  static const Color catUniversityBg = Color(0xFFDDECF6);
  static const Color catUniversityText = Color(0xFF3B82A6);
  static const Color catFreelanceBg = Color(0xFFF7F2E2);
  static const Color catFreelanceText = Color(0xFF947F35);
  static const Color catPersonalBg = Color(0xFFE2F1E8);
  static const Color catPersonalText = Color(0xFF489468);

  // Aliases de compatibilidad para evitar roturas
  static const Color background = scaffoldBackground;
  static const Color surface = surfaceCard;
  static const Color border = borderSubtle;
  static const Color focusRed = focusChipText;
  static const Color breakGreen = breakChipText;
  static const Color graceOrange = graceChipText;
  static const Color waitingBlue = primarySage;
  static const Color accentCyan = primarySage;
}
