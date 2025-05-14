import 'dart:async';
import 'dart:html' as html; // Needed for window.history, window.location

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:poker_planning/components/participants_grid_view.dart';
import 'package:poker_planning/components/reveal_reset_button.dart';
import 'package:poker_planning/components/share_room_dialog_content.dart';
import 'package:poker_planning/components/user_profile_chip.dart'; // Assicurati che il percorso sia corretto
import 'package:poker_planning/components/vote_results_summary_view.dart';
import 'package:poker_planning/components/voting_cards_row.dart';
import 'package:poker_planning/models/participant.dart';
import 'package:poker_planning/models/room.dart';
import 'package:poker_planning/services/firebase_service.dart';
import 'package:poker_planning/services/user_preferences_service.dart';
import 'package:provider/provider.dart';

// --- Planning Room Widget ---
class PlanningRoom extends StatefulWidget {
  // Rinominato per chiarezza
  final String roomId;
  final String currentParticipantId;
  final String currentUserName;
  final bool isSpectator;

  const PlanningRoom({
    // Rinominato per chiarezza
    Key? key,
    required this.roomId,
    required this.currentParticipantId,
    required this.currentUserName,
    required this.isSpectator,
  }) : super(key: key);

  @override
  State<PlanningRoom> createState() =>
      _PlanningRoomState(); // Rinominato per chiarezza
}

class _PlanningRoomState extends State<PlanningRoom> {
  // Rinominato per chiarezza
  late RealtimeFirebaseService _firebaseService;
  StreamSubscription<Room>? _roomSubscription;
  Room? _currentRoom;
  Participant? _me;
  late String _myParticipantId;
  String? _selectedVote;
  bool _isLoading = true;
  bool _presenceSetupDone = false;

  // final TextEditingController _nameController = TextEditingController(); // Non più usato direttamente qui se _saveProfile è aggiornato
  final _prefsService = UserPreferencesService();

  @override
  void initState() {
    super.initState();
    _firebaseService =
        Provider.of<RealtimeFirebaseService>(context, listen: false);
    _myParticipantId = widget.currentParticipantId;

    _subscribeToRoomUpdates();
    _setupPresenceIfNeeded();
    _updatePageUrlIfNeeded();
  }

  void _subscribeToRoomUpdates() {
    if (_roomSubscription != null) return;

    setState(() {
      _isLoading = true;
    });

    _roomSubscription =
        _firebaseService.getRoomStream(widget.roomId).listen((room) async {
          if (!mounted) return;

          final bool amIStillInRoom =
          room.participants.any((p) => p.id == _myParticipantId);

          if (!amIStillInRoom && _currentRoom != null) {
            print(
                "User $_myParticipantId detected removal from room ${widget
                    .roomId}. Navigating back.");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You have been removed from the room.'),
                backgroundColor: Colors.orangeAccent,
                duration: Duration(seconds: 3),
              ),
            );
            await _roomSubscription?.cancel();
            _roomSubscription = null;
            if (mounted) {
              Navigator.of(context).pop();
            }
            return;
          }

          setState(() {
            _currentRoom = room;
              _me = room.participants
                  .firstWhereOrNull((p) => p.id == _myParticipantId);
            if (!room.areCardsRevealed) {
              _selectedVote = _me?.vote;
            } else {
              _selectedVote = room.participants
                  .firstWhereOrNull((p) => p.id == _myParticipantId)
                  ?.vote;
            }
            _isLoading = false;
          });
        }, onError: (error) {
          if (!mounted) return;
          print("Error in room stream for ${widget.roomId}: $error");
          setState(() {
            _isLoading = false;
            _currentRoom = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Error loading room: $error. You might need to leave.'),
              backgroundColor: Colors.red));
        }, onDone: () {
          if (!mounted) return;
          print("Room stream for ${widget.roomId} closed.");
          if (ModalRoute
              .of(context)
              ?.isCurrent ?? false) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Connection to the room closed.'),
                backgroundColor: Colors.grey));
            Navigator.of(context).pop();
          }
        });
  }

  void _updatePageUrlIfNeeded() {
    if (_myParticipantId.isEmpty) {
      return;
    }
    final currentPath = html.window.location.pathname ?? '';
    final targetPath = '/room/${widget.roomId}';
    if (currentPath != targetPath) {
      html.window.history
          .pushState(null, 'Poker Planning Room ${widget.roomId}', targetPath);
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _roomSubscription = null;
    // _nameController.dispose(); // Non più usato
    super.dispose();
  }

  Future<void> _selectVote(String value) async {
    if (_currentRoom != null && _currentRoom!.areCardsRevealed) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final previousVote = _selectedVote;

    setState(() {
      _selectedVote = value;
    });

    try {
      await _firebaseService.submitVote(
        roomId: widget.roomId,
        participantId: _myParticipantId,
        vote: value,
      );
    } catch (e) {
      if (mounted && _selectedVote == value) {
        setState(() {
          _selectedVote = previousVote;
        });
      }
      messenger.showSnackBar(SnackBar(
          content: Text('Failed to submit vote: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _revealCards() async {
    if (_currentRoom != null && _currentRoom!.areCardsRevealed) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _firebaseService.revealCards(roomId: widget.roomId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Failed to reveal cards: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _resetVoting() async {
    if (_currentRoom != null && !_currentRoom!.areCardsRevealed) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _firebaseService.resetVoting(roomId: widget.roomId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Failed to reset voting: $e'),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Room? room = _currentRoom;
    final bool isLoading =
        _isLoading || (room == null && _roomSubscription != null);

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Room...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 16),
                const Text(
                  'Could not load room details. The room may not exist or there was a connection issue.',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                )
              ],
            ),
          ),
        ),
      );
    }

    final participants =
    room.participants.where((p) => !p.isSpectator).toList();
    final spectators =
    room.participants.where((p) => p.isSpectator).toList();
    final cardValues = room.cardValues;
    final cardsRevealed = room.areCardsRevealed;

    final bool someoneVoted =
    room.participants.any((p) => p.vote != null && p.vote!.isNotEmpty);
    final bool canReveal = !cardsRevealed && someoneVoted;
    final bool canReset = cardsRevealed;

    return Scaffold(
      appBar: AppBar(
        title: Text('Planning Poker ♠️'),
        // Show user's name
        actions: [
          UserProfileChip(onTap: _saveProfile),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Invite Teammates'),
            onPressed: _showShareDialog,
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(
              children: [
              Positioned(left: 0, top: 0,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text("👀 Spectators: ${spectators.length}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      ...spectators.map((elem)=> Text(elem.name))
                    ],
                  ),
                ),
              ),
              ),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: ParticipantsGridView(
                    participants: participants,
                    cardsRevealed: cardsRevealed,
                    myParticipantId: _myParticipantId,
                    onKickParticipant: _showKickConfirmationDialog,
                    // isCreator: _myParticipantId == room.creatorId, // Esempio se necessario
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (cardsRevealed)
                SizedBox(
                    height: MediaQuery
                        .sizeOf(context)
                        .height / 2,
                    child: VoteResultsSummaryView(room: room))
              else
                if (_me?.isSpectator == false)
                  VotingCardsRow(
                    cardValues: cardValues,
                    selectedVote: _selectedVote,
                    cardsRevealed: cardsRevealed,
                    onVoteSelected: _selectVote,
                  ),
              const SizedBox(height: 20),
              if (_me?.isSpectator == false)
                Align(
                  widthFactor: 1,
                  child: RevealResetButton(
                    cardsRevealed: cardsRevealed,
                    canReveal: canReveal,
                    canReset: canReset,
                    onReveal: _revealCards,
                    onReset: _resetVoting,
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      ],
    ),)
    ,
    );
  }

  void _showShareDialog() {
    final roomUrl = '${html.window.location.origin}/room/${widget.roomId}';
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Share Room'),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
            content: ShareRoomDialogContent(
              // Usa il widget per il contenuto
              roomUrl: roomUrl,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _setupPresenceIfNeeded() {
    if (_myParticipantId.isNotEmpty && !_presenceSetupDone) {
      _firebaseService.setupPresence(widget.roomId, _myParticipantId);
      _presenceSetupDone = true;
    }
  }

  Future<void> _saveProfile() async {
    {
      var userName = (await _prefsService.getUsername() ?? "Unknown").trim();
      bool isSpectator = await _prefsService.isSpectator() ?? false;
      _firebaseService.updateParticipant(
          widget.roomId, _myParticipantId, userName, isSpectator);
    }
  }

  Future<void> _showKickConfirmationDialog(String participantIdToKick,
      String participantName) async {
    if (participantIdToKick == _myParticipantId) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        // Usa un context diverso per il dialog
        return AlertDialog(
          title: const Text('Confirm Kick'),
          content: Text(
              'Are you sure you want to remove "$participantName" from the room?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Kick'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _kickParticipant(participantIdToKick, participantName);
    }
  }

  Future<void> _kickParticipant(String participantIdToKick,
      String participantName) async {
    final messenger = ScaffoldMessenger.of(context);
    print(
        'Kicking participant $participantIdToKick from room ${widget.roomId}');
    try {
      await _firebaseService.removeParticipant(
          widget.roomId, participantIdToKick);
      messenger.showSnackBar(SnackBar(
          content: Text('"$participantName" has been removed.'),
          backgroundColor: Colors.green));
    } catch (e) {
      print("Error kicking participant $participantIdToKick: $e");
      messenger.showSnackBar(SnackBar(
          content: Text('Failed to remove "$participantName": $e'),
          backgroundColor: Colors.red));
    }
  }
}
