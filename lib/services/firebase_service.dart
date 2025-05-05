// firebase_service.dart
import 'dart:async';
import 'dart:math'; // Necessario per _generateUserId

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:poker_planning/models/participant.dart';
import 'package:poker_planning/models/room.dart';
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
    print("RealtimeFirebaseService using REAL Firebase (Open Access Mode).");
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
  Future<Room> createRoom({required String creatorName, required List<String> cardValues}) async {
    print("Creating real Firebase room for $creatorName...");

    var creatorId = _generateUserId(); // ID casuale per il creatore
    if(await _prefsService.hasId()){
      creatorId = (await _prefsService.getId())!;
    }
    final creator =
        Participant(id: creatorId, name: creatorName, isCreator: true);
    _prefsService.saveId(creatorId);

    final newRoomRef = _roomsRef.push(); // Firebase genera l'ID della stanza
    final roomId = newRoomRef.key!;

    final newRoom = Room(
      id: roomId,
      creatorId: creatorId,
      participants: [creator], // Inizia con il creatore,
      cardValues: cardValues
    );

    try {
      await newRoomRef.set(newRoom.toJsonForDb());
      print("Real Firebase Room created: $roomId");
      return newRoom;
    } catch (e) {
      print("Error creating room $roomId: $e");
      throw Exception("Database error during room creation: $e");
    }
  }

  // Join an existing room
  Future<Room?> joinRoom(
      {required String roomId, required String participantName}) async {
    print(
        "Attempting to join real Firebase room $roomId as $participantName...");
    final roomRef = _getRoomRef(roomId);

    try {
      // Controlla se la stanza esiste prima di tentare un'operazione complessa
      final snapshot = await roomRef.get();
      if (!snapshot.exists) {
        print("Real Firebase Room $roomId not found");
        return null;
      }

      var participantId = _generateUserId(); // Nuovo ID casuale
      if(await _prefsService.hasId()){
        participantId = (await _prefsService.getId())!;
      }
      final newParticipant =
          Participant(id: participantId, name: participantName);
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

      print("$participantName ($participantId) joined real room $roomId");
      return Room.fromSnapshot(updatedSnapshot); // Ritorna la stanza aggiornata
    } catch (e) {
      print("Error joining room $roomId: $e");
      // Potrebbe essere l'eccezione per nome duplicato o un errore DB
      // Rilancia l'eccezione per farla gestire dalla UI
      rethrow;
      // O gestiscila qui se preferisci non mostrarla all'utente
      // return null;
    }
  }

  // Get a stream of room updates
  Stream<Room> getRoomStream(String roomId) {
    print("Subscribing to real Firebase stream for room $roomId");
    final roomRef = _getRoomRef(roomId);

    return roomRef.onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        print("Snapshot for room $roomId doesn't exist or is null in stream.");
        throw Exception("Room $roomId not found or has been deleted.");
      }
      try {
        // Deserializza i dati, gestendo potenziali errori di formato
        return Room.fromSnapshot(snapshot);
      } catch (e, stacktrace) {
        print("Error deserializing room $roomId from stream: $e");
        print(stacktrace);
        // Lancia un errore specifico per indicare problemi di dati
        throw Exception(
            "Failed to parse room data for $roomId. Data might be corrupted.");
      }
    }).handleError((error) {
      // Logga errori dallo stream stesso (es. problemi di permesso se le regole cambiano)
      print("Error in Firebase stream for room $roomId: $error");
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
    print("Submitting real vote '$vote' for $participantId in room $roomId...");
    // Riferimento diretto al campo 'vote' di quel partecipante
    final voteRef =
        _getRoomRef(roomId).child('participants/$participantId/vote');

    try {
      // Scrive il voto (o null per cancellare). Nessun controllo su chi lo fa.
      await voteRef.set(vote);
      print("Real vote submitted for $participantId in $roomId");
    } catch (e) {
      print("Error submitting vote for $participantId in $roomId: $e");
      throw Exception("Database error submitting vote: $e");
    }
  }

  // Reveal all cards in the room
  Future<void> revealCards({required String roomId}) async {
    print("Revealing real cards in room $roomId...");
    final revealRef = _getRoomRef(roomId).child('areCardsRevealed');
    try {
      // Imposta a true. Chiunque può farlo.
      await revealRef.set(true);
      print("Real cards revealed in $roomId");
    } catch (e) {
      print("Error revealing cards in $roomId: $e");
      throw Exception("Database error revealing cards: $e");
    }
  }

  // Reset voting (hide cards, clear votes)
  Future<void> resetVoting({required String roomId}) async {
    print("Resetting real voting in room $roomId...");
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
      } else {
        print(
            "Warning: No participants found or invalid data structure during reset for room $roomId.");
      }

      // 3. Esegui l'aggiornamento atomico
      if (updates.isNotEmpty) {
        // Esegui solo se ci sono aggiornamenti da fare
        await roomRef.update(updates);
        print("Real voting reset in $roomId");
      } else {
        print("No updates to perform for reset in $roomId.");
      }
    } catch (e) {
      print("Error resetting voting in $roomId: $e");
      throw Exception("Database error resetting voting: $e");
    }
  }

  // Update the card set for the room
  Future<void> updateCardSet(
      {required String roomId, required List<String> newCardValues}) async {
    print("Updating real card set for room $roomId...");
    final cardsRef = _getRoomRef(roomId).child('cardValues');

    try {
      // Scrive la nuova lista di carte. Chiunque può farlo.
      await cardsRef.set(newCardValues);
      print("Real card set updated for $roomId");
      // Non resetta automaticamente i voti qui, l'azione è separata.
    } catch (e) {
      print("Error updating card set for $roomId: $e");
      throw Exception("Database error updating card set: $e");
    }
  }

  /// Sets up the onDisconnect handler to remove the participant when connection is lost.
  Future<void> setupPresence(String roomId, String participantId) async {
    if (participantId.isEmpty) {
      print("Warning: Cannot set up presence without a valid participantId.");
      return;
    }
    // Path to the specific participant within the room
    final participantRef =
        _database.ref('rooms/$roomId/participants/$participantId');

    try {
      // When the client disconnects, remove their data from the participants list
      await participantRef.onDisconnect().remove();
      print(
          "Firebase onDisconnect handler set up for participant $participantId in room $roomId.");

      final participantsSnapshot =
          await _getRoomRef(roomId).child('participants').get();
      if (!(participantsSnapshot.exists && participantsSnapshot.value is Map)) {
        await _getRoomRef(roomId).remove();
      }
    } catch (e) {
      print("Error setting up Firebase onDisconnect handler: $e");
      // Handle error appropriately, maybe retry or log
    }
  }

  /// Explicitly removes a participant from the room.
  Future<void> removeParticipant(String roomId, String participantId) async {
    if (participantId.isEmpty) {
      print(
          "Warning: Cannot remove participant without a valid participantId.");
      return;
    }
    final participantRef =
        _database.ref('rooms/$roomId/participants/$participantId');
    try {
      await participantRef.remove();
      print("Participant $participantId explicitly removed from room $roomId.");

      final participantsSnapshot =
          await _getRoomRef(roomId).child('participants').get();
      print(participantsSnapshot.value);
      if (!(participantsSnapshot.exists && participantsSnapshot.value is Map)) {
        await _getRoomRef(roomId).remove();
      }
    } catch (e) {
      print("Error removing participant $participantId from room $roomId: $e");
    }
  }

  Future<int> deleteEmptyRooms() async {
    print("Starting cleanup of empty rooms...");
    int deletedCount = 0;

    try {
      // 1. Leggi tutti i dati una sola volta sotto il nodo 'rooms'
      final DatabaseEvent event = await _roomsRef.once();
      final DataSnapshot snapshot = event.snapshot;

      // 2. Controlla se esistono dati
      if (!snapshot.exists || snapshot.value == null) {
        print("No rooms found to check.");
        return 0;
      }

      // 3. Itera sui dati delle stanze
      // snapshot.value è spesso Map<dynamic, dynamic> o Map<Object?, Object?>
      final dynamic roomsData = snapshot.value;

      if (roomsData is! Map) {
        print(
            "Error: Expected 'rooms' node to contain a Map, but found ${roomsData.runtimeType}");
        return 0; // Non possiamo procedere se non è una mappa
      }

      // Copia le chiavi per evitare problemi durante l'iterazione e la modifica
      final List<String> roomIds = roomsData.keys.cast<String>().toList();
      print("Found ${roomIds.length} rooms to check.");

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
            print("Room '$roomId' has no participants. Deleting...");
            try {
              await _roomsRef.child(roomId).remove();
              deletedCount++;
              print("Room '$roomId' deleted successfully.");
            } catch (e) {
              print("Error deleting room '$roomId': $e");
              // Continua con le altre stanze anche se una fallisce
            }
          } else {
            // Logica opzionale per contare i partecipanti se non è vuota
            int count = 0;
            if (participantsData is Map) count = participantsData.length;
            if (participantsData is List) count = participantsData.length;
            print("Room '$roomId' has $count participant(s). Skipping.");
          }
        } else {
          print(
              "Warning: Data for room '$roomId' is not a Map. Skipping. Data: $roomSnapshotData");
        }
      }

      print("Finished cleanup. Deleted $deletedCount empty rooms.");
      return deletedCount;
    } catch (e) {
      print("An error occurred during the empty room cleanup process: $e");
      // Potresti voler rilanciare l'errore o gestirlo diversamente
      return deletedCount; // Restituisce il conteggio delle stanze eliminate fino all'errore
    }
  }

  Future<void> updateParticipantName(
      String roomId, String participantId, String newName) async {
    if (roomId.isEmpty) {
      print("Error: Cannot update participant name with empty roomId.");
      throw ArgumentError("Room ID cannot be empty.");
    }
    if (participantId.isEmpty) {
      print("Error: Cannot update participant name with empty participantId.");
      throw ArgumentError("Participant ID cannot be empty.");
    }
    final trimmedNewName =
        newName.trim(); // Rimuovi spazi bianchi iniziali/finali
    if (trimmedNewName.isEmpty) {
      print("Error: Cannot update participant name to an empty string.");
      throw ArgumentError("New name cannot be empty or just whitespace.");
    }

    print(
        "Attempting to update participant $participantId in room $roomId to name '$trimmedNewName'...");

    // 2. Riferimento al campo 'name' specifico del partecipante
    final DatabaseReference participantNameRef =
        _getRoomRef(roomId).child('participants/$participantId/name');

    try {
      // 3. Esegui l'aggiornamento usando set() sul riferimento specifico del nome
      // Questo sovrascrive solo il valore del campo 'name'.
      await participantNameRef.set(trimmedNewName);
      print(
          "Successfully updated name for participant $participantId in room $roomId.");
    } catch (e) {
      print(
          "Error updating name for participant $participantId in room $roomId: $e");
      // Rilancia l'eccezione per farla gestire dal chiamante (es. UI)
      throw Exception("Database error updating participant name: $e");
    }
  }
}
