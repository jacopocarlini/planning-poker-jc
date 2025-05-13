import 'dart:convert'; // Per jsonEncode, utf8, base64UrlEncode
import 'dart:html' as html; // Needed for window.history, window.location
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:poker_planning/config/theme.dart'; // Assicurati che il percorso e le variabili siano corretti
import 'package:poker_planning/models/room.dart'; // Assicurati che il percorso sia corretto

class VoteResultsSummaryView extends StatelessWidget {
  final Room room;

  const VoteResultsSummaryView({
    Key? key,
    required this.room,
  }) : super(key: key);

  Widget _buildResultStat(BuildContext context, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final participantsWhoVoted = room.participants
        .where((p) => p.vote != null && p.vote!.isNotEmpty)
        .toList();

    if (participantsWhoVoted.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: Text(
            "No votes were cast.",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    final Map<String, int> voteCounts = {};
    final List<double> numericVotes = [];
    for (var p in participantsWhoVoted) {
      final vote = p.vote!;
      voteCounts[vote] = (voteCounts[vote] ?? 0) + 1;
      final numericValue = double.tryParse(vote);
      if (numericValue != null) {
        numericVotes.add(numericValue);
      }
    }

    final double? average = numericVotes.isNotEmpty
        ? numericVotes.reduce((a, b) => a + b) / numericVotes.length
        : null;

    final double? consensusStdDev = VoteCalculator.calculateStandardDeviation(
        numericVotes); // Usa la classe helper
    String consensusText = "N/A";
    if (consensusStdDev != null) {
      if (consensusStdDev <= 1.0) {
        consensusText = "Strong Yes 👍";
      } else if (consensusStdDev <= 2) {
        consensusText = "Yes 👍";
      } else {
        consensusText = "No 👎";
      }
    }

    final sortedVotes = voteCounts.entries.toList()
      ..sort((a, b) {
        final numA = double.tryParse(a.key);
        final numB = double.tryParse(b.key);
        if (numA != null && numB != null) return numA.compareTo(numB);
        if (numA != null) return -1;
        if (numB != null) return 1;
        if (a.key == "☕") return 1;
        if (b.key == "☕") return -1;
        if (a.key == "?") return 1;
        if (b.key == "?") return -1;
        return a.key.compareTo(b.key);
      });

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(),
                Text('Voting Results',
                    style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: Icon(Icons.share), // o Theme.of(context).primaryColor
                  tooltip: 'Share Results',
                  onPressed: participantsWhoVoted
                          .isNotEmpty // Disabilita se non ci sono voti
                      ? () => _showShareDialog(context, room)
                      : null, // Disabilita il pulsante se non ci sono voti da condividere
                ),
              ],
            ),
            const SizedBox(height: 26,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResultStat(context, "Total Voters", numericVotes.length.toString()),
                _buildResultStat(context, "Average",
                    average != null ? average.toStringAsFixed(1) : "N/A"),
                _buildResultStat(context, "Standard Deviation",
                    consensusStdDev?.toStringAsFixed(1) ?? 'N/A'),
                _buildResultStat(context, "Consensus", consensusText),
              ],
            ),
            if (sortedVotes.isNotEmpty) ...[
              const Divider(
                height: 24,
                thickness: 1,
                indent: 20,
                endIndent: 20,
                color: lightGrey,
              ),
              Text('Distribution',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                // Use Wrap for flexibility with many vote options
                spacing: 16.0,
                // Horizontal space
                runSpacing: 8.0,
                // Vertical space
                alignment: WrapAlignment.center,
                direction: Axis.horizontal,
                children: sortedVotes.map((entry) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(entry.value.toString()),
                      ),
                      Container(
                        width: 8 * 4,
                        height: 12 * 4,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.blueGrey.shade200,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ]),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Center(
                              child: Text(entry.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // Funzione per mostrare il dialog di condivisione
  void _showShareDialog(BuildContext context, Room room) {
    final String shareableLink = VoteCalculator.generateShareableLink(room);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Share Result"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Link:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300)),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        '$shareableLink',
                        style: TextStyle(
                            color: Colors.blue.shade800, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy to clipboard',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        html.window.navigator.clipboard
                            ?.writeText(shareableLink);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('link copied!'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(10),
                              duration: const Duration(seconds: 2)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close il dialog
              },
            ),
          ],
        );
      },
    );
  }
}

class VoteCalculator {
  static double? calculateStandardDeviation(List<double> votes) {
    final numericVotes = votes.toList();

    if (numericVotes.length < 2) {
      return numericVotes.isEmpty ? null : 0.0;
    }

    final double mean =
        numericVotes.reduce((a, b) => a + b) / numericVotes.length;
    final num sumOfSquaredDifferences =
        numericVotes.map((vote) => pow(vote - mean, 2)).reduce((a, b) => a + b);
    final double variance = sumOfSquaredDifferences / numericVotes.length;
    return sqrt(variance);
  }

  static String generateShareableLink(Room room) {
    // Estrai solo i voti che non sono null o vuoti, come fa il tuo widget
    final List<String> votesToShare = room.participants
        .where((p) => p.vote != null && p.vote!.isNotEmpty)
        .map((p) => p.vote!)
        .toList();
    final baseUrl = '${html.window.location.origin}/result';

    if (votesToShare.isEmpty) {
      // Potresti voler gestire questo caso, magari non generando un link
      // o generando un link che indica "nessun voto"
      return "$baseUrl?error=no_votes";
    }

    // 1. Serializza la lista di voti in JSON
    final String jsonVotes = jsonEncode(votesToShare);

    // 2. Codifica la stringa JSON in Base64 (URL safe)
    final String base64Votes = base64UrlEncode(utf8.encode(jsonVotes));

    // 3. Crea il link
    return "$baseUrl/$base64Votes";
  }
}
