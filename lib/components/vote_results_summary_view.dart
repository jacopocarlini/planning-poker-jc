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
        Text(label,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold, color: primaryBlue)),
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
        consensusText = "Strong Yes 👍 (${consensusStdDev.toStringAsFixed(1)})";
      } else if (consensusStdDev <= 2.5) {
        consensusText = "Yes 👍 (${consensusStdDev.toStringAsFixed(1)})";
      } else {
        consensusText = "No 👎 (${consensusStdDev.toStringAsFixed(1)})";
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
            Text('Voting Results',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResultStat(context, "Average",
                    average != null ? average.toStringAsFixed(1) : "N/A"),
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
              Text('Vote Distribution',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
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
}
