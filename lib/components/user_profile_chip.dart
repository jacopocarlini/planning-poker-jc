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
  bool? _isSpectator;
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
      final spectator = await _prefsService.isSpectator();
      if (mounted) {
        setState(() {
          _username = name;
          _isSpectator = spectator;

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
              backgroundColor: Theme
                  .of(context)
                  .colorScheme
                  .secondaryContainer,
              child: Text(
                _getInitials(_username),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme
                      .of(context)
                      .colorScheme
                      .onSecondaryContainer,
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

  Future<void> _changeProfile(BuildContext context) async { // 'context' qui è quello di UserProfileChip
    // Pre-carica il valore corrente di _isSpectator se non è già fatto o se vuoi essere sicuro
    // _isSpectator dovrebbe già avere il valore corretto da _loadUsername
    _nameController.text = await _prefsService.getUsername() ?? "Unknown";

    // Non è necessario avere una variabile di stato separata _switch
    // bool currentSwitchStateInDialog = _isSpectator ?? false; // Puoi usarla se preferisci non modificare _isSpectator direttamente fino al salvataggio

    showDialog(
      context: context, // context originale del UserProfileChip
      builder: (dialogContext) { // dialogContext è il context specifico del dialogo
        return StatefulBuilder( // <--- AGGIUNGI QUESTO
          builder: (BuildContext context, StateSetter setStateDialog) { // setStateDialog è per il dialogo
            return AlertDialog(
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
                        // Passa dialogContext per chiudere il dialogo corretto
                        await _handleSave(dialogContext);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        children: [
                          Switch(
                            value: _isSpectator ?? false, // Legge direttamente dallo stato del widget padre
                            onChanged: (value) {
                              setStateDialog(() { // <--- USA setStateDialog QUI
                                // Aggiorna la variabile di stato del widget padre
                                // Questo farà ri-renderizzare solo il contenuto del StatefulBuilder (quindi il dialogo)
                                _isSpectator = value;
                              });
                            },
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Text("Enter as Spectator"),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    // Passa dialogContext per chiudere il dialogo corretto
                    await _handleSave(dialogContext);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

// Il metodo _handleSave rimane quasi invariato, assicurati solo di passare il context corretto per Navigator.pop
  Future<void> _handleSave(BuildContext dialogContext) async { // Riceve il dialogContext
    if (_formKey.currentState!.validate()) {
      await _prefsService.saveUsername(_nameController.text.trim());
      await _prefsService.saveIsSpectator(_isSpectator ?? false); // _isSpectator è già aggiornato
      if (widget.onTap != null) {
        widget.onTap!();
      }
      await _loadUsername(); // Ricarica i dati e aggiorna l'UI del UserProfileChip
      if (Navigator.canPop(dialogContext)) { // Controlla se il dialogo può essere chiuso
        Navigator.pop(dialogContext); // Usa dialogContext per chiudere il dialogo
      }
    }
  }
}
