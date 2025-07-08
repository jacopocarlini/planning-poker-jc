import 'package:flutter/material.dart';
import 'package:poker_planning/config/theme.dart'; // Assicurati che il percorso e le variabili (primaryBlue, accentYellow) siano corretti

class RevealResetButton extends StatelessWidget {
  final bool cardsRevealed;
  final bool canReveal; // True se !cardsRevealed && someoneVoted
  final bool canReset;  // True se cardsRevealed
  final VoidCallback onReveal;
  final VoidCallback onReset;
  final VoidCallback onNextVote;
  final bool hasNextVote;
  final String nextTask;

  const RevealResetButton({
    super.key,
    required this.cardsRevealed,
    required this.canReveal,
    required this.canReset,
    required this.onReveal,
    required this.onReset,
    required this.onNextVote,
    required this.hasNextVote,
    required this.nextTask,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
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
          icon: Icon(cardsRevealed ? Icons.refresh : Icons.visibility),
          label: Text(cardsRevealed ? 'Reset Voting' : 'Reveal Cards'),
        ),

        SizedBox(width: 16,),


        hasNextVote?
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: hasNextVote ? onNextVote : null,
          icon: Icon(Icons.next_plan_outlined),
          label: Text('Vote for the ${nextTask}° Task'),
        )
            :
            OutlinedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: null,
                icon: Icon(Icons.next_plan_outlined),
                label: Text('No other tasks'))
      ],
    );
  }
}