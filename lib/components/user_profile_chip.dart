import 'package:flutter/material.dart';
import 'package:poker_planning/services/user_preferences_service.dart';

class UserProfileChip extends StatefulWidget {
  final VoidCallback? onTap; // Azione da eseguire al tap

  const UserProfileChip({
    Key? key,
    this.onTap, // Rendi opzionale la callback
  }) : super(key: key);

  @override
  State<UserProfileChip> createState() => _UserProfileChipState();
}

class _UserProfileChipState extends State<UserProfileChip> {
  final _prefsService = UserPreferencesService();
  String? _username;
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    setState(() => _isLoading = true);
    try {
      final name = await _prefsService.getUsername();
      if (mounted) {
        setState(() {
          _username = name;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _isLoading = false); // Smetti di caricare anche in caso di errore
      }
    }
  }

  // Funzione per generare iniziali dal nome
  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    List<String> nameParts = name.trim().split(' ');
    if (nameParts.length > 1) {
      // Prendi le iniziali del primo e dell'ultimo nome
      return nameParts.first[0].toUpperCase() + nameParts.last[0].toUpperCase();
    } else if (nameParts.isNotEmpty && nameParts.first.isNotEmpty) {
      // Prendi le prime due lettere se c'è solo una parola
      return nameParts.first.length > 1
          ? nameParts.first.substring(0, 2).toUpperCase()
          : nameParts.first[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Mostra un piccolo indicatore di caricamento o un placeholder
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Costruisci il Chip cliccabile
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: InkWell(
        onTap: () async {
          await _changeProfile(context);
        },
        // Usa la callback passata al widget
        borderRadius: BorderRadius.circular(20),
        // Rende l'effetto ripple rotondo
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Row(children: [
            CircleAvatar(
              // Puoi personalizzare il colore o usare un'immagine se disponibile
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Text(
                _getInitials(_username),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            Text(
              _username ?? 'Guest',
              // Mostra 'Guest' se il nome non è disponibile
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ]
              // Puoi aggiungere altre personalizzazioni al Chip qui
              // padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
        ),
      ),
    );
  }

  Future<void> _changeProfile(context) async {
    _nameController.text = await _prefsService.getUsername() ?? "Unknown";
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit your profile'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Change your name'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Enter Your Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty || value.trim().isEmpty) {
                    return 'Please enter a valid name';
                  }
                  return null;
                },
                onFieldSubmitted: (value) async {
                  await _handleSave(dialogContext);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _handleSave(dialogContext);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave(BuildContext dialogContext) async {
    if (_formKey.currentState!.validate()) {
      await _prefsService.saveUsername(_nameController.text.trim());
      if (widget.onTap != null) {
        widget.onTap!();
      }
      await _loadUsername();
      Navigator.pop(dialogContext);
    }
  }
}
