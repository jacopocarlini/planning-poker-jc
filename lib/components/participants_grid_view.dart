import 'package:flutter/material.dart';
import 'package:poker_planning/components/participant_card.dart'; // Assicurati che il percorso sia corretto
import 'package:poker_planning/models/participant.dart';

class ParticipantsGridView extends StatelessWidget {
  final List<Participant> participants;
  final bool cardsRevealed;
  final String myParticipantId;
  final Future<void> Function(String participantId, String participantName) onKickParticipant;
  // Aggiungi isCreator se ParticipantCard ne ha bisogno direttamente o per logica qui
  // final bool isCreator;


  const ParticipantsGridView({
    Key? key,
    required this.participants,
    required this.cardsRevealed,
    required this.myParticipantId,
    required this.onKickParticipant,
    // required this.isCreator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Text("No participants yet. Share the link to invite them!",
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Team Members: ${participants.length}',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 20.0,
            runSpacing: 24.0,
            children: participants.map((participant) {
              return ParticipantCard(
                key: ValueKey(participant.id),
                participant: participant,
                cardsRevealed: cardsRevealed,
                isMe: participant.id == myParticipantId,
                onKick: onKickParticipant,
                // Passa isCreator se necessario a ParticipantCard
                // isCreator: isCreator && participant.id != myParticipantId, // Esempio: creator può kickare altri
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}