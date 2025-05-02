import 'dart:async'; // Needed for StreamSubscription
import 'dart:html' as html; // Needed for window.history, window.location

import 'package:flutter/material.dart';
import 'package:poker_planning/models/participant.dart';
import 'package:poker_planning/models/room.dart';
import 'package:poker_planning/services/firebase_service.dart';
import 'package:provider/provider.dart';

// --- Planning Room Widget ---
class PlanningRoom extends StatefulWidget {
  final String roomId;

  // These might be provided via arguments after create/join, or null if joining via URL
  final String? currentParticipantId;
  final String? currentUserName;

  const PlanningRoom({
    Key? key,
    required this.roomId,
    this.currentParticipantId, // Can be null initially if joining via URL
    this.currentUserName, // Can be null initially if joining via URL
  }) : super(key: key);

  @override
  State<PlanningRoom> createState() => _PlanningRoomState();
}

class _PlanningRoomState extends State<PlanningRoom> {
  late RealtimeFirebaseService _firebaseService;
  StreamSubscription<Room>? _roomSubscription;
  Room? _currentRoom;
  String? _myParticipantId; // Resolved participant ID for the current user
  String? _myUserName; // Resolved user name for the current user
  String? _selectedVote; // Current user's selected card (local state)
  bool _isLoading = true;
  bool _isJoining = false; // Flag for URL join process
  bool _presenceSetupDone = false; // Flag to ensure presence is set only once

  @override
  void initState() {
    super.initState();
    _firebaseService =
        Provider.of<RealtimeFirebaseService>(context, listen: false);
    _myParticipantId =
        widget.currentParticipantId; // Initial values from widget args
    _myUserName = widget.currentUserName;

    print(
        "PlanningRoom initState: roomId=${widget.roomId}, participantId=$_myParticipantId, userName=$_myUserName");

    if (_myParticipantId == null || _myUserName == null) {
      // Likely joined via URL or page refresh, need to prompt for name and join
      _isJoining = true;
      // Use addPostFrameCallback to show dialog after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptForNameAndJoin();
      });
    } else {
      // Already have participant info (navigated from Create/Join)
      _subscribeToRoomUpdates();
      _setupPresenceIfNeeded(); // Try setting up presence immediately
      _updatePageUrlIfNeeded(); // Update URL to be shareable
    }
  }

  Future<void> _promptForNameAndJoin() async {
    final name = await _showNameEntryDialog(widget.roomId);
    if (name != null && name.isNotEmpty && mounted) {
      setState(() {
        _isLoading = true; // Show loading indicator while joining
      });
      final messenger = ScaffoldMessenger.of(context); // Grab before async gap

      try {
        final room = await _firebaseService.joinRoom(
            roomId: widget.roomId, participantName: name);
        if (room == null) {
          throw Exception("Room not found or could not be joined.");
        }
        // Find the newly added participant's ID
        // This assumes names are unique for simplicity, real app might need better ID handling
        final newParticipant = room.participants.firstWhere(
            (p) => p.name == name, // Basic matching
            orElse: () => throw Exception(
                "Could not find joined participant in room data."));

        if (mounted) {
          setState(() {
            _myParticipantId = newParticipant.id;
            _myUserName = newParticipant.name;
            _isLoading = false; // Stop loading indicator
            _isJoining = false; // Done with joining process
            _currentRoom = room; // Set initial room state
          });
          _subscribeToRoomUpdates(); // Start listening for updates
          _setupPresenceIfNeeded();
          _updatePageUrlIfNeeded(); // Update URL now that we've joined
        }
      } catch (e) {
        print("Error joining room via URL: $e");
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isJoining = false;
          });
          messenger.showSnackBar(SnackBar(
              content: Text('Error joining room: $e. Please try again.'),
              backgroundColor: Colors.red));
          // Optionally navigate back or show a retry option
          Navigator.of(context).pop(); // Go back if join fails
        }
      }
    } else if (mounted) {
      // Dialog dismissed or name was empty
      Navigator.of(context).pop(); // Go back if user cancels name entry
    }
  }

  void _subscribeToRoomUpdates() {
    if (_roomSubscription != null) return; // Already subscribed

    print("Subscribing to room ${widget.roomId}");
    setState(() {
      _isLoading = true;
    }); // Show loading when subscribing initially

    _roomSubscription =
        _firebaseService.getRoomStream(widget.roomId).listen((room) {
      if (!mounted) return;
      print(
          "Received room update: Participants=${room.participants.length}, Revealed=${room.areCardsRevealed}");
      setState(() {
        _currentRoom = room;
        // Update local selected vote based on received state if cards are hidden
        if (!room.areCardsRevealed && _myParticipantId != null) {
          final myVote = room.participants
              .firstWhere((p) => p.id == _myParticipantId,
                  orElse: () => Participant(id: '', name: ''))
              .vote;
          _selectedVote =
              myVote; // Sync local selection with remote state if needed
        }
        // If cards are revealed, clear local selection unless we want to show our revealed vote selected
        // else { _selectedVote = null; } // Optional: clear selection when revealed

        _isLoading =
            false; // Hide loading indicator after first successful update
      });
    }, onError: (error) {
      print("Error in room stream: $error");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error receiving room updates: $error'),
          backgroundColor: Colors.red));
      // Consider navigating back or showing an error state
    }, onDone: () {
      print("Room stream closed for ${widget.roomId}");
      if (!mounted) return;
      // Handle stream closure if necessary
    });
  }

  // Update browser URL using dart:html history API
  void _updatePageUrlIfNeeded() {
    final currentPath = html.window.location.pathname ?? '';
    final targetPath = '/room/${widget.roomId}';
    if (currentPath != targetPath) {
      print("Updating URL from $currentPath to $targetPath");
      html.window.history
          .pushState(null, 'Poker Planning Room ${widget.roomId}', targetPath);
    }
  }

  // Helper method to setup presence only once we have the ID
  void _setupPresenceIfNeeded() {
    if (_myParticipantId != null &&
        _myParticipantId!.isNotEmpty &&
        !_presenceSetupDone) {
      print(
          "Setting up presence for participant: $_myParticipantId in room ${widget.roomId}");
      _firebaseService.setupPresence(widget.roomId, _myParticipantId!);
      _presenceSetupDone = true; // Mark as done
    } else if (_presenceSetupDone) {
      print("Presence already set up for $_myParticipantId.");
    } else {
      print("Cannot set up presence yet, participant ID is missing.");
    }
  }

  @override
  void dispose() {
    print(
        "Disposing PlanningRoom for ${widget.roomId}. Participant: $_myParticipantId");
    // Cancel the stream subscription FIRST
    _roomSubscription?.cancel();

    // Explicitly remove the participant on clean dispose (e.g., navigating away within the app)
    // The onDisconnect handler acts as a backup for unclean exits (tab close, browser crash)
    if (_myParticipantId != null && _myParticipantId!.isNotEmpty) {
      print(
          "Attempting to explicitly remove participant $_myParticipantId on dispose.");
      // No need for await here as dispose should be synchronous if possible,
      // Firebase SDK handles offline queueing. Let onDisconnect be the guarantee.
      _firebaseService.removeParticipant(widget.roomId, _myParticipantId!);
    } else {
      print("No participant ID to remove on dispose.");
    }

    super.dispose();
  }

  // --- Voting Actions ---
  Future<void> _selectVote(String value) async {
    if (_myParticipantId == null ||
        _currentRoom == null ||
        _currentRoom!.areCardsRevealed) {
      return; // Cannot vote if not joined, room not loaded, or cards revealed
    }
    final messenger = ScaffoldMessenger.of(context);

    // Optimistic UI update
    setState(() {
      _selectedVote = value;
    });

    try {
      await _firebaseService.submitVote(
        roomId: widget.roomId,
        participantId: _myParticipantId!,
        vote: value,
      );
      // Optional: Show confirmation
      // messenger.showSnackBar(SnackBar(content: Text('Vote submitted: $value'), duration: Duration(seconds: 1)));
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        _selectedVote = _currentRoom?.participants
            .firstWhere((p) => p.id == _myParticipantId)
            .vote;
      });
      messenger.showSnackBar(SnackBar(
          content: Text('Failed to submit vote: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _revealCards() async {
    if (_currentRoom == null || _currentRoom!.areCardsRevealed) return;
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
    if (_currentRoom == null || !_currentRoom!.areCardsRevealed) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Clear local selection immediately
      setState(() {
        _selectedVote = null;
      });
      await _firebaseService.resetVoting(roomId: widget.roomId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Failed to reset voting: $e'),
          backgroundColor: Colors.red));
    }
  }

  // --- UI Building Methods ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentRoom == null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(_isJoining ? 'Joining Room...' : 'Loading Room...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // We have room data
    final room = _currentRoom!;
    final participants = room.participants;
    final cardValues = room.cardValues;
    final cardsRevealed = room.areCardsRevealed;

    return Scaffold(
      appBar: AppBar(
        title: Text('Room: ${widget.roomId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Room Link',
            onPressed: _showShareDialog,
          ),
          // IconButton( // Example: Settings button
          //   icon: const Icon(Icons.settings),
          //   tooltip: 'Room Settings',
          //   onPressed: _showSettingsDialog,
          // ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
            child: ConstrainedBox(
          // Limit max width for larger screens
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            // Push cards to bottom
            children: [
              _buildParticipantsGrid(participants, cardsRevealed),
              const Spacer(), // Use Spacer to push elements apart
              _buildRevealButton(cardsRevealed),
              const SizedBox(height: 30),
              _buildVotingCards(cardValues, cardsRevealed),
              const SizedBox(height: 20), // Padding at the bottom
            ],
          ),
        )),
      ),
    );
  }

  Widget _buildParticipantsGrid(
      List<Participant> participants, bool cardsRevealed) {
    if (participants.isEmpty) {
      return const Center(child: Text("No participants yet. Share the link!"));
    }
    return Column(
      children: [
        Text(
          'Team Members (${participants.length})',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          // Adjust cross axis count based on available width
          int crossAxisCount = (constraints.maxWidth / 150)
              .floor()
              .clamp(2, 6); // Card width ~150
          return GridView.builder(
            shrinkWrap: true,
            // Important inside a Column
            physics: const NeverScrollableScrollPhysics(),
            // Disable scrolling within the grid
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.7, // Adjust for card + name height
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: participants.length,
            itemBuilder: (context, index) {
              final participant = participants[index];
              return _buildParticipantCard(participant, cardsRevealed);
            },
          );
        }),
      ],
    );
  }

  Widget _buildParticipantCard(Participant participant, bool cardsRevealed) {
    final vote = participant.vote;
    final hasVoted = vote != null;
    final isMe = participant.id == _myParticipantId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 80,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              border: Border.all(
                  color: isMe ? Colors.blue.shade700 : Colors.blue.shade300,
                  width: isMe ? 2 : 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Show vote value if revealed
                if (cardsRevealed && hasVoted)
                  Text(
                    vote ?? '',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800),
                  ),
                // Show placeholder/question mark if revealed but not voted
                if (cardsRevealed && !hasVoted)
                  Icon(Icons.question_mark,
                      size: 40, color: Colors.grey.shade500),

                // Show checkmark if not revealed but user has voted
                if (!cardsRevealed && hasVoted)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green.shade600)),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 30,
                    ),
                  ),
                // Show empty card back if not revealed and not voted
                if (!cardsRevealed && !hasVoted)
                  Icon(Icons.crop_square,
                      size: 40, color: Colors.blue.shade200),
                // Placeholder card back
              ],
            )),
        const SizedBox(height: 8),
        // Simple Avatar Placeholder (Replace with real avatars if available)
        // CircleAvatar(
        //   radius: 15,
        //   backgroundColor: Colors.grey.shade300,
        //   child: Icon(Icons.person, size: 20, color: Colors.grey.shade700),
        // ),
        // const SizedBox(height: 4),
        Text(
          participant.name + (isMe ? ' (You)' : ''),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildRevealButton(bool cardsRevealed) {
    // Only the creator should be able to reveal/reset? (Check isCreator flag if needed)
    // final bool canControl = _currentRoom?.participants.firstWhereOrNull((p) => p.id == _myParticipantId)?.isCreator ?? false;
    // if (!canControl) return const SizedBox.shrink(); // Hide button if not creator

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        backgroundColor: cardsRevealed ? Colors.orangeAccent : Colors.green,
      ),
      icon: Icon(cardsRevealed ? Icons.refresh : Icons.visibility),
      label: Text(
        cardsRevealed ? 'Reset Voting' : 'Reveal Cards',
        style: const TextStyle(fontSize: 18),
      ),
      onPressed: cardsRevealed ? _resetVoting : _revealCards,
    );
  }

  Widget _buildVotingCards(List<String> cardValues, bool cardsRevealed) {
    if (cardsRevealed) {
      // Optionally show aggregated results or nothing when revealed
      return const SizedBox(
          height: 120,
          child: Center(
              child: Text(
            "Cards Revealed!",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          )));
    }

    // Prevent voting if cards are revealed (double check)
    final canVote = !cardsRevealed;

    return SizedBox(
      // Use SizedBox for fixed height
      height: 120, // Height for card + padding
      child: Center(
        // Center the ListView horizontally
        child: ListView.builder(
          shrinkWrap: true, // Allow centering
          scrollDirection: Axis.horizontal,
          itemCount: cardValues.length,
          itemBuilder: (context, index) {
            final value = cardValues[index];
            final isSelected = _selectedVote == value;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: GestureDetector(
                onTap: canVote ? () => _selectVote(value) : null,
                // Disable tap if cannot vote
                child: Opacity(
                  // Dim cards if voting disabled
                  opacity: canVote ? 1.0 : 0.5,
                  child: Container(
                    width: 70,
                    height: 110,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.shade700 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Colors.blue.shade900
                            : Colors.blue.shade300,
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.5),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected ? Colors.white : Colors.blue.shade700,
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

  // --- Dialogs ---

  // Dialog to get user's name when joining via URL
  Future<String?> _showNameEntryDialog(String roomId) async {
    final nameController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // User must enter name or explicitly cancel
      builder: (context) => AlertDialog(
        title: const Text('Join Planning Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are joining Room ID: $roomId'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter your display name',
              ),
              onSubmitted: (value) {
                // Allow submitting with Enter key
                if (value.isNotEmpty) {
                  Navigator.of(context).pop(value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null), // Cancel
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              } // Otherwise, do nothing (let user fix input)
            },
            child: const Text('Join'),
          ),
        ],
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
            const Text('Share this link or Room ID with your team:'),
            const SizedBox(height: 16),
            const Text('Room Link:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      roomUrl,
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy Link',
                    onPressed: () {
                      html.window.navigator.clipboard?.writeText(roomUrl);
                      Navigator.pop(context); // Close dialog after copy
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Link copied to clipboard'),
                            duration: Duration(seconds: 2)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Room ID:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      widget.roomId,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy Room ID',
                    onPressed: () {
                      html.window.navigator.clipboard?.writeText(widget.roomId);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Room ID copied to clipboard'),
                            duration: Duration(seconds: 2)),
                      );
                    },
                  ),
                ],
              ),
            ),
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

  // Stub for Settings Dialog (Implement content as needed)
  void _showSettingsDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Room Settings (Not Implemented)'),
              content: const Text(
                  'Settings like card deck selection would go here.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ));
  }

  // Stub for Card Deck Dialog (Implement content as needed)
  void _showCardDeckDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Select Card Deck (Not Implemented)'),
              content:
                  const Text('List available decks (Fibonacci, T-Shirt, etc.)'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ));
  }
}
