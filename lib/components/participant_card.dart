// Place this class below the _PlanningRoomState class or in a separate file

import 'package:flutter/material.dart';
import 'package:poker_planning/config/theme.dart';
import 'package:poker_planning/models/participant.dart';

class ParticipantCard extends StatefulWidget {
  final Participant participant;
  final bool cardsRevealed;
  final bool isMe;
  final Future<void> Function(String participantId, String participantName) onKick; // Callback

  const ParticipantCard({
    Key? key,
    required this.participant,
    required this.cardsRevealed,
    required this.isMe,
    required this.onKick,
  }) : super(key: key);

  @override
  _ParticipantCardState createState() => _ParticipantCardState();
}

class _ParticipantCardState extends State<ParticipantCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final vote = widget.participant.vote;
    final hasVoted = vote != null && vote.isNotEmpty;
    final canBeKicked = !widget.isMe; // Only creator can kick others

    return MouseRegion(
      onEnter: (_) {
        if (canBeKicked) { // Only show hover effect if kick is possible
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
          Stack( // Use Stack to overlay the kick button
            clipBehavior: Clip.none, // Allow button to overflow slightly if needed
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 120,
                decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    border: Border.all(
                      color: widget.isMe ? primaryBlue : Colors.blueGrey.shade200,
                      width: widget.isMe ? 2.5 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ]),
                child: Stack( // Inner stack for card content
                  alignment: Alignment.center,
                  children: [
                    // Revealed State
                    if (widget.cardsRevealed)
                      hasVoted
                          ? Text(
                        vote!,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade800,
                        ),
                      )
                          : Icon(Icons.question_mark,
                          size: 40, color: Colors.grey.shade400),
                    // Hidden State
                    if (!widget.cardsRevealed)
                      hasVoted
                          ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.green.shade500, width: 1.5)),
                          child: Icon(Icons.check,
                              color: Colors.green.shade600,
                              size: 28),
                        ),
                      )
                          : Icon(Icons.hourglass_empty,
                          size: 30, color: Colors.blueGrey.shade300),
                  ],
                ),
              ),
              // --- Kick Button ---
              if (canBeKicked && _isHovering)
                Positioned(
                  top: -10, // Adjust position as needed
                  right: -10, // Adjust position as needed
                  child: Material( // Provides elevation and shape
                    color: Colors.redAccent,
                    shape: const CircleBorder(),
                    elevation: 4.0,
                    child: InkWell( // Clickable area
                      customBorder: const CircleBorder(),
                      onTap: () {
                        // Call the kick callback
                        widget.onKick(widget.participant.id, widget.participant.name);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4.0), // Padding inside the circle
                        child: Icon(
                          Icons.close, // The 'X' icon
                          color: Colors.white,
                          size: 18.0, // Adjust size as needed
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
            child: Text(
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
          ),
        ],
      ),
    );
  }
}