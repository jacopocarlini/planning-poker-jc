// --- Data Models (Devono essere definiti qui o importati) ---
// Assicurati che le classi Participant e Room con i metodi
// toJson(), fromJson(), toJsonForDb(), fromSnapshot() siano presenti.
// (Le definizioni fornite nella risposta precedente sono adatte)
import 'dart:math';

class Participant {
  final String id;
  final String name;
  final String? vote;
  final int? trill;
  final bool isCreator;
  final bool isSpectator;

  Participant({
    required this.id,
    required this.name,
    this.vote,
    this.trill,
    this.isCreator = false,
    this.isSpectator = false,
  });

  Participant copyWith({
    String? id,
    String? name,
    String? vote,
    int? trill,
    bool? isCreator,
    bool? isSpectator,
    bool? clearVote,
  }) {
    return Participant(
      id: id ?? this.id,
      name: name ?? this.name,
      trill: trill ?? this.trill,
      vote: clearVote == true ? null : vote ?? this.vote,
      isCreator: isCreator ?? this.isCreator,
      isSpectator: isSpectator ?? this.isSpectator,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'vote': vote,
    'trill': trill,
    'isCreator': isCreator,
    'isSpectator': isSpectator,
  };

  static Participant fromJson(Map<String, dynamic> json) => Participant(
    id: json['id'] as String? ?? "default_id_${Random().nextInt(1000)}", // Fallback ID se mancante
    name: json['name'] as String? ?? 'Unknown', // Fallback nome se mancante
    vote: json['vote'] as String?,
    trill: json['trill'] as int?,
    isCreator: json['isCreator'] as bool? ?? false,
    isSpectator: json['isSpectator'] as bool? ?? false,
  );
}