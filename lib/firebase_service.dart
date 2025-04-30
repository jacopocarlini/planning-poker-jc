// firebase_service.dart
import 'dart:async';
import 'dart:math'; // Necessario per _generateUserId

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'firebase_options.dart';

// --- Data Models (Devono essere definiti qui o importati) ---
// Assicurati che le classi Participant e Room con i metodi
// toJson(), fromJson(), toJsonForDb(), fromSnapshot() siano presenti.
// (Le definizioni fornite nella risposta precedente sono adatte)
class Participant {
  final String id;
  final String name;
  final String? vote;
  final bool isCreator;

  Participant({
    required this.id,
    required this.name,
    this.vote,
    this.isCreator = false,
  });

  Participant copyWith({
    String? id,
    String? name,
    String? vote,
    bool? isCreator,
    bool? clearVote,
  }) {
    return Participant(
      id: id ?? this.id,
      name: name ?? this.name,
      vote: clearVote == true ? null : vote ?? this.vote,
      isCreator: isCreator ?? this.isCreator,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'vote': vote,
    'isCreator': isCreator,
  };

  static Participant fromJson(Map<String, dynamic> json) => Participant(
    id: json['id'] as String? ?? "default_id_${Random().nextInt(1000)}", // Fallback ID se mancante
    name: json['name'] as String? ?? 'Unknown', // Fallback nome se mancante
    vote: json['vote'] as String?,
    isCreator: json['isCreator'] as bool? ?? false,
  );
}

class Room {
  final String id;
  final String creatorId;
  final List<Participant> participants;
  final bool areCardsRevealed;
  final List<String> cardValues;

  Room({
    required this.id,
    required this.creatorId,
    required this.participants,
    this.areCardsRevealed = false,
    this.cardValues = const ['0', '1', '2', '3', '5', '8', '13', '?', '☕'],
  });

  Room copyWith({
    String? id,
    String? creatorId,
    List<Participant>? participants,
    bool? areCardsRevealed,
    List<String>? cardValues,
  }) {
    return Room(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      participants: participants ?? this.participants,
      areCardsRevealed: areCardsRevealed ?? this.areCardsRevealed,
      cardValues: cardValues ?? this.cardValues,
    );
  }

  factory Room.fromSnapshot(DataSnapshot snapshot) {
    final roomId = snapshot.key!;
    final value = snapshot.value; // Può essere null se la stanza è vuota o non esiste

    // Gestione del caso in cui value sia null o non sia una mappa
    if (value == null || value is! Map) {
      // Potresti lanciare un'eccezione specifica o restituire una Room 'vuota' o di default
      print("Warning: Room data for $roomId is null or not a Map. Value: $value");
      // In questo caso, lanciamo un'eccezione perché una stanza valida DEVE essere una mappa
      throw FormatException("Invalid data format for room $roomId. Expected a Map.");
    }

    // Ora sappiamo che value è una Map, possiamo fare il cast sicuro
    final data = Map<String, dynamic>.from(value as Map);

    final participantsMap = data['participants'] as Map<dynamic, dynamic>? ?? {};
    final participantsList = participantsMap.entries.map((entry) {
      final participantId = entry.key as String;
      // Controlla se il valore del partecipante è una mappa valida
      final participantValue = entry.value;
      if (participantValue is Map) {
        final participantData = Map<String, dynamic>.from(participantValue);
        // Assicurati che l'ID esista o usa la chiave come fallback
        participantData['id'] = participantData['id'] ?? participantId;
        try {
          return Participant.fromJson(participantData);
        } catch (e) {
          print("Error parsing participant $participantId in room $roomId: $e. Data: $participantData");
          // Salta questo partecipante o crea un partecipante di default
          return Participant(id: participantId, name: "Error Parsing", isCreator: false);
        }
      } else {
        print("Warning: Invalid data for participant $participantId in room $roomId. Value: $participantValue");
        // Salta questo partecipante o crea un partecipante di default
        return Participant(id: participantId, name: "Invalid Data", isCreator: false);
      }

    }).toList();


    final defaultCardValues = const ['0', '1', '2', '3', '5', '8', '13', '?', '☕'];
    final dbCardValues = data['cardValues'] as List<dynamic>?;

    List<String> cardValuesList;
    if (dbCardValues != null) {
      // Filtra eventuali valori null o non stringa prima della conversione
      cardValuesList = dbCardValues
          .where((v) => v != null)
          .map((v) => v.toString())
          .toList();
      // Se dopo il filtro la lista è vuota, usa il default
      if (cardValuesList.isEmpty) {
        cardValuesList = defaultCardValues;
      }
    } else {
      cardValuesList = defaultCardValues;
    }


    return Room(
      id: roomId,
      creatorId: data['creatorId'] as String? ?? '',
      participants: participantsList,
      areCardsRevealed: data['areCardsRevealed'] as bool? ?? false,
      cardValues: cardValuesList,
    );
  }

  Map<String, dynamic> toJsonForDb() => {
    // 'id': id, // L'ID è la CHIAVE nel DB
    'creatorId': creatorId,
    'participants': Map.fromEntries(
        participants.map((p) => MapEntry(p.id, p.toJson()))
    ),
    'areCardsRevealed': areCardsRevealed,
    'cardValues': cardValues,
  };
}
// --- FINE DATA MODELS ---


// --- Servizio Firebase Reale (Modalità Aperta) ---

class RealtimeFirebaseService {
  late final FirebaseDatabase _database;


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
  }

  // Genera ID casuale per gli utenti "guest"
  String _generateUserId() {
    return "user_${Random().nextInt(9999999).toString().padLeft(7, '0')}";
  }

  // Create a new room
  Future<Room> createRoom({required String creatorName}) async {
    print("Creating real Firebase room for $creatorName (Open Access)...");

    final creatorId = _generateUserId(); // ID casuale per il creatore
    final creator = Participant(id: creatorId, name: creatorName, isCreator: true);

    final newRoomRef = _roomsRef.push(); // Firebase genera l'ID della stanza
    final roomId = newRoomRef.key!;
    if (roomId == null) {
      throw Exception("Failed to generate Room ID from Firebase.");
    }


    final newRoom = Room(
      id: roomId,
      creatorId: creatorId,
      participants: [creator], // Inizia con il creatore
    );

    try {
      await newRoomRef.set(newRoom.toJsonForDb());
      print("Real Firebase Room created: $roomId (Open Access)");
      return newRoom;
    } catch (e) {
      print("Error creating room $roomId: $e");
      throw Exception("Database error during room creation: $e");
    }
  }

  // Join an existing room
  Future<Room?> joinRoom({required String roomId, required String participantName}) async {
    print("Attempting to join real Firebase room $roomId as $participantName (Open Access)...");
    final roomRef = _getRoomRef(roomId);

    try {
      // Controlla se la stanza esiste prima di tentare un'operazione complessa
      final snapshot = await roomRef.get();
      if (!snapshot.exists) {
        print("Real Firebase Room $roomId not found (Open Access)");
        return null;
      }

      // Verifica nome duplicato (opzionale, ma buona pratica anche in modalità aperta)
      final currentRoomData = snapshot.value;
      if (currentRoomData is Map) {
        final participantsMap = (currentRoomData['participants'] as Map?) ?? {};
        final nameExists = participantsMap.values.any((pData) => pData is Map && pData['name'] == participantName);
        if (nameExists) {
          print("Participant name '$participantName' already exists in real room $roomId (Open Access)");
          throw Exception("Name '$participantName' already taken in this room.");
        }
      }


      final participantId = _generateUserId(); // Nuovo ID casuale
      final newParticipant = Participant(id: participantId, name: participantName);

      // Aggiungi il partecipante alla mappa nel DB
      // Usa `update` per aggiungere/modificare solo questo partecipante
      await roomRef.child('participants').child(participantId).set(newParticipant.toJson());

      // Recupera lo stato aggiornato della stanza
      final updatedSnapshot = await roomRef.get();
      if (!updatedSnapshot.exists) return null; // Stanza eliminata nel frattempo?

      print("$participantName ($participantId) joined real room $roomId (Open Access)");
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
    print("Subscribing to real Firebase stream for room $roomId (Open Access)");
    final roomRef = _getRoomRef(roomId);

    return roomRef.onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        print("Snapshot for room $roomId doesn't exist or is null in stream (Open Access).");
        throw Exception("Room $roomId not found or has been deleted.");
      }
      try {
        // Deserializza i dati, gestendo potenziali errori di formato
        return Room.fromSnapshot(snapshot);
      } catch (e, stacktrace) {
        print("Error deserializing room $roomId from stream (Open Access): $e");
        print(stacktrace);
        // Lancia un errore specifico per indicare problemi di dati
        throw Exception("Failed to parse room data for $roomId. Data might be corrupted.");
      }
    }).handleError((error) {
      // Logga errori dallo stream stesso (es. problemi di permesso se le regole cambiano)
      print("Error in Firebase stream for room $roomId (Open Access): $error");
      // Puoi decidere se rilanciare l'errore o gestirlo diversamente
      // Rilanciare è spesso meglio per far sapere alla UI che c'è un problema
      throw error;
    });
  }

  // Submit a vote for a participant
  Future<void> submitVote({required String roomId, required String participantId, required String? vote}) async {
    print("Submitting real vote '$vote' for $participantId in room $roomId (Open Access)...");
    // Riferimento diretto al campo 'vote' di quel partecipante
    final voteRef = _getRoomRef(roomId).child('participants/$participantId/vote');

    try {
      // Scrive il voto (o null per cancellare). Nessun controllo su chi lo fa.
      await voteRef.set(vote);
      print("Real vote submitted for $participantId in $roomId (Open Access)");
    } catch (e) {
      print("Error submitting vote for $participantId in $roomId: $e");
      throw Exception("Database error submitting vote: $e");
    }
  }

  // Reveal all cards in the room
  Future<void> revealCards({required String roomId}) async {
    print("Revealing real cards in room $roomId (Open Access)...");
    final revealRef = _getRoomRef(roomId).child('areCardsRevealed');
    try {
      // Imposta a true. Chiunque può farlo.
      await revealRef.set(true);
      print("Real cards revealed in $roomId (Open Access)");
    } catch (e) {
      print("Error revealing cards in $roomId: $e");
      throw Exception("Database error revealing cards: $e");
    }
  }

  // Reset voting (hide cards, clear votes)
  Future<void> resetVoting({required String roomId}) async {
    print("Resetting real voting in room $roomId (Open Access)...");
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
        print("Warning: No participants found or invalid data structure during reset for room $roomId.");
      }


      // 3. Esegui l'aggiornamento atomico
      if (updates.isNotEmpty) { // Esegui solo se ci sono aggiornamenti da fare
        await roomRef.update(updates);
        print("Real voting reset in $roomId (Open Access)");
      } else {
        print("No updates to perform for reset in $roomId.");
      }


    } catch (e) {
      print("Error resetting voting in $roomId: $e");
      throw Exception("Database error resetting voting: $e");
    }
  }

  // Update the card set for the room
  Future<void> updateCardSet({required String roomId, required List<String> newCardValues}) async {
    print("Updating real card set for room $roomId (Open Access)...");
    final cardsRef = _getRoomRef(roomId).child('cardValues');

    try {
      // Scrive la nuova lista di carte. Chiunque può farlo.
      await cardsRef.set(newCardValues);
      print("Real card set updated for $roomId (Open Access)");
      // Non resetta automaticamente i voti qui, l'azione è separata.
    } catch (e) {
      print("Error updating card set for $roomId: $e");
      throw Exception("Database error updating card set: $e");
    }
  }
}