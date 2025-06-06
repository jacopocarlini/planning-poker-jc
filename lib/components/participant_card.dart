import 'dart:math' as math; // Per math.pi

import 'package:flutter/material.dart';
import 'package:poker_planning/config/geometric_card_pattern_painter.dart';
import 'package:poker_planning/config/theme.dart'; // Assicurati che primaryBlue sia definito qui
import 'package:poker_planning/models/participant.dart';
import 'package:poker_planning/services/firebase_service.dart';
import 'package:provider/provider.dart';

import '../services/user_preferences_service.dart';

class ParticipantCard extends StatefulWidget {
  final Participant participant;
  final String roomId;
  final bool cardsRevealed;
  final bool isMe;
  final Future<void> Function(String participantId, String participantName)
      onKick;

  const ParticipantCard({
    super.key,
    required this.participant,
    required this.roomId,
    required this.cardsRevealed,
    required this.isMe,
    required this.onKick,
  });

  @override
  _ParticipantCardState createState() => _ParticipantCardState();
}

class _ParticipantCardState extends State<ParticipantCard>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  final _prefsService = UserPreferencesService();
  late RealtimeFirebaseService _firebaseService;

  // Variabili per l'animazione
  late AnimationController _animationController; // <--- AGGIUNTO
  late Animation<double> _animation; // <--- AGGIUNTO
  num? _lastTrillValue; // Per tenere traccia del valore precedente del trillo

  @override
  void initState() {
    super.initState();
    _firebaseService =
        Provider.of<RealtimeFirebaseService>(context, listen: false);

    // Inizializza il controller dell'animazione
    _animationController = AnimationController(
      // <--- AGGIUNTO
      duration: const Duration(milliseconds: 500), // Durata dell'animazione
      vsync: this,
    );

    // Definisci l'animazione (un effetto "shake")
    _animation = TweenSequence<double>([
      // <--- AGGIUNTO
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.03), weight: 1),
      // ruota a dx
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.03, end: -0.03), weight: 1),
      // ruota a sx
      TweenSequenceItem(
          tween: Tween<double>(begin: -0.03, end: 0.03), weight: 1),
      // ruota a dx
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.03, end: -0.03), weight: 1),
      // ruota a sx
      TweenSequenceItem(
          tween: Tween<double>(begin: -0.03, end: 0.0), weight: 1),
      // torna al centro
    ]).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    // Oppure un'animazione più elastica:
    // _animation = Tween<double>(begin: 0, end: 1).animate(
    //   CurvedAnimation(parent: _animationController, curve: Curves.elasticInOut)
    // )..addListener(() { setState(() {}); }); // Se non usi AnimatedBuilder e vuoi ricostruire con setState

    // Salva il valore iniziale del trillo
    _lastTrillValue = widget.participant.trill;
  }

  @override
  void didUpdateWidget(ParticipantCard oldWidget) {
    // <--- AGGIUNTO
    super.didUpdateWidget(oldWidget);
    // Controlla se il valore del trillo è cambiato e non è nullo
    // Questo assume che `widget.participant.trill` sia un timestamp o un contatore
    // che viene aggiornato in Firebase quando un trillo viene inviato A QUESTO partecipante.
    if (widget.participant.trill != _lastTrillValue) {
      //print("Trill detected for ${widget.participant.name}! Old: $_lastTrillValue, New: ${widget.participant.trill}");
      if (mounted) {
        // Assicurati che il widget sia ancora montato
        if (widget.participant.trill != 0)
          _animationController.forward(
              from: 0.0); // Avvia l'animazione dalla sua posizione iniziale
      }
      _lastTrillValue =
          widget.participant.trill; // Aggiorna l'ultimo valore del trillo
    }
  }

  @override
  void dispose() {
    _animationController
        .dispose(); // <--- AGGIUNTO: Non dimenticare di fare dispose!
    super.dispose();
  }

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
              AnimatedBuilder(
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _animation.value * math.pi,
                    // Converte radianti per shake (o usa direttamente radianti nel Tween)
                    // Se usi un Tween da 0 a 1 per Curves.elasticInOut:
                    // angle: math.sin(_animation.value * math.pi * 2) * 0.05, // Esempio per effetto elastico
                    child: child,
                  );
                },
                animation: _animation,
                child: Container(
                  width: 80,
                  height: 120,
                  decoration: cardDecoration,
                  child: cardContent,
                ),
              ),
              if (canBeKicked && _isHovering && !hasVoted)
                Positioned(
                    top: -10,
                    left: -10,
                    child: Tooltip(
                      message: 'Trill!',
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 4.0,
                        child: InkWell(
                            onTap: () async {
                              sendNudgeSignalViaFirestore(
                                  senderId: (await _prefsService.getId()) ?? '',
                                  senderName:
                                      (await _prefsService.getUsername() ?? ''),
                                  recipientId: widget.participant.id,
                                  recipientName: widget.participant.name,
                                  context: context);
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(
                                color: accentOrange,
                                Icons.notifications_none_outlined,
                              ),
                            )),
                      ),
                    )),
              if (canBeKicked && _isHovering)
                Positioned(
                  top: -10,
                  right: -10,
                  child: Material(
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
                    fontWeight:
                        widget.isMe ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                if ((widget.participant.trill ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.notifications_active_outlined),
                  )
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
    if (recipientId == senderId) {
      return;
    }

    try {
      final nudgePayload = {
        'recipientId': recipientId,
        'senderId': senderId,
        'senderName': senderName,
        'title': 'Trill! 🔔',
        'body': '$senderName sent you a trill!',
        'timestamp': DateTime.now().toUtc(),
        'read': false,
        'type': 'web_nudge',
      };
      await _firebaseService.sendNudgeSignal(widget.roomId, nudgePayload);
      // await FirebaseFirestore.instance
      //     .collection('webNudges')
      //     .add(nudgePayload);
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending trill: ${e.toString()}')),
        );
      }
    }
  }
}
