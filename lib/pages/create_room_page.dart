import 'package:flutter/material.dart';
import 'package:poker_planning/components/user_profile_chip.dart';
import 'package:poker_planning/services/firebase_service.dart';
import 'package:poker_planning/services/user_preferences_service.dart';
import 'package:provider/provider.dart';

// --- Definisci i set di carte disponibili ---
const Map<String, List<String>> availableCardSets = {
  'Default': ['0', '1', '2', '3', '5', '8', '13', '?', '☕'],
  'Fibonacci': ['0', '1', '2', '3', '5', '8', '13', '21', '34', '?', '☕'],
  'Modified Fibonacci': ['0', '0.5', '1', '2', '3', '5', '8', '13', '20', '40', '?', '☕'],
  'T-Shirt Sizes': ['XS', 'S', 'M', 'L', 'XL', 'XXL', '?', '☕'],
  '1 to 5': ['1', '2', '3', '4', '5'],
  '1 to 10': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'],
};

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({Key? key}) : super(key: key);

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customValueController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSpectator = false;
  bool _isPersistent = false;

  // Gestione Set Custom
  static const String _customOption = 'Custom...';
  String _selectedCardSetName = availableCardSets.keys.first;
  final List<String> _customCardsList = [];

  final _prefsService = UserPreferencesService();

  @override
  void initState() {
    super.initState();
    _prefsService.isSpectator().then((value) {
      setState(() {
        _isSpectator = value ?? false;
      });
    });
  }

  // Aggiunge un valore alla lista custom
  void _addCustomCard() {
    final value = _customValueController.text.trim();
    if (value.isNotEmpty) {
      setState(() {
        _customCardsList.add(value);
        _customValueController.clear();
      });
    }
  }

  // Rimuove un valore dalla lista custom
  void _removeCustomCard(int index) {
    setState(() {
      _customCardsList.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dropdownOptions = [...availableCardSets.keys, _customOption];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning Poker ♠️'),
        actions: const [
          UserProfileChip(),
          SizedBox(width: 20),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
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

                  // Nome della Stanza
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Room Name',
                      prefixIcon: Icon(Icons.meeting_room),
                      border: OutlineInputBorder(), // Aggiunto bordo per coerenza visiva
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter a room name' : null,
                  ),

                  const SizedBox(height: 24),

                  // Selezione Set di Carte
                  DropdownButtonFormField<String>(
                    value: _selectedCardSetName,
                    decoration: const InputDecoration(
                      labelText: 'Card Set',
                      prefixIcon: Icon(Icons.style),
                      border: OutlineInputBorder(), // Aggiunto bordo per coerenza visiva
                    ),
                    items: dropdownOptions.map((String setName) {
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
                  ),

                  // --- NUOVA SEZIONE CUSTOM ---
                  if (_selectedCardSetName == _customOption) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Custom Card Values',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Type a value and press Enter or the Add button.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _customValueController,
                            decoration: InputDecoration(
                              labelText: 'Add value',
                              border: const OutlineInputBorder(),
                              // Spostato il bottone dentro l'input field per una UX migliore
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                                onPressed: _addCustomCard,
                                tooltip: 'Add to set',
                              ),
                            ),
                            onSubmitted: (_) => _addCustomCard(),
                          ),
                          const SizedBox(height: 16),

                          // Gestione chiara dell'Empty State
                          if (_customCardsList.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No value added yet.',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: _customCardsList.asMap().entries.map((entry) {
                                return InputChip(
                                  label: Text(entry.value),
                                  deleteIcon: const Icon(Icons.cancel, size: 18),
                                  onDeleted: () => _removeCustomCard(entry.key),
                                  tooltip: 'Remove card',
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                  // --- FINE SEZIONE CUSTOM ---

                  const SizedBox(height: 32),

                  // Opzioni Room
                  SwitchListTile(
                    title: const Text("Enter as Spectator"),
                    subtitle: const Text("Join without voting"),
                    value: _isSpectator,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onChanged: (value) {
                      setState(() => _isSpectator = value);
                      _prefsService.saveIsSpectator(value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text("Persistent Room"),
                    subtitle: const Text("Save this room for future sessions"),
                    value: _isPersistent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onChanged: (value) {
                      setState(() => _isPersistent = value);
                    },
                  ),

                  const SizedBox(height: 40),

                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _createRoom,
                    child: const Text('Create Room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createRoom() async {
    if (_formKey.currentState!.validate()) {
      // Determinazione dei valori finali delle carte
      List<String> selectedCards;
      if (_selectedCardSetName == _customOption) {
        selectedCards = List.from(_customCardsList);
      } else {
        selectedCards = availableCardSets[_selectedCardSetName]!;
      }

      // Validazione specifica per il set custom
      if (selectedCards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one card value for your custom set.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      final firebaseService = Provider.of<RealtimeFirebaseService>(context, listen: false);
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      try {
        String? username = await _prefsService.getUsername();
        if (username == null || username.isEmpty) username = "User_${DateTime.now().millisecond}";

        await _prefsService.saveIsSpectator(_isSpectator);

        final room = await firebaseService.createRoom(
          creatorName: username,
          roomName: _nameController.text,
          isSpectator: _isSpectator,
          isPersistent: _isPersistent,
          cardValues: selectedCards,
        );

        navigator.pushNamed(
          '/room/${room.id}',
          arguments: {
            'roomId': room.id,
            'participantId': room.creatorId,
            'userName': username,
            'isSpectator': _isSpectator,
          },
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to create room: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customValueController.dispose();
    super.dispose();
  }
}