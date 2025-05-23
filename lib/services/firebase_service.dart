// firebase_service.dart
import 'dart:async';
import 'dart:math'; // Necessario per _generateUserId

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:poker_planning/models/participant.dart';
import 'package:poker_planning/models/room.dart';
import 'package:poker_planning/models/vote_history_entry.dart';
import 'package:poker_planning/services/user_preferences_service.dart';

import '../firebase_options.dart';

class RealtimeFirebaseService {
  late final FirebaseDatabase _database;
  final _prefsService = UserPreferencesService();

  // Riferimento base per tutte le stanze
  DatabaseReference get _roomsRef => _database.ref('rooms');

  // Helper per ottenere riferimento a una stanza specifica
  DatabaseReference _getRoomRef(String roomId) => _roomsRef.child(roomId);

  Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _database = FirebaseDatabase.instance;

    deleteEmptyRooms();
  }

  // Genera ID casuale per gli utenti "guest"
  String _generateUserId() {
    return "user_${Random().nextInt(9999999).toString().padLeft(7, '0')}";
  }

  // Create a new room
  Future<Room> createRoom(
      {required String creatorName,
      required bool isSpectator,
      required List<String> cardValues}) async {
    var creatorId = _generateUserId(); // ID casuale per il creatore
    if (await _prefsService.hasId()) {
      creatorId = (await _prefsService.getId())!;
    }
    final creator = Participant(
        id: creatorId,
        name: creatorName,
        isCreator: true,
        isSpectator: isSpectator);
    _prefsService.saveId(creatorId);

    final newRoomRef = _roomsRef.push(); // Firebase genera l'ID della stanza
    final roomId = newRoomRef.key!;

    final newRoom = Room(
        id: roomId,
        creatorId: creatorId,
        participants: [creator], // Inizia con il creatore,
        cardValues: cardValues);

    try {
      await newRoomRef.set(newRoom.toJsonForDb());
      return newRoom;
    } catch (e) {
      throw Exception("Database error during room creation: $e");
    }
  }

  // Join an existing room
  Future<Room?> joinRoom(
      {required String roomId,
      required String participantName,
      required bool isSpectator}) async {
    final roomRef = _getRoomRef(roomId);

    try {
      // Controlla se la stanza esiste prima di tentare un'operazione complessa
      final snapshot = await roomRef.get();
      if (!snapshot.exists) {
        return null;
      }

      var participantId = _generateUserId(); // Nuovo ID casuale
      if (await _prefsService.hasId()) {
        participantId = (await _prefsService.getId())!;
      }
      final newParticipant = Participant(
          id: participantId, name: participantName, isSpectator: isSpectator);
      _prefsService.saveId(participantId);

      // Aggiungi il partecipante alla mappa nel DB
      // Usa `update` per aggiungere/modificare solo questo partecipante
      await roomRef
          .child('participants')
          .child(participantId)
          .set(newParticipant.toJson());

      // Recupera lo stato aggiornato della stanza
      final updatedSnapshot = await roomRef.get();
      if (!updatedSnapshot.exists)
        return null; // Stanza eliminata nel frattempo?

      return Room.fromSnapshot(updatedSnapshot); // Ritorna la stanza aggiornata
    } catch (e) {
      // Potrebbe essere l'eccezione per nome duplicato o un errore DB
      // Rilancia l'eccezione per farla gestire dalla UI
      rethrow;
      // O gestiscila qui se preferisci non mostrarla all'utente
      // return null;
    }
  }

  // Get a stream of room updates
  Stream<Room> getRoomStream(String roomId) {
    final roomRef = _getRoomRef(roomId);

    return roomRef.onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        throw Exception("Room not found or has been deleted.");
      }
      try {
        // Deserializza i dati, gestendo potenziali errori di formato
        return Room.fromSnapshot(snapshot);
      } catch (e) {
        // Lancia un errore specifico per indicare problemi di dati
        throw Exception(
            "Failed to parse room data for $roomId. Data might be corrupted.");
      }
    }).handleError((error) {
      // Logga errori dallo stream stesso (es. problemi di permesso se le regole cambiano)
      // Puoi decidere se rilanciare l'errore o gestirlo diversamente
      // Rilanciare è spesso meglio per far sapere alla UI che c'è un problema
      throw error;
    });
  }

  // Submit a vote for a participant
  Future<void> submitVote(
      {required String roomId,
      required String participantId,
      required String? vote}) async {
    // Riferimento diretto al campo 'vote' di quel partecipante
    final voteRef =
        _getRoomRef(roomId).child('participants/$participantId/vote');

    try {
      // Scrive il voto (o null per cancellare). Nessun controllo su chi lo fa.
      await voteRef.set(vote);
    } catch (e) {
      throw Exception("Database error submitting vote: $e");
    }
  }

  // Reveal all cards in the room
  Future<void> revealCards({required String roomId}) async {
    final roomRef = _getRoomRef(roomId); // Riferimento alla room principale

    final Map<String, int> voteCounts = {};

    try {
      // 1. Ottenere i dati dei partecipanti
      final participantsSnapshot = await roomRef.child('participants').get();

      if (participantsSnapshot.exists && participantsSnapshot.value != null) {
        // Supponiamo che 'participants' sia una mappa dove la chiave è l'ID utente
        // e il valore è un oggetto/mappa con i dettagli del partecipante, incluso 'vote'.
        // Esempio: participants: { "userId1": {"name": "Alice", "vote": "5"}, ... }
        final participantsData =
            participantsSnapshot.value as Map<dynamic, dynamic>;

        participantsData.forEach((participantId, participantDetails) {
          if (participantDetails is Map &&
              participantDetails.containsKey('vote')) {
            final vote = participantDetails['vote'] as String?;
            if (vote != null && vote.isNotEmpty) {
              // Popola voteCounts
              voteCounts['v-$vote'] = (voteCounts['v-$vote'] ?? 0) + 1;
            }
          }
        });
      }

      // 2. Aggiornare la room con areCardsRevealed e nvoteCounts
      // Usiamo update() per modificare/aggiungere campi specifici senza sovrascrivere l'intera room.
      await roomRef.update({
        'areCardsRevealed': true,
      });

      int? idSelected = await getStorySelected(roomId);
      if (idSelected == null) {
        var historyRef = roomRef.child('historyVote');
        final historySnapshot = await historyRef.get();
        int id = 0;
        if (historySnapshot.exists && historySnapshot.value != null) {
          Map historyData = historySnapshot.value as Map;
          id = historyData.values
                  .map((elem) => elem['id'] as int)
                  .reduce((int a, int b) => max(a, b)) +
              1;
        }
        await roomRef
            .child('historyVote')
            .child('v-' + id.toString())
            .set(VoteHistoryEntry(id: id, voteCounts: voteCounts).toJson());
      } else {
        await roomRef
            .child('historyVote')
            .child('v-' + idSelected.toString())
            .update({'voteCounts': voteCounts});
      }
    } catch (e) {
      // È buona pratica loggare l'errore o rilanciare un'eccezione più specifica
      print("Database error in revealCards: $e");
      throw Exception(
          "Database error revealing cards or saving vote counts: $e");
    }
  }

  // Reset voting (hide cards, clear votes)
  Future<void> resetVoting({required String roomId, bool selected = false}) async {
    final roomRef = _getRoomRef(roomId);

    try {
      // Prepara un oggetto `updates` per eseguire modifiche multiple atomicamente
      final Map<String, dynamic> updates = {};

      // 1. Imposta areCardsRevealed a false
      updates['/areCardsRevealed'] = false;

      // 2. Leggi gli ID attuali dei partecipanti per poter cancellare i loro voti
      final participantsSnapshot = await roomRef.child('participants').get();
      if (participantsSnapshot.exists && participantsSnapshot.value is Map) {
        final participantsMap = participantsSnapshot.value as Map;
        for (final participantId in participantsMap.keys) {
          // Aggiungi un percorso all'oggetto updates per cancellare il voto
          updates['/participants/$participantId/vote'] = null;
        }
      }

      // 3. Esegui l'aggiornamento atomico
      if (updates.isNotEmpty) {
        // Esegui solo se ci sono aggiornamenti da fare
        await roomRef.update(updates);
        int? idSelected = await getStorySelected(roomId);
        if (idSelected is int) {
          if(!selected) roomRef.child('currentStoryTitle').set('');
          await roomRef
              .child('historyVote')
              .child('v-' + idSelected.toString())
              .update({'selected': selected});
        }
      }
    } catch (e) {
      throw Exception("Database error resetting voting: $e");
    }
  }

  // Update the card set for the room
  Future<void> updateCardSet(
      {required String roomId, required List<String> newCardValues}) async {
    final cardsRef = _getRoomRef(roomId).child('cardValues');

    try {
      // Scrive la nuova lista di carte. Chiunque può farlo.
      await cardsRef.set(newCardValues);
      // Non resetta automaticamente i voti qui, l'azione è separata.
    } catch (e) {
      throw Exception("Database error updating card set: $e");
    }
  }

  /// Sets up the onDisconnect handler to remove the participant when connection is lost.
  Future<void> setupPresence(String roomId, String participantId) async {
    if (participantId.isEmpty) {
      return;
    }
    // Path to the specific participant within the room
    final participantRef =
        _database.ref('rooms/$roomId/participants/$participantId');

    try {
      // When the client disconnects, remove their data from the participants list
      await participantRef.onDisconnect().remove();

      final participantsSnapshot =
          await _getRoomRef(roomId).child('participants').get();
      if (!(participantsSnapshot.exists && participantsSnapshot.value is Map)) {
        await _getRoomRef(roomId).remove();
      }
    } catch (e) {
      // Handle error appropriately, maybe retry or log
    }
  }

  /// Explicitly removes a participant from the room.
  Future<void> removeParticipant(String roomId, String participantId) async {
    if (participantId.isEmpty) {
      return;
    }
    final participantRef =
        _database.ref('rooms/$roomId/participants/$participantId');
    try {
      await participantRef.remove();

      final participantsSnapshot =
          await _getRoomRef(roomId).child('participants').get();
      if (!(participantsSnapshot.exists && participantsSnapshot.value is Map)) {
        await _getRoomRef(roomId).remove();
      }
    } catch (e) {}
  }

  Future<int> deleteEmptyRooms() async {
    int deletedCount = 0;

    try {
      // 1. Leggi tutti i dati una sola volta sotto il nodo 'rooms'
      final DatabaseEvent event = await _roomsRef.once();
      final DataSnapshot snapshot = event.snapshot;

      // 2. Controlla se esistono dati
      if (!snapshot.exists || snapshot.value == null) {
        return 0;
      }

      // 3. Itera sui dati delle stanze
      // snapshot.value è spesso Map<dynamic, dynamic> o Map<Object?, Object?>
      final dynamic roomsData = snapshot.value;

      if (roomsData is! Map) {
        return 0; // Non possiamo procedere se non è una mappa
      }

      // Copia le chiavi per evitare problemi durante l'iterazione e la modifica
      final List<String> roomIds = roomsData.keys.cast<String>().toList();

      for (final String roomId in roomIds) {
        final dynamic roomSnapshotData = roomsData[roomId];

        // Assicurati che i dati della singola stanza siano una mappa
        if (roomSnapshotData is Map) {
          // 4. Controlla i partecipanti
          final dynamic participantsData = roomSnapshotData['participants'];

          bool isEmpty = false;
          if (participantsData == null) {
            isEmpty = true;
          } else if (participantsData is Map && participantsData.isEmpty) {
            isEmpty = true;
          } else if (participantsData is List && participantsData.isEmpty) {
            // Meno comune in Firebase RTDB usare liste per cose indicizzate da ID, ma controlliamo per sicurezza
            isEmpty = true;
          } else if (participantsData is Map && participantsData.isNotEmpty) {
            // This depends heavily on your data structure for participants
            // Example: If participants Map contains objects with an 'isOnline' flag
            // final onlineParticipants = participantsData.values.where((p) => p is Map && p['isOnline'] == true).length;
            // isEmpty = onlineParticipants == 0;
            // If simply having keys means they exist, then isEmpty is false if participantsData is not empty
            isEmpty = false;
          }

          // 5. Se vuota, elimina la stanza
          if (isEmpty) {
            try {
              await _roomsRef.child(roomId).remove();
              deletedCount++;
            } catch (e) {
              // Continua con le altre stanze anche se una fallisce
            }
          }
        }
      }

      return deletedCount;
    } catch (e) {
      // Potresti voler rilanciare l'errore o gestirlo diversamente
      return deletedCount; // Restituisce il conteggio delle stanze eliminate fino all'errore
    }
  }

  Future<void> updateParticipant(String roomId, String participantId,
      String newName, bool isSpectator) async {
    if (roomId.isEmpty) {
      throw ArgumentError("Room ID cannot be empty.");
    }
    if (participantId.isEmpty) {
      throw ArgumentError("Participant ID cannot be empty.");
    }
    final trimmedNewName =
        newName.trim(); // Rimuovi spazi bianchi iniziali/finali
    if (trimmedNewName.isEmpty) {
      throw ArgumentError("New name cannot be empty or just whitespace.");
    }

    // 2. Riferimento al campo 'name' specifico del partecipante
    final DatabaseReference participantNameRef =
        _getRoomRef(roomId).child('participants/$participantId/name');

    try {
      // 3. Esegui l'aggiornamento usando set() sul riferimento specifico del nome
      // Questo sovrascrive solo il valore del campo 'name'.
      await participantNameRef.set(trimmedNewName);
    } catch (e) {
      // Rilancia l'eccezione per farla gestire dal chiamante (es. UI)
      throw Exception("Database error updating participant name: $e");
    }
    final DatabaseReference participantSpectatorRef =
        _getRoomRef(roomId).child('participants/$participantId/isSpectator');
    await participantSpectatorRef.set(isSpectator);
  }

  Future<void> updateStoryTitle(
      Room room, VoteHistoryEntry entry, String newTitle) async {
    var roomRef = _getRoomRef(room.id);
    entry.storyTitle = newTitle;
    roomRef.child('currentStoryTitle').set(newTitle);

    await roomRef
        .child('historyVote')
        .child('v-' + entry.id.toString())
        .set(entry.toJson());
  }

  Future<void> addHistory(String roomId) async {
    var roomRef = _getRoomRef(roomId);
    var historyRef = roomRef.child('historyVote');
    final historySnapshot = await historyRef.get();
    int id = 0;
    if (historySnapshot.exists && historySnapshot.value != null) {
      Map historyData = historySnapshot.value as Map;
      id = historyData.values
              .map((elem) => elem['id'] as int)
              .reduce((int a, int b) => max(a, b)) +
          1;
    }
    await roomRef.child('historyVote').child('v-' + id.toString()).set(
        VoteHistoryEntry(id: id, voteCounts: {}, storyTitle: 'Unnamed Task')
            .toJson());
  }

  Future<void> deleteHistory(String roomId, VoteHistoryEntry entry) async {
    var roomRef = _getRoomRef(roomId);
    await roomRef
        .child('historyVote')
        .child('v-' + entry.id.toString())
        .remove();
  }

  Future<void> selectedEntry(String roomId, VoteHistoryEntry entry) async {
    var roomRef = _getRoomRef(roomId);

    var historyRef = roomRef.child('historyVote');
    final historySnapshot = await historyRef.get();

    if (historySnapshot.exists && historySnapshot.value != null) {
      var historyData = historySnapshot.value as Map;
      for (var elem in historyData.values) {
        if (elem == null) continue;
        if (elem['id'] is! int) {
          return;
        }
        var id = (elem['id'] as int);
        bool selected = entry.id == id;
        if (elem['selected'] == selected) continue;
        if (selected)
          roomRef.child('currentStoryTitle').set((elem['storyTitle'] ??'Unnamed Task' ) as String);
        roomRef.child('historyVote').child('v-' + id.toString()).update({
          'selected': selected,
        });
        roomRef.update({
          'areCardsRevealed': false,
        });
        resetVoting(roomId: roomId, selected: true);
      }
    }
  }

  Future<int?> getStorySelected(String roomId) async {
    var roomRef = _getRoomRef(roomId);
    var historyRef = roomRef.child('historyVote');
    final historySnapshot = await historyRef.get();
    if (historySnapshot.exists && historySnapshot.value != null) {
      var historyData = historySnapshot.value as Map;
      for (var elem in historyData.values) {
        if (elem == null) continue;
        if (elem['selected'] is bool && elem['selected'] == true) {
          return elem['id'] as int;
        }
      }
    }
    return null;
  }

  Future<String?> getVersion() async {
    return await _database.ref('version').get().then((value) => value.value as String?);
  }
}
