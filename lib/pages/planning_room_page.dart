import 'dart:async';
import 'dart:html' as html; // Needed for window.history, window.location

import 'package:audioplayers/audioplayers.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:poker_planning/components/HistorySidePanel.dart';
import 'package:poker_planning/components/participants_grid_view.dart';
import 'package:poker_planning/components/share_room_dialog_content.dart';
import 'package:poker_planning/components/user_profile_chip.dart'; // Assicurati che il percorso sia corretto
import 'package:poker_planning/components/vote_results_summary_view.dart';
import 'package:poker_planning/components/voting_cards_row.dart';
import 'package:poker_planning/models/participant.dart';
import 'package:poker_planning/models/room.dart';
import 'package:poker_planning/services/firebase_service.dart';
import 'package:poker_planning/services/user_preferences_service.dart';
import 'package:provider/provider.dart';

import '../models/vote_history_entry.dart';

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
  List<VoteHistoryEntry> _votingHistory = [];
  bool _isPersistent = false;
  int _lastTrillValue = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

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
    // startNudgeListener(widget.currentParticipantId);
  }

  void _subscribeToRoomUpdates() {
    if (_roomSubscription != null) return;

    setState(() {
      _isLoading = true;
    });

    _roomSubscription =
        _firebaseService.getRoomStream(widget.roomId).listen((Room room) async {
      if (!mounted) return;

      final bool amIStillInRoom =
          room.participants.any((p) => p.id == _myParticipantId);

      if (!amIStillInRoom && _currentRoom != null) {
        print(
            "User $_myParticipantId detected removal from room ${widget.roomId}. Navigating back.");
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
        _isPersistent = room.isPersistent;
        _me =
            room.participants.firstWhereOrNull((p) => p.id == _myParticipantId);
        if (!room.areCardsRevealed) {
          _selectedVote = _me?.vote;
        } else {
          _selectedVote = room.participants
              .firstWhereOrNull((p) => p.id == _myParticipantId)
              ?.vote;
        }
        _votingHistory = room.historyVote;
        _isLoading = false;
      });

      var trillValue = (_me?.trill ?? 0);
      if (trillValue != _lastTrillValue && trillValue > 0) {
        showBrowserNotification(
            title: 'Trill! 🔔', body: 'Someone sent you a trill!');
      }
      setState(() {
        _lastTrillValue = trillValue;
      });
    }, onError: (error) {
      if (!mounted) return;
      print("Error in room stream for ${widget.roomId}: $error");
      setState(() {
        _isLoading = false;
        _currentRoom = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error loading room: $error. You might need to leave.'),
          backgroundColor: Colors.red));
    }, onDone: () {
      if (!mounted) return;
      print("Room stream for ${widget.roomId} closed.");
      if (ModalRoute.of(context)?.isCurrent ?? false) {
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
  Future<void> dispose() async {
    super.dispose();
    _audioPlayer.dispose();
    _roomSubscription?.cancel();
    _roomSubscription = null;
    // _nameController.dispose(); // Non più usato
    await _firebaseService.removeParticipant(widget.roomId, _myParticipantId);
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
    setState(() {
      final Map<String, int> voteCounts = {};
      final List<double> numericVotes = [];
      final participantsWhoVoted = _currentRoom?.participants
              .where((p) => p.vote != null && p.vote!.isNotEmpty)
              .toList() ??
          [];
      for (var p in participantsWhoVoted) {
        final vote = p.vote!;
        voteCounts[vote] = (voteCounts[vote] ?? 0) + 1;
        final numericValue = double.tryParse(vote);
        if (numericValue != null) {
          numericVotes.add(numericValue);
        }
      }
      // _votingHistory.add(VoteHistoryEntry(voteCounts: voteCounts));
    });
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

  Future<void> _onNextVote() async {
    if (_currentRoom == null) return;
    if (_currentRoom!.historyVote.isEmpty) {
      return;
    }
    int indexOfNext =
        _currentRoom!.historyVote.indexWhere((elem) => elem.selected == true) +
            1;
    if (indexOfNext > _currentRoom!.historyVote.length - 1) return;

    await _firebaseService.resetVoting(roomId: widget.roomId);
    await _firebaseService.selectedEntry(
        widget.roomId, _currentRoom!.historyVote[indexOfNext]);
  }

  bool _hasTask() {
    if (_currentRoom == null) return false;
    return _currentRoom!.historyVote.isNotEmpty;
  }

  String _currentTask() {
    if (_currentRoom == null) return '';
    if (_currentRoom!.historyVote.isEmpty) {
      return '';
    }
    return (_currentRoom!.historyVote
                .indexWhere((elem) => elem.selected == true) + 1)
        .toString();
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
    final spectators = room.participants.where((p) => p.isSpectator).toList();
    final players = room.participants.where((p) => !p.isSpectator).toList();
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
          UserProfileChip(
            onTap: _saveProfile,
            isPersistent:
                room.creatorId == _myParticipantId ? _isPersistent : null,
            onPersist: (bool value) {
              setState(() {
                _isPersistent = value;
              });
              _firebaseService.setPersistent(
                  roomId: room.id, isPersistent: value);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Invite Teammates'),
            onPressed: _showShareDialog,
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 20,
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 10,
                  child: Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                                '👥 Team Members: ${participants.length}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                          ...players.map((elem) => Text(elem.name)),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: SizedBox(
                                width: 200,
                                child: const Divider(
                                    height: 1,
                                    color:
                                        CupertinoColors.lightBackgroundGray)),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 8, bottom: 12.0),
                            child: Text("👀 Spectators: ${spectators.length}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                          ...spectators.map((elem) => Text(elem.name))
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
                                roomId: room.id,
                                room: room,
                                cardsRevealed: cardsRevealed,
                                myParticipantId: _myParticipantId,
                                onKickParticipant: _showKickConfirmationDialog,
                                onRevealCards: _revealCards,
                                onResetVoting: _resetVoting,
                                canReveal: canReveal,
                                canReset: canReset,
                                onNextVote: _onNextVote,
                                hasTask: _hasTask(),
                                currentTask: _currentTask()
                                // isCreator: _myParticipantId == room.creatorId, // Esempio se necessario
                                ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (room.currentStoryTitle != null)
                          Text(
                            room.currentStoryTitle!,
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        if (cardsRevealed)
                          SizedBox(
                              height: MediaQuery.sizeOf(context).height / 2,
                              child: VoteResultsSummaryView(room: room))
                        else if (_me?.isSpectator == false)
                          VotingCardsRow(
                            cardValues: cardValues,
                            selectedVote: _selectedVote,
                            cardsRevealed: cardsRevealed,
                            onVoteSelected: _selectVote,
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          HistorySidePanel(
            votingHistory: _votingHistory,
            collapsedWidth: 60,
            expandedWidth: 400,
            onUpdateEntryTitle:
                (VoteHistoryEntry entry, String newTitle) async {
              await _firebaseService.updateStoryTitle(room, entry, newTitle);
            },
            onAddNewHistoryEntry: () async {
              var task = await _firebaseService.addHistory(room.id);

              // _showVoteDialog(context, task);
            },
            onDeleteEntry: (VoteHistoryEntry entry) {
              _firebaseService.deleteHistory(room.id, entry);
            },
            onSelectedEntry: (VoteHistoryEntry entry) {
              var other = _votingHistory
                  .firstWhereOrNull((elem) => elem.selected == true)
                  ?.id;
              if (entry.id == other) {
                _firebaseService.resetVoting(roomId: room.id, selected: false);
              } else {
                _firebaseService.selectedEntry(room.id, entry);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showVoteDialog(BuildContext context, VoteHistoryEntry entry) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          content: SizedBox(
            child: Text('Do you want to select this task for voting?'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton.icon(
              label: Text('Vote'),
              onPressed: () {
                setState(() {
                  _firebaseService.selectedEntry(_currentRoom!.id, entry);
                });
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  void _showShareDialog() {
    final roomUrl = '${html.window.location.origin}/room/${widget.roomId}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

  Future<void> _showKickConfirmationDialog(
      String participantIdToKick, String participantName) async {
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

  Future<void> _kickParticipant(
      String participantIdToKick, String participantName) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _firebaseService.removeParticipant(
          widget.roomId, participantIdToKick);
      messenger.showSnackBar(SnackBar(
          content: Text('"$participantName" has been removed.'),
          backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Failed to remove "$participantName": $e'),
          backgroundColor: Colors.red));
    }
  }

// Funzione helper per mostrare notifiche browser
  void showBrowserNotification({
    required String title,
    required String body,
  }) {
    if (html.Notification.supported) {
      // print("Browser notifications are supported."); // DEBUG
      html.Notification.requestPermission().then((permission) {
        if (permission == 'granted') {
          try {
            _audioPlayer.play(AssetSource('audio/beep.mp3'));
            final notification = html.Notification(
              title,
              body: body,
              tag: 'web-nudge-${DateTime.now().millisecondsSinceEpoch}',
              // Tag univoco per evitare sovrapposizioni se invii rapidamente
              icon: '/icons/icon-192.png', // Opzionale: aggiungi un'icona
            );

            notification.onClick.listen((event) {
              // print('Browser notification clicked. Data: $data');
              // html.window.focus(); // Porta la finestra/scheda in primo piano
              // Qui potresti navigare o fare altro in base a `data`
              // Esempio: se data contiene un 'roomId', potresti voler navigare a quella stanza
            });
            notification.onShow.listen((event) {
              // print("Notification successfully SHOWN to the user."); // DEBUG
            });
            notification.onError.listen((event) {
              // Aggiunto gestore errori
              // print("ERROR showing notification: ${notification.title}, Error: $event");
            });
            notification.onClose.listen((event) {
              // print("Notification closed: ${notification.title}");
            });
          } catch (e) {
            print("Exception while creating html.Notification: $e"); // DEBUG
          }
        } else {
          print(
              'Permesso notifiche browser NON concesso (status: $permission).');
        }
      });
    } else {
      print('API Notification del browser non supportata.');
    }
  }
}
