import 'package:flutter/material.dart';
import 'package:poker_planning/config/theme.dart'; // Assicurati che i percorsi e le variabili siano corretti

class VotingCardsRow extends StatelessWidget {
  final List<String> cardValues;
  final String? selectedVote;
  final bool cardsRevealed; // Per disabilitare il tap
  final Function(String) onVoteSelected;

  const VotingCardsRow({
    Key? key,
    required this.cardValues,
    required this.selectedVote,
    required this.cardsRevealed,
    required this.onVoteSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (cardsRevealed) { // Se le carte sono rivelate, non mostrare le carte per votare
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 150,
      child: Center(
        child: ListView.builder(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          itemCount: cardValues.length,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          itemBuilder: (context, index) {
            final value = cardValues[index];
            final isSelected = selectedVote == value;
            final canVote = !cardsRevealed;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 4.0),
              child: GestureDetector(
                onTap: canVote ? () => onVoteSelected(value) : null,
                child: Opacity(
                  opacity: canVote ? 1.0 : 0.6,
                  child: Tooltip(
                    message: "Vote: $value",
                    child: buildContainer(isSelected, value),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Stack buildStack(bool isSelected, String value) {
    return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Contenitore interno per lo sfondo del numero principale
                      Container(
                        width: 60,
                        height: 100,
                        decoration: BoxDecoration(
                          color: isSelected? lightBlueGrey : Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(4), // Raggio leggermente più piccolo
                        ),
                      ),
                      // Numero grande centrale
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                      // Numero piccolo in alto a sinistra
                      Positioned(
                        top: 6,
                        left: 4,
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(bottomRight: Radius.circular(8))),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: Center(
                              child: Text(
                                value,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Numero piccolo in basso a destra
                      Positioned(
                        bottom: 6,
                        right: 4,
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(8))),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: Center(
                              child: Text(
                                value,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
  }

  Container buildContainer(bool isSelected, String value) {
    return Container(
                    width: 80,
                    height: 120,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color:  Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? primaryBlue
                            : Colors.blueGrey.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? primaryBlue.withOpacity(0.3)
                              : Colors.black.withOpacity(0.08),
                          blurRadius: isSelected ? 8 : 4,
                          spreadRadius: isSelected ? 1 : 0,
                          offset: Offset(0, isSelected ? 4 : 2),
                        )
                      ],
                    ),
                    child: buildStack(isSelected, value)
                  );
  }
}