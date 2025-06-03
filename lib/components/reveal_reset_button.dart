import 'package:flutter/material.dart';
import 'package:poker_planning/config/theme.dart'; // Assicurati che il percorso e le variabili (primaryBlue, accentYellow) siano corretti

class RevealResetButton extends StatelessWidget {
  final bool cardsRevealed;
  final bool canReveal; // True se !cardsRevealed && someoneVoted
  final bool canReset;  // True se cardsRevealed
  final VoidCallback onReveal;
  final VoidCallback onReset;

  const RevealResetButton({
    super.key,
    required this.cardsRevealed,
    required this.canReveal,
    required this.canReset,
    required this.onReveal,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        backgroundColor: cardsRevealed ? accentYellow : primaryBlue,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        disabledBackgroundColor: Colors.grey.shade300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: cardsRevealed
          ? (canReset ? onReset : null)
          : (canReveal ? onReveal : null),
      icon: Icon(cardsRevealed ? Icons.refresh : Icons.remove_red_eye_outlined),
      label: Text(cardsRevealed ? 'Reset Voting' : 'Reveal Cards'),
    );
  }
}