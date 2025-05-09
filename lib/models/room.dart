import 'package:firebase_database/firebase_database.dart';
import 'package:poker_planning/models/participant.dart';

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

  // Factory constructor per creare una Room solo da una lista di voti
  factory Room.fromVotesList(List<String> votes) {
    return Room(
      participants: votes.map((vote) => Participant(vote: vote, id: '', name: '')).toList(), id: '', creatorId: '',
    );
  }

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
          // Salta questo partecipante o crea un partecipante di default
          return Participant(id: participantId, name: "Error Parsing", isCreator: false);
        }
      } else {
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