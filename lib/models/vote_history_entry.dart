
class VoteHistoryEntry {
  final int id;
  String? storyTitle;
  final Map<String, int> voteCounts; // Es. {'5': 2, '8': 1}

  VoteHistoryEntry({
    required this.id,
    this.storyTitle,
    required this.voteCounts,
  });


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storyTitle': storyTitle,
      'voteCounts': voteCounts,
    };
  }

  // Per la condivisione via link (JSON)
  factory VoteHistoryEntry.fromJson(Map<String, dynamic> json) {
    var data = json['voteCounts'];
    if(json['id'] is! int){
      return VoteHistoryEntry(id: -1, voteCounts: {});
    }
    Map<String, int> voteCounts = {};
    if (data != null && data is Map<String, int>) {
      voteCounts = convert(Map<String, int>.from(data as Map));
    }
    return VoteHistoryEntry(
      id: json['id'] as int,
      storyTitle: json['storyTitle'] as String?,
      voteCounts: voteCounts,
    );
  }

  static Map<String, int> convert(originalVoteCounts) {
    // Alternativa ancora più concisa usando la "collection for" di Dart (se Dart >= 2.3)
    final Map<String, int> newVoteCountsConcise = {
      for (var entry in originalVoteCounts.entries)
        (entry.key.startsWith('v-') ? entry.key.substring(2) : entry.key) : entry.value
    };
    print('New voteCounts (conciso, senza prefisso "v-"): $newVoteCountsConcise');
    return newVoteCountsConcise;
  }

  // Metodo per calcolare la media, ignorando i voti non numerici
  // Aggiunto qui per comodità, dato che il modello è semplice.
  double? get averageVote {
    if (voteCounts.isEmpty) return null;
    double sum = 0;
    int numericVoteTotalCount = 0;
    voteCounts.forEach((voteValue, count) {
      final numericVal = int.tryParse(voteValue);
      if (numericVal != null) {
        sum += numericVal * count;
        numericVoteTotalCount += count;
      }
    });
    return numericVoteTotalCount > 0 ? sum / numericVoteTotalCount : null;
  }
}