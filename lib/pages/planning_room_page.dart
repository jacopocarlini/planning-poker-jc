import 'dart:async'; // Needed for StreamSubscription
import 'dart:html' as html; // Needed for window.history, window.location
import 'dart:math'; // Needed for min/max

import 'package:collection/collection.dart'; // Import for firstWhereOrNull
import 'package:flutter/material.dart';
import 'package:poker_planning/components/participant_card.dart';
import 'package:poker_planning/components/user_profile_chip.dart';
import 'package:poker_planning/config/theme.dart';
import 'package:poker_planning/models/participant.dart';
import 'package:poker_planning/models/room.dart';
import 'package:poker_planning/services/firebase_service.dart';
import 'package:poker_planning/services/user_preferences_service.dart';
import 'package:provider/provider.dart';

// --- Planning Room Widget ---
class PlanningRoom extends StatefulWidget {
  final String roomId;
  final String currentParticipantId;
  final String currentUserName;

  const PlanningRoom({
    Key? key,
    required this.roomId,
    required this.currentParticipantId,
    required this.currentUserName,
  }) : super(key: key);

  @override
  State<PlanningRoom> createState() => _PlanningRoomState();
}

class _PlanningRoomState extends State<PlanningRoom> {
  late RealtimeFirebaseService _firebaseService;
  StreamSubscription<Room>? _roomSubscription;
  Room? _currentRoom;
  late String _myParticipantId;
  late String _myUserName;
  String? _selectedVote;
  bool _isLoading = true;
  bool _presenceSetupDone = false;
  final TextEditingController _nameController = TextEditingController();
  final _prefsService = UserPreferencesService();

  @override
  void initState() {
    super.initState();
    _firebaseService =
        Provider.of<RealtimeFirebaseService>(context, listen: false);
    _myParticipantId = widget.currentParticipantId;
    _myUserName = widget.currentUserName;

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
      // Rendi la callback async
      if (!mounted)
        return; // Controllo standard se il widget è ancora "montato"

      // --- CONTROLLO SE SONO STATO KICKATO ---
      final bool amIStillInRoom =
          room.participants.any((p) => p.id == _myParticipantId);

      if (!amIStillInRoom) {
        // Non sono più nella lista dei partecipanti!
        print(
            "User $_myParticipantId detected removal from room ${widget.roomId}. Navigating back.");

        // Mostra un messaggio (opzionale ma consigliato)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have been removed from the room.'),
            backgroundColor: Colors.orangeAccent,
            // Usa un colore distintivo
            duration: Duration(seconds: 3), // Durata del messaggio
          ),
        );

        // Annulla l'iscrizione allo stream PRIMA di navigare via
        await _roomSubscription?.cancel();
        _roomSubscription = null;

        // Naviga indietro alla schermata precedente
        // Aggiungi un controllo 'mounted' di nuovo per sicurezza dopo l'await potenziale dello snackbar
        if (mounted) {
          Navigator.of(context).pop();
        }

        // IMPORTANTE: Esci dalla callback qui, non fare setState
        return;
      }
      // --- FINE CONTROLLO KICK ---

      // Se sono ancora nella stanza, procedi con l'aggiornamento normale
      setState(() {
        _currentRoom = room;
        // Aggiorna il voto selezionato solo se le carte non sono rivelate
        if (!room.areCardsRevealed) {
          // Cerca il partecipante corrente nella lista aggiornata
          final me = room.participants
              .firstWhereOrNull((p) => p.id == _myParticipantId);
          // Aggiorna il voto locale con quello dal DB (potrebbe essere null)
          _selectedVote = me?.vote;
        } else {
          // Se le carte sono rivelate, potresti voler resettare il voto locale
          // se il flusso è reset -> rivela (anche se _resetVoting lo fa già)
          _selectedVote = room.participants
              .firstWhereOrNull((p) => p.id == _myParticipantId)
              ?.vote;
        }
        _isLoading = false; // Aggiorna lo stato di caricamento
      });
    }, onError: (error) {
      if (!mounted) return;
      print(
          "Error in room stream for ${widget.roomId}: $error"); // Logga l'errore
      setState(() {
        _isLoading = false;
        // Potresti voler resettare _currentRoom a null qui o mostrare un errore persistente
        _currentRoom = null; // Indica che non possiamo più caricare la stanza
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error loading room: $error. You might need to leave.'),
          // Messaggio migliorato
          backgroundColor: Colors.red));

      // Potresti anche decidere di far uscire l'utente in caso di certi errori
      // if (error is SomeSpecificFirebaseErrorIndicatingRoomDeleted) {
      //    Navigator.of(context).pop();
      // }
    }, onDone: () {
      if (!mounted) return;
      print("Room stream for ${widget.roomId} closed.");
      // Lo stream è terminato (potrebbe succedere se la stanza viene eliminata?)
      // Potresti voler far uscire l'utente anche qui.
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        // Naviga solo se questa è la rotta corrente
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Connection to the room closed.'),
            backgroundColor: Colors.grey));
        Navigator.of(context).pop();
      }
    });
  }

  void _updatePageUrlIfNeeded() {
    if (_myParticipantId.isEmpty) {
      return; // Don't update URL until join is confirmed
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
    _firebaseService.removeParticipant(widget.roomId, _myParticipantId);
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _nameController.dispose();

    super.dispose();
  }

  // --- Voting Actions ---
  Future<void> _selectVote(String value) async {
    if (_currentRoom != null && _currentRoom!.areCardsRevealed) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final previousVote =
        _selectedVote; // Store previous vote for potential revert

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
      // Revert optimistic update on error only if the vote hasn't changed again
      if (mounted && _selectedVote == value) {
        setState(() {
          _selectedVote =
              previousVote; // Revert to the vote before the failed attempt
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
      // No need to clear local selection here, stream update will handle it
      // setState(() { _selectedVote = null; }); // Remove this
      await _firebaseService.resetVoting(roomId: widget.roomId);
      // Local selection (_selectedVote) will be updated via the stream listener when the room state changes
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Failed to reset voting: $e'),
          backgroundColor: Colors.red));
    }
  }

  // --- UI Building Methods ---

  @override
  Widget build(BuildContext context) {
    // Use local variables for null safety checks inside the build method
    final Room? room = _currentRoom;
    final bool isLoading = _isLoading || room == null;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If not loading, but room is still null (error state)
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
                  'Could not load room details.',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(), // Go back
                  child: const Text('Go Back'),
                )
              ],
            ),
          ),
        ),
      );
    }

    // We definitely have room data now
    final participants = room.participants;
    final cardValues = room.cardValues;
    final cardsRevealed = room.areCardsRevealed;

    return Scaffold(
      appBar: AppBar(
        title: Text('Planning Poker ♠️'),
        // Show user's name
        actions: [
          UserProfileChip(onTap: _saveProfile),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Room Link',
            onPressed: _showShareDialog,
          ),
          SizedBox(
            width: 20,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildParticipantsGrid(participants, cardsRevealed),
                  ),
                ),
                const SizedBox(height: 20),
                if (cardsRevealed)
                  _buildVoteResultsSummary(room) // Show results when revealed
                else
                  _buildVotingCards(cardValues, cardsRevealed),
                const SizedBox(height: 20),
                _buildRevealButton(cardsRevealed),

                const SizedBox(height: 20),
                // Padding at the bottom
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantsGrid(
      List<Participant> participants, bool cardsRevealed) {
    if (participants.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Text("No participants yet. Share the link!"),
        ),
      );
    }

    // Determine if the current user is the creator ONCE here
    final bool amICreator = _myParticipantId == _currentRoom?.creatorId;

    return Column(
      children: [
        Text(
          'Team Members: ${participants.length}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        Center(
          child: LayoutBuilder(builder: (context, constraints) {
            int crossAxisCount =
                (constraints.maxWidth / 160).floor().clamp(2, 6);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.65,
                // Might need slight adjustment due to Stack/Button
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final participant = participants[index];
                // Use the new ParticipantCard widget
                return ParticipantCard(
                  // Use a ValueKey to help Flutter identify stateful widgets correctly
                  key: ValueKey(participant.id),
                  participant: participant,
                  cardsRevealed: cardsRevealed,
                  isMe: participant.id == _myParticipantId,
                  onKick:
                      _showKickConfirmationDialog, // Pass the function reference
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRevealButton(bool cardsRevealed) {
    // Check if anyone has voted (relevant for enabling reveal)
    final bool someoneVoted =
        _currentRoom?.participants.any((p) => p.vote != null) ?? false;
    // Reveal button enabled only if cards are hidden AND someone has voted
    final bool canReveal = !cardsRevealed && someoneVoted;
    // Reset button enabled only if cards are revealed
    final bool canReset = cardsRevealed;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          backgroundColor: cardsRevealed ? accentYellow : primaryBlue,
          // Use different colors
          foregroundColor: Colors.white,
          // Text color
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          disabledBackgroundColor:
              Colors.grey.shade300 // Grey out when disabled
          ),
      // Disable button conditionally
      onPressed: cardsRevealed
          ? (canReset ? _resetVoting : null)
          : (canReveal ? _revealCards : null),
      icon: Icon(cardsRevealed ? Icons.refresh : Icons.visibility),
      label: Text(cardsRevealed ? 'Reset Voting' : 'Reveal Cards'),
    );
  }

  // --- NEW WIDGET for displaying results ---
  Widget _buildVoteResultsSummary(Room room) {
    final participantsWhoVoted = room.participants
        .where((p) => p.vote != null && p.vote!.isNotEmpty)
        .toList();

    if (participantsWhoVoted.isEmpty) {
      return const SizedBox(
        height: 150, // Match approx height of voting cards area
        child: Center(
          child: Text(
            "No votes were cast.",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    // --- Calculations ---
    final Map<String, int> voteCounts = {};
    final List<double> numericVotes = [];
    for (var p in participantsWhoVoted) {
      final vote = p.vote!;
      voteCounts[vote] = (voteCounts[vote] ?? 0) + 1;
      final numericValue = double.tryParse(vote);
      if (numericValue != null) {
        numericVotes.add(numericValue);
      }
    }

    // Average
    final double? average = numericVotes.isNotEmpty
        ? numericVotes.reduce((a, b) => a + b) / numericVotes.length
        : null;

    // Consensus
    final double? consensus = _calculateStandardDeviation(numericVotes);

    // Sort vote counts for display (e.g., numeric first, then alphabetically)
    final sortedVotes = voteCounts.entries.toList()
      ..sort((a, b) {
        final numA = double.tryParse(a.key);
        final numB = double.tryParse(b.key);
        if (numA != null && numB != null)
          return numA.compareTo(numB); // Sort numbers
        if (numA != null) return -1; // Numbers before strings
        if (numB != null) return 1; // Strings after numbers
        return a.key.compareTo(b.key); // Sort strings alphabetically
      });

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Voting Results',
                style: Theme.of(context).textTheme.headlineSmall),
            const Divider(
              height: 20,
              thickness: 1,
              color: lightGrey,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResultStat("Average",
                    average != null ? average.toStringAsFixed(1) : "N/A"),
                _buildResultStat(
                    "Consensus",
                    (consensus ?? 0) <= 2.0
                        ? "(${consensus ?? 'N/A'}) Yes 👍"
                        : "(${consensus ?? 'N/A'}) No 👎"),
              ],
            ),
            const Divider(height: 20, thickness: 1, color: lightGrey,),
            Text('Vote Summary:',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              // Use Wrap for flexibility with many vote options
              spacing: 16.0,
              // Horizontal space
              runSpacing: 8.0,
              // Vertical space
              alignment: WrapAlignment.center,
              direction: Axis.horizontal,
              children: sortedVotes.map((entry) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(entry.value.toString()),
                    ),
                    Container(
                      width: 8 * 4,
                      height: 12 * 4,
                      decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          border: Border.all(
                            color: Colors.blueGrey.shade200,
                            width: 1.5,
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
                      child: Center(
                        child: Text(entry.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for styling the Average/Consensus stats
  Widget _buildResultStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildVotingCards(List<String> cardValues, bool cardsRevealed) {
    // This function remains largely the same, but check the height/constraints
    // Adjust height or use LayoutBuilder if needed based on results widget height
    return SizedBox(
      height: 150, // Ensure consistent height with results area
      child: Center(
        child: cardsRevealed
            ? const Text("Cards Revealed!",
                style: TextStyle(
                    fontSize: 18,
                    color:
                        Colors.grey)) // Should not happen if logic is correct
            : ListView.builder(
                // Keep ListView if cards are not revealed
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                itemCount: cardValues.length,
                itemBuilder: (context, index) {
                  final value = cardValues[index];
                  final isSelected = _selectedVote == value;
                  final canVote = !cardsRevealed; // Explicitly check here

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: GestureDetector(
                      onTap: canVote ? () => _selectVote(value) : null,
                      child: Opacity(
                        opacity: canVote ? 1.0 : 0.5,
                        child: Container(
                          width: 70,
                          height: 110,
                          // Keep original card size
                          margin: const EdgeInsets.symmetric(vertical: 20),
                          // Center vertically
                          decoration: BoxDecoration(
                            color: isSelected
                                ? lightBlue
                                : Colors.white, // Different selected color
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? primaryBlue
                                  : Colors.blueGrey.shade300,
                              width: isSelected ? 3 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primaryBlue.withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : [
                                    BoxShadow(
                                      // Subtle shadow for unselected cards too
                                      color: Colors.grey.withOpacity(0.2),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    )
                                  ],
                          ),
                          child: Center(
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : primaryBlue,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showShareDialog() {
    final roomUrl = '${html.window.location.origin}/room/${widget.roomId}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this link with your team:'),
            const SizedBox(height: 16),
            _buildShareItem('Room Link:', roomUrl, context),
            // const SizedBox(height: 16),
            // _buildShareItem('Room ID:', widget.roomId, context),
          ],
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

  // Helper for Share Dialog items
  Widget _buildShareItem(
      String label, String value, BuildContext dialogContext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300)),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: TextStyle(color: Colors.blue.shade800),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact, // Make button smaller
                onPressed: () {
                  html.window.navigator.clipboard?.writeText(value);
                  // Use ScaffoldMessenger from the main context, not dialog context
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('$label copied to clipboard'),
                        duration: const Duration(seconds: 2)),
                  );
                  // Optionally close dialog after copy - depends on preference
                  // Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  double? _calculateStandardDeviation(List<double> votes) {
    // 1. Filtra e converti i voti numerici validi
    final numericVotes = votes
        .where((v) => v != null) // Rimuovi i null (voti non numerici)
        .map((v) => v!) // Ora siamo sicuri che non sono null
        .toList();

    // 2. Gestisci casi limite
    if (numericVotes.length < 2) {
      // Non si può calcolare StdDev con meno di 2 valori.
      // Consideriamo 0 o 1 voto come consenso perfetto (StdDev = 0) o indefinito (null).
      // Restituire 0.0 se c'è 1 voto ha senso (nessuna deviazione).
      // Restituire null se 0 voti o se si preferisce non definirla con <2 voti.
      return numericVotes.isEmpty ? null : 0.0;
    }

    // 3. Calcola la media (Mean)
    final double mean =
        numericVotes.reduce((a, b) => a + b) / numericVotes.length;

    // 4. Calcola la somma delle differenze quadrate dalla media
    final num sumOfSquaredDifferences = numericVotes
        .map((vote) => pow(vote - mean, 2)) // (vote - mean)^2
        .reduce((a, b) => a + b); // Somma di tutti i quadrati

    // 5. Calcola la Varianza della Popolazione (dividi per N)
    final double variance = sumOfSquaredDifferences / numericVotes.length;

    // 6. Calcola la Deviazione Standard (radice quadrata della varianza)
    final double standardDeviation = sqrt(variance);

    return standardDeviation;
  }

  // Helper method to setup presence only once we have the ID
  void _setupPresenceIfNeeded() {
    if (_myParticipantId.isNotEmpty && !_presenceSetupDone) {
      _firebaseService.setupPresence(widget.roomId, _myParticipantId);
      _presenceSetupDone = true; // Mark as done
    }
  }

  Future<void> _saveProfile() async {
    {
      var userName = (await _prefsService.getUsername() ?? "Unknown").trim();
      setState(() {
        _myUserName = userName;
      });
      await _firebaseService.updateParticipantName(
        widget.roomId,
        _myParticipantId,
        userName,
      );
    }
  }

  // Add this method inside _PlanningRoomState

  Future<void> _showKickConfirmationDialog(
      String participantIdToKick, String participantName) async {
    // Prevent kicking yourself (should be handled by UI, but double-check)
    if (participantIdToKick == _myParticipantId) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Kick'),
          content: Text(
              'Are you sure you want to remove "$participantName" from the room?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // Return false
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Kick'),
              onPressed: () {
                Navigator.of(context).pop(true); // Return true
              },
            ),
          ],
        );
      },
    );

    // If the user confirmed in the dialog
    if (confirmed == true) {
      await _kickParticipant(participantIdToKick);
    }
  }

  // Actual function to call Firebase service
  Future<void> _kickParticipant(String participantIdToKick) async {
    final messenger = ScaffoldMessenger.of(context);
    print(
        'Kicking participant $participantIdToKick from room ${widget.roomId}');
    try {
      // Use the existing removeParticipant method from your service
      await _firebaseService.removeParticipant(
          widget.roomId, participantIdToKick);
      messenger.showSnackBar(SnackBar(
          content: Text('Participant removed successfully.'),
          backgroundColor: Colors.green));
    } catch (e) {
      print("Error kicking participant $participantIdToKick: $e");
      messenger.showSnackBar(SnackBar(
          content: Text('Failed to remove participant: $e'),
          backgroundColor: Colors.red));
    }
  }
}
