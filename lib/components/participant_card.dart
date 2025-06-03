import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:poker_planning/config/geometric_card_pattern_painter.dart';
import 'package:poker_planning/config/theme.dart'; // Assicurati che primaryBlue sia definito qui
import 'package:poker_planning/models/participant.dart';

import '../services/user_preferences_service.dart';

class ParticipantCard extends StatefulWidget {
  final Participant participant;
  final bool cardsRevealed;
  final bool isMe;
  final int? notifications;
  final Future<void> Function(String participantId, String participantName)
      onKick;

  const ParticipantCard({
    super.key,
    required this.participant,
    required this.cardsRevealed,
    required this.isMe,
    required this.notifications,
    required this.onKick,
  });

  @override
  _ParticipantCardState createState() => _ParticipantCardState();
}

class _ParticipantCardState extends State<ParticipantCard> {
  bool _isHovering = false;
  final _prefsService = UserPreferencesService();


  @override
  Widget build(BuildContext context) {
    final vote = widget.participant.vote;
    final hasVoted = vote != null && vote.isNotEmpty;
    final canBeKicked = !widget.isMe; // Creator can kick others

    Widget cardContent;
    BoxDecoration cardDecoration;

    // Definisci lo stile del bordo comune
    Border commonBorder = Border.all(
      color: widget.isMe ? primaryBlue : Colors.blueGrey.shade200,
      width: widget.isMe ? 2.5 : 1.5,
    );
    // Definisci l'ombra comune
    List<BoxShadow> commonBoxShadow = [
      BoxShadow(
        color: Colors.grey.withOpacity(0.2),
        spreadRadius: 1,
        blurRadius: 3,
        offset: const Offset(0, 2),
      ),
    ];

    if (!widget.cardsRevealed) {
      // Stato: CARTE NASCOSTE
      if (hasVoted) {
        // 2. Votato ma Nascosto: Retro della carta blu con pattern generato
        // 2. Votato ma Nascosto: Retro della carta blu con pattern generato
        cardDecoration = BoxDecoration(
            border: commonBorder,
            borderRadius: BorderRadius.circular(8),
            boxShadow: commonBoxShadow,
            // Non impostare colore o immagine qui, il CustomPaint lo gestirà
            // Puoi aggiungere un colore di sfondo qui se vuoi che lo spazio
            // attorno al CustomPaint più piccolo abbia un colore specifico.
            // Esempio: color: Colors.blueGrey.shade700,
            color: Colors.white);
        // Definisci le dimensioni desiderate per il disegno del CustomPaint
        const double desiredPaintWidth = 60.0; // Esempio: più piccolo
        const double desiredPaintHeight = 100.0; // Esempio: più piccolo

        cardContent = ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Center(
            // << NUOVO: Centra il SizedBox
            child: SizedBox(
              // << NUOVO: Controlla la dimensione del CustomPaint
              width: desiredPaintWidth,
              height: desiredPaintHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: CustomPaint(
                  // size: Size.infinite, // CustomPaint prenderà la dimensione del SizedBox
                  // oppure puoi specificarlo di nuovo ma non è strettamente necessario se è dentro SizedBox
                  size: const Size(desiredPaintWidth, desiredPaintHeight),
                  painter: GeometricCardPatternPainter(
                    seed: widget.participant.id.hashCode % 1000,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        // 1. Non Votato (Carta non posizionata): Rettangolo grigio
        cardDecoration = BoxDecoration(
          color: Colors.grey.shade200,
          border: commonBorder,
          borderRadius: BorderRadius.circular(8),
          boxShadow: commonBoxShadow,
        );
        cardContent = Center(
          child: Icon(
            Icons.hourglass_bottom_rounded,
            size: 30,
            color: Colors.grey.shade200,
          ),
        );
      }
    } else {
      // Stato: CARTE RIVELATE
      cardDecoration = BoxDecoration(
        color: Colors.white, // Sfondo bianco per carte rivelate
        border: commonBorder,
        borderRadius: BorderRadius.circular(8),
        boxShadow: commonBoxShadow,
      );

      if (hasVoted) {
        // 3. Votato e Rivelato: Numero grande + numeri piccoli angoli
        cardContent = Stack(
          alignment: Alignment.center,
          children: [
            // Contenitore interno per lo sfondo del numero principale
            Container(
              width: 60,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius:
                    BorderRadius.circular(4), // Raggio leggermente più piccolo
              ),
            ),
            // Numero grande centrale
            Text(
              vote,
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
                    borderRadius:
                        BorderRadius.only(bottomRight: Radius.circular(8))),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: Center(
                    child: Text(
                      vote,
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
                    borderRadius:
                        BorderRadius.only(topLeft: Radius.circular(8))),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: Center(
                    child: Text(
                      vote,
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
      } else {
        // 4. Non Votato e Rivelato: Punto interrogativo
        cardDecoration = BoxDecoration(
          color: Colors.grey.shade200,
          border: commonBorder,
          borderRadius: BorderRadius.circular(8),
          boxShadow: commonBoxShadow,
        );
        cardContent = Center(
          child: Icon(
            Icons.hourglass_bottom_rounded,
            size: 30,
            color: Colors.grey.shade200,
          ),
        );
      }
    }

    return MouseRegion(
      onEnter: (_) {
        if (canBeKicked) {
          setState(() => _isHovering = true);
        }
      },
      onExit: (_) {
        if (canBeKicked) {
          setState(() => _isHovering = false);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 120,
                decoration: cardDecoration,
                child: cardContent,
              ),
              if (true || canBeKicked && _isHovering )
                Positioned(
                  top: -10,
                  right: -10,
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'Trill!',
                        child: IconButton(
                            onPressed: () async {
                              sendNudgeSignalViaFirestore(
                                  senderId: (await _prefsService.getId()) ?? '',
                              senderName: (await _prefsService.getUsername() ?? ''),
                              recipientId: widget.participant.id,
                              recipientName: widget.participant.name,
                              context: context);
                            },
                            icon: const Icon(
                              Icons.notifications_none_outlined,
                              color: Colors.amber,
                            )),
                      ),
                      Material(
                        color: Colors.redAccent,
                        shape: const CircleBorder(),
                        elevation: 4.0,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            widget.onKick(
                                widget.participant.id, widget.participant.name);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.participant.name + (widget.isMe ? ' (You)' : ''),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontWeight: widget.isMe ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                if (widget.notifications != null && widget.notifications! > 0) Icon(Icons.notifications_active_outlined)
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Nella tua ParticipantCard o un servizio helper

// Funzione per inviare il segnale di trillo tramite Firestore
  Future<void> sendNudgeSignalViaFirestore({
    required String recipientId,
    required String
        recipientName, // Nome del destinatario (opzionale, per logging o UI mittente)
    required String senderId, // Il tuo ID
    required String senderName, // Il tuo nome
    required BuildContext context, // Per ScaffoldMessenger
  }) async {

    // if (recipientId == senderId) {
    //   return;
    // }

    try {
      final nudgePayload = {
        'recipientId': recipientId,
        'senderId': senderId,
        'senderName': senderName,
        'title': 'Trill! 🔔',
        'body': '$senderName sent you a trill!',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'web_nudge',
      };
      await FirebaseFirestore.instance
          .collection('webNudges')
          .add(nudgePayload);

    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending trill: ${e.toString()}')),
        );
      }
      print('Error sending web nudge signal: $e');
    }
  }
}
