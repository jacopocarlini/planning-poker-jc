// --- Join Room Page ---
import 'package:flutter/material.dart';
import 'package:poker_planning/services/firebase_service.dart';
import 'package:provider/provider.dart';

class JoinRoomPage extends StatefulWidget {
  final String roomId;

  const JoinRoomPage({Key? key, required this.roomId}) : super(key: key);

  @override
  State<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends State<JoinRoomPage> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Planning Room'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Join to Room',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Enter Your Name',
                        // border: OutlineInputBorder(), // Using theme default
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!_isLoading) {
                          _joinRoom();
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                            onPressed: _joinRoom,
                            child: const Text('Join Room'),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinRoom() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final firebaseService =
          Provider.of<RealtimeFirebaseService>(context, listen: false);
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final name = _nameController.text.trim();

      try {
        final room = await firebaseService.joinRoom(
            roomId: widget.roomId, participantName: name);

        if (room == null) {
          setState(() {
            _isLoading = false;
          });
          messenger.showSnackBar(
            SnackBar(
                content: Text('Room ${widget.roomId} not found.'),
                backgroundColor: Colors.orange),
          );
          return;
        }

        // Find the ID of the participant who just joined
        final participantId = room.participants
            .firstWhere((p) => p.name == name && !p.isCreator,
                // Be careful if names aren't unique!
                orElse: () => room.participants.last // Fallback, less reliable
                )
            .id;

        navigator.pushReplacementNamed(
          '/room/$widget.roomId', // Use path parameter
          arguments: {
            'roomId': widget.roomId,
            'participantId': participantId,
            'userName': name,
            // 'isCreator': false, // Optionally pass this
          },
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        messenger.showSnackBar(
          SnackBar(
              content: Text('Failed to join room: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
