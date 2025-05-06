// lib/widgets/geometric_card_pattern_painter.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'theme.dart';

class GeometricCardPatternPainter extends CustomPainter {
  final int seed; // Per variare il pattern o mantenerlo fisso

  GeometricCardPatternPainter({this.seed = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    // Palette di colori ispirata all'immagine
    final List<Color> blues = [
      accentYellow, // Blu notte molto scuro
      const Color(0xFF1E3D58), // Blu scuro desaturato
      const Color(0xFF3E6D9C), // Blu acciaio
      const Color(0xFF669BBC), // Blu medio chiaro
      const Color(0xFFADCDE1), // Blu polvere chiaro
    ];
    // Colore chiaro per contrasto, simile al bianco/grigio chiaro nell'immagine
    final Color lightContrastColor = const Color(0xFFE0E0E0); // Un grigio molto chiaro

    // Dimensione della cella base del pattern.
    // Una carta è 80x120. Scegliamo una dimensione che crei una griglia gradevole.
    final double cellSize = 20.0; // Produce una griglia di 4x6 celle sulla carta
    final int numCols = (size.width / cellSize).ceil();
    final int numRows = (size.height / cellSize).ceil();

    for (int r = 0; r < numRows; r++) {
      for (int c = 0; c < numCols; c++) {
        final cellRect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
        final paint = Paint()..style = PaintingStyle.fill;

        // 1. Colore di sfondo per la cella (un blu a caso dalla palette)
        paint.color = blues[random.nextInt(blues.length)];
        canvas.drawRect(cellRect, paint);

        // 2. Elemento geometrico sovrapposto
        // Scegli un colore per l'elemento che contrasti con lo sfondo della cella
        Color elementColor;
        if (random.nextDouble() < 0.7) { // 70% di probabilità di usare un altro blu
          do {
            elementColor = blues[random.nextInt(blues.length)];
          } while (elementColor == paint.color && blues.length > 1);
        } else { // 30% di probabilità di usare il colore chiaro di contrasto
          elementColor = lightContrastColor;
        }
        paint.color = elementColor;

        // Scegli casualmente quale elemento disegnare
        int elementType = random.nextInt(6); // 0: cerchio, 1-4: quarto di cerchio, 5: cella piena (rara)

        if (elementType == 0) { // Cerchio piccolo al centro della cella
          canvas.drawCircle(cellRect.center, cellSize * 0.25, paint);
        } else if (elementType < 5) { // Quarto di cerchio
          final path = Path();
          // L'angolo della cella che sarà il centro del cerchio da cui si prende l'arco
          int orientation = random.nextInt(4); // 0:TL, 1:TR, 2:BR, 3:BL

          switch (orientation) {
            case 0: // Angolo Alto-Sinistra (TL) come centro dell'arco
              path.moveTo(cellRect.left, cellRect.top);
              path.lineTo(cellRect.left + cellSize, cellRect.top); // Lato superiore
              path.arcTo(Rect.fromCircle(center: cellRect.topLeft, radius: cellSize), 0, math.pi / 2, false);
              path.lineTo(cellRect.left, cellRect.top); // Chiude al punto iniziale
              break;
            case 1: // Angolo Alto-Destra (TR)
              path.moveTo(cellRect.right, cellRect.top);
              path.lineTo(cellRect.right, cellRect.top + cellSize); // Lato destro
              path.arcTo(Rect.fromCircle(center: cellRect.topRight, radius: cellSize), math.pi / 2, math.pi / 2, false);
              path.lineTo(cellRect.right, cellRect.top);
              break;
            case 2: // Angolo Basso-Destra (BR)
              path.moveTo(cellRect.right, cellRect.bottom);
              path.lineTo(cellRect.left, cellRect.bottom); // Lato inferiore
              path.arcTo(Rect.fromCircle(center: cellRect.bottomRight, radius: cellSize), math.pi, math.pi / 2, false);
              path.lineTo(cellRect.right, cellRect.bottom);
              break;
            case 3: // Angolo Basso-Sinistra (BL)
              path.moveTo(cellRect.left, cellRect.bottom);
              path.lineTo(cellRect.left, cellRect.top); // Lato sinistro
              path.arcTo(Rect.fromCircle(center: cellRect.bottomLeft, radius: cellSize), 3 * math.pi / 2, math.pi / 2, false);
              path.lineTo(cellRect.left, cellRect.bottom);
              break;
          }
          path.close();
          canvas.drawPath(path, paint);
        } else { // Cella piena con il colore dell'elemento (rara, per varietà)
          canvas.drawRect(cellRect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GeometricCardPatternPainter oldDelegate) {
    return oldDelegate.seed != seed; // Ridisegna se il seed cambia
  }
}