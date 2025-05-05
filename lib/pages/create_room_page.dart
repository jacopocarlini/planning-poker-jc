import 'package:flutter/material.dart';
import 'package:poker_planning/components/user_profile_chip.dart';
import 'package:poker_planning/services/firebase_service.dart'; // Assicurati che il percorso sia corretto
import 'package:poker_planning/services/user_preferences_service.dart';
import 'package:provider/provider.dart';

// --- Definisci i set di carte disponibili ---
const Map<String, List<String>> availableCardSets = {
  'Default': ['0', '1', '2', '3', '5', '8', '13', '?', '☕'],
  'Fibonacci': ['0', '1', '2', '3', '5', '8', '13', '20', '40', '100', '?', '☕'],
  'Modified Fibonacci': ['0', '0.5', '1', '2', '3', '5', '8', '13', '20', '?', '☕'],
  'T-Shirt Sizes': ['XS', 'S', 'M', 'L', 'XL', 'XXL', '?', '☕'],
  // Aggiungi altri set se necessario
};

// --- Create Room Page ---
class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({Key? key}) : super(key: key);

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Stato per memorizzare il nome del set di carte selezionato
  String _selectedCardSetName = availableCardSets.keys.first; // Default al primo set
  final _prefsService = UserPreferencesService(); // Istanza del servizio prefs

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning Poker ♠️'),
        actions: const [
          UserProfileChip(),
          SizedBox(width: 20,)
        ],
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
                // TextFormField(
                //   controller: _nameController,
                //   decoration: const InputDecoration(
                //     labelText: 'Enter Your Name',
                //   ),
                //   validator: (value) {
                //     if (value == null || value.isEmpty) {
                //       return 'Please enter a valid name'; // Messaggio corretto
                //     }
                //     return null;
                //   },
                //   onFieldSubmitted: (_) {
                //     if (!_isLoading) {
                //       _createRoom();
                //     }
                //   },
                // ),
                const SizedBox(height: 24), // Spazio prima del dropdown

                // --- Dropdown per la selezione del set di carte ---
                DropdownButtonFormField<String>(
                  value: _selectedCardSetName,
                  decoration: const InputDecoration(
                    labelText: 'Card Set',
                    // border: OutlineInputBorder(), // Usa il default del tema
                  ),
                  items: availableCardSets.keys.map((String setName) {
                    return DropdownMenuItem<String>(
                      value: setName,
                      child: Text(setName),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCardSetName = newValue;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a card set';
                    }
                    return null;
                  },
                ),
                // --- Fine Dropdown ---

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
    // Valida anche il dropdown ora
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final firebaseService = Provider.of<RealtimeFirebaseService>(context, listen: false);
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      // Ottieni la lista di carte effettiva basata sul nome selezionato
      final List<String>? selectedCards = availableCardSets[_selectedCardSetName];

      // Assicurati che selectedCards non sia null (dovrebbe essere garantito dal dropdown)
      if (selectedCards == null) {
        setState(() { _isLoading = false; });
        messenger.showSnackBar(
          const SnackBar(content: Text('Invalid card set selected.'), backgroundColor: Colors.red),
        );
        return;
      }


      try {
        String username = (await _prefsService.getUsername())!;
        // Passa il set di carte selezionato al service
        final room = await firebaseService.createRoom(
          creatorName: username,
          cardValues: selectedCards, // Passa il set di carte
        );
        navigator.pushReplacementNamed(
          '/room/${room.id}',
          arguments: {
            'roomId': room.id,
            'participantId': room.creatorId,
            'userName': username,
            // Non c'è bisogno di passare di nuovo le carte qui,
            // la RoomPage le leggerà da Firebase usando l'ID della stanza.
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
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
