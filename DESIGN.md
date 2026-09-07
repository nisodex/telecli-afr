---
name: Movistar AFR 5G Field Technician
version: 1.0.0
description: Design tokens and UI rationale for the Movistar AFR 5G Antenna Alignment Android app.
colors:
  primary: "#00A9E0"          # Movistar Cyan Blue
  primaryDark: "#0B2742"      # Deep Movistar Navy
  primaryContainer: "#003254" # Surface container blue
  background: "#080C14"       # OLED Deep Black for outdoor sunlight contrast
  surface: "#111827"          # Card surface dark slate
  surfaceVariant: "#1F2937"   # Secondary container
  onPrimary: "#FFFFFF"
  onBackground: "#F3F4F6"
  onSurface: "#E5E7EB"
  onSurfaceVariant: "#9CA3AF"
  accent5G: "#00E676"         # High-visibility 5G n78 green (3.5 GHz)
  accent5GLow: "#00B0FF"      # 5G n28 blue (700 MHz)
  accent4G: "#FFB300"         # 4G LTE amber
  accentWarning: "#FF9100"
  accentError: "#FF5252"
  laserBeam: "#00E676"        # Line of sight indicator
  compassRing: "#374151"
  compassNeedleTarget: "#00E676"
  compassNeedleCurrent: "#00A9E0"
typography:
  fontFamily: "Roboto"
  displayLarge: "34sp, Bold"
  headlineMedium: "24sp, Bold"
  titleLarge: "20sp, SemiBold"
  titleMedium: "16sp, SemiBold"
  bodyLarge: "15sp, Regular"
  bodyMedium: "13sp, Regular"
  labelLarge: "14sp, Medium"
  labelSmall: "11sp, Medium"
spacing:
  xs: 4
  sm: 8
  md: 16
  lg: 24
  xl: 32
rounded:
  sm: 8
  md: 14
  lg: 20
  full: 999
components:
  touchTargetMin: 48
  gaugeHeight: 280
  cardElevation: 2
---

# Movistar AFR 5G - Especificación de Diseño

## Overview
Esta aplicación está diseñada para técnicos de campo de Movistar encargados de la instalación de antenas exteriores de **Acceso Fijo Radio 5G (AFR 5G)** en tejados, fachadas y mástiles. Los técnicos trabajan en condiciones ambientales exigentes: luz solar directa, uso con una sola mano, guantes y manos ocupadas con herramientas mecánicas.

## Colors
- **Paleta Movistar:** Azul corporativo `#00A9E0` combinado con azul marino profundo `#0B2742`.
- **Fondo OLED Dark (`#080C14`):** Maximiza el contraste bajo el sol, ahorra batería en jornadas intensivas de trabajo de campo y previene el sobrecalentamiento de la pantalla.
- **Colores Semánticos de Red:**
  - **Verde 5G n78 (`#00E676`):** Indica la banda de alta velocidad 3.5 GHz (gNodeB óptima para AFR 5G).
  - **Azul 5G n28 (`#00B0FF`):** Indica cobertura 700 MHz de largo alcance rural.
  - **Ámbar 4G (`#FFB300`):** Celdas 4G LTE (fallback).

## Typography
Uso del sistema de tipografía Material Design 3 con Roboto, optimizado con tamaños legibles a distancia de brazo extendido en el mástil.

## Layout & Touch Psychology
- **Fitts' Law y Zona del Pulgar:** Todos los botones críticos y acciones principales (Alinear, Centrar GPS, Cambiar Modo) se ubican en la mitad inferior de la pantalla.
- **Tamaño mínimo táctil:** 48dp de altura y anchura mínima en todos los botones e interactivos.
- **Espaciado preventivo:** Mínimo 12dp entre controles para evitar toques accidentales con guantes de trabajo.

## Elevation & Depth
Superficies oscuras con elevaciones sutiles y bordes contrastados para diferenciar secciones sin saturar visualmente al usuario.

## Do's and Don'ts
- **DO:** Usar indicadores de gran contraste para azimut y grados de desviación.
- **DO:** Proporcionar respuesta háptica (vibración) y acústica al alcanzar la alineación sin forzar a mirar la pantalla.
- **DON'T:** No usar fondos claros que deslumbren al técnico bajo el sol o consuman batería excesiva.
- **DON'T:** No obligar a introducir texto complejo en campo: las búsquedas por GPS y coordenadas deben ser automáticas.
