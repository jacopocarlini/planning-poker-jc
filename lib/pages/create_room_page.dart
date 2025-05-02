// --- Create Room Page ---
import 'package:flutter/material.dart';
import 'package:poker_planning/services/firebase_service.dart';
import 'package:provider/provider.dart';

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({Key? key}) : super(key: key);

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning Poker ♠️'),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create a new room!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
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
                  // Aggiungi questa riga:
                  onFieldSubmitted: (_) {
                    // Chiama la stessa funzione usata dal pulsante
                    if (!_isLoading) {
                      // Evita doppie chiamate se già in caricamento
                      _createRoom();
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
                        onPressed: _createRoom,
                        child: const Text('Create Room'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createRoom() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final firebaseService =
          Provider.of<RealtimeFirebaseService>(context, listen: false);
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      try {
        final room =
            await firebaseService.createRoom(creatorName: _nameController.text);
        // Navigate to the room, passing necessary details
        navigator.pushReplacementNamed(
          '/room/${room.id}', // Use path parameter for consistency
          arguments: {
            'roomId': room.id,
            'participantId': room.creatorId,
            'userName': _nameController.text,
          },
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        messenger.showSnackBar(
          SnackBar(
              content: Text('Failed to create room: $e'),
              backgroundColor: Colors.red),
        );
      }
      // No need to set isLoading back to false if navigation succeeds
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
