import 'package:flutter/material.dart';
import 'package:poker_planning/services/firebase_service.dart'; // Assicurati che il path sia corretto
import 'package:poker_planning/services/user_preferences_service.dart'; // Assicurati che il path sia corretto
import 'package:provider/provider.dart';

class JoinRoomPage extends StatefulWidget {
  final String roomId;

  const JoinRoomPage({Key? key, required this.roomId}) : super(key: key);

  @override
  State<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends State<JoinRoomPage> {
  final TextEditingController _nameController = TextEditingController();
  // Meglio inizializzare servizi che non dipendono da context qui o tramite DI
  final UserPreferencesService _prefsService = UserPreferencesService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  // Flag per evitare chiamate multiple se l'auto-join è in corso
  bool _isAutoJoining = false;
  bool _isSpectator = false;

  @override
  void initState() {
    super.initState();
    // Usiamo addPostFrameCallback per assicurarci che il contesto sia pronto
    // e per non bloccare la build iniziale.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAutoJoin();
    });
  }

  // Funzione separata per la logica di auto-join
  Future<void> _checkAndAutoJoin() async {
    // Recupera l'username dalle preferenze
    final String? storedUsername = await _prefsService.getUsername();
    final bool? isSpectator = await _prefsService.isSpectator();

    // Controlla se l'username esiste e non è vuoto e se il widget è ancora montato
    if (storedUsername != null && storedUsername.isNotEmpty && mounted) {
      // Imposta il flag per indicare che stiamo tentando l'auto-join
      setState(() {
        _isAutoJoining = true; // Indica che l'auto join è iniziato
        _isLoading = true; // Mostra l'indicatore di caricamento
        // Opzionale: Pre-compila il campo di testo per coerenza UX
        _nameController.text = storedUsername;
        _isSpectator = isSpectator ?? false;
      });

      // Chiama la funzione di join passando l'username recuperato
      await _performJoinRoom(storedUsername);

      // Se siamo ancora qui (es. join fallito), resetta il flag di auto-join
      // Il reset di _isLoading avviene dentro _performJoinRoom
      if (mounted) {
        setState(() {
          _isAutoJoining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se stiamo facendo l'auto-join, mostriamo solo un loader centrale
    // per evitare che l'utente veda/interagisca con il form per un istante.
    if (_isAutoJoining && _isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Joining Room...'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Joining automatically...'),
            ],
          ),
        ),
      );
    }

    // Altrimenti, mostra la UI normale
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Planning Room'),
      ),
      body: Center(
        child: SingleChildScrollView( // Aggiunto per evitare overflow su schermi piccoli
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Join Room', // Semplificato testo
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
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(), // Stile leggermente migliore
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) { // Usa trim() anche qui
                            return 'Please enter a valid name';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) {
                          // Non permettere invio se già in caricamento
                          if (!_isLoading) {
                            _handleManualJoin();
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      Row(children: [
                        Switch(value: _isSpectator, onChanged: (value){
                          setState(() {
                            _isSpectator = value;
                          });
                        }),

                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: const Text("Enter as Spectator"),
                        ),

                      ],),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder( // Bordi arrotondati
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        // Disabilita il pulsante se in caricamento
                        onPressed: _isLoading ? null : _handleManualJoin,
                        child: const Text('Join Room'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Gestisce il tentativo di join manuale (da pulsante/invio)
  Future<void> _handleManualJoin() async {
    // Valida il form prima di procedere
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      // Imposta isLoading PRIMA della chiamata asincrona
      setState(() {
        _isLoading = true;
      });
      await _performJoinRoom(name);
      // isLoading verrà resettato dentro _performJoinRoom o qui in caso di errore non gestito
      // Ma è meglio gestirlo sempre dentro la funzione _performJoinRoom
    }
  }

  // Funzione UNIFICATA per eseguire il join, accetta il nome come parametro
  Future<void> _performJoinRoom(String participantName) async {
    // Se il nome è vuoto (non dovrebbe succedere con la validazione, ma per sicurezza)
    if (participantName.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    // Ottieni i servizi (meglio ottenerli prima degli await se possibile)
    // ATTENZIONE: se usi Provider, assicurati che sia disponibile sopra questo widget nel tree.
    // Se questa pagina viene raggiunta senza un Provider<RealtimeFirebaseService> sopra, darà errore.
    final firebaseService = Provider.of<RealtimeFirebaseService>(context, listen: false);
    final navigator = Navigator.of(context); // Salva navigator prima di await
    final messenger = ScaffoldMessenger.of(context); // Salva messenger prima di await

    try {
      // 1. Salva (o sovrascrivi) l'username nelle preferenze
      await _prefsService.saveUsername(participantName);

      // 2. Prova a fare il join alla stanza Firebase
      final room = await firebaseService.joinRoom(
        roomId: widget.roomId,
        participantName: participantName,
        isSpectator: _isSpectator
      );

      // 3. Controlla il risultato
      if (room == null) {
        // Controlla se il widget è ancora montato prima di mostrare SnackBar/aggiornare state
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        messenger.showSnackBar(
          SnackBar(
              content: Text('Room not found or unable to join.'),
              backgroundColor: Colors.orange),
        );
        return; // Esce dalla funzione
      }

      // 4. Join riuscito: Trova l'ID del partecipante
      // Questa logica per trovare l'ID potrebbe essere fragile se i nomi non sono unici.
      // Sarebbe meglio se `joinRoom` restituisse direttamente l'ID del nuovo partecipante.
      // Assumiamo per ora che funzioni o che `joinRoom` venga migliorato.
      String? participantId;
      try {
        // Cerca per nome E che non sia il creatore (se hai modo di distinguerlo)
        // O un altro flag che identifichi univocamente il nuovo utente
        final participant = room.participants.firstWhere(
                (p) => p.name == participantName // && !p.isCreator // Aggiungi condizione se applicabile
        );
        participantId = participant.id;
      } catch (e) {
        // Fallback se firstWhere fallisce (es. nome duplicato o logica imperfetta)
        // Questo fallback è rischioso, cerca una soluzione migliore se possibile
        if (room.participants.isNotEmpty) {
          participantId = room.participants.last.id;
        }
      }

      if (participantId == null) {
        if (!mounted) return;
        setState(() { _isLoading = false; });
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Joined room, but could not identify participant ID.'),
              backgroundColor: Colors.red),
        );
        return;
      }


      // 5. Naviga alla pagina della stanza
      // Controlla se il widget è ancora montato prima di navigare
      if (!mounted) return;
      navigator.pushReplacementNamed(
        '/room/${widget.roomId}', // Usa l'interpolazione per il path parameter
        arguments: {
          'roomId': widget.roomId,
          'participantId': participantId,
          'userName': participantName,
          'isSpectator': _isSpectator,
          // 'isCreator': false, // Passa questo se necessario
        },
      );
      // Non resettare isLoading qui perché stiamo navigando via

    } catch (e) {
      // Controlla se il widget è ancora montato prima di mostrare SnackBar/aggiornare state
      if (!mounted) return;
      setState(() {
        _isLoading = false; // Resetta il caricamento in caso di errore
      });
      messenger.showSnackBar(
        SnackBar(
            content: Text('Failed to join room: ${e.toString()}'), // Mostra l'errore
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}