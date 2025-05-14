import 'dart:convert'; // Per jsonEncode, utf8, base64UrlEncode
import 'dart:html' as html; // Needed for window.history, window.location
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:poker_planning/models/room.dart';

class VoteResultsSummaryView extends StatelessWidget {
  final Room room;

  const VoteResultsSummaryView({
    super.key,
    required this.room,
  });

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

  Widget _buildVoteDistributionChart(
    BuildContext context,
    List<MapEntry<String, int>> sortedVotes,
    int totalVoters,
  ) {
    if (sortedVotes.isEmpty) {
      return const SizedBox.shrink();
    }

    // Trova il conteggio massimo per l'asse Y
    final int maxVoteCount =
        sortedVotes.map((e) => e.value).reduce(max).toInt();

    // Determina l'intervallo per l'asse Y
    double yAxisInterval = 1;

    return SizedBox(
      height: 200,
      child: AspectRatio(
        aspectRatio: 3, // Regola questo per le dimensioni del grafico
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxVoteCount + yAxisInterval).toDouble(),
              // Un po' di spazio in alto
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true, // Abilita l'interazione al tocco
                touchTooltipData: BarTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final voteValue = sortedVotes[groupIndex].key;
                    final count = sortedVotes[groupIndex].value;
                    return BarTooltipItem(
                      '',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: count.toString(),
                          style: TextStyle(
                            color: Colors.yellow.shade200,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < sortedVotes.length) {
                        final String voteKey = sortedVotes[index].key;
                        // Per visualizzare meglio i simboli speciali come caffè e punto interrogativo
                        String displayKey = voteKey;
                        double fontSize = 14;

                        return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Container(
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
                                  child: SizedBox(
                                    height: 28,
                                    child: Center(
                                      child: Text(displayKey,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ),
                                  ),
                                ),
                              ),
                            ));
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: yAxisInterval,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color ??
                              Colors.black,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.left,
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                  show: true,
                  border: Border(
                      top: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      bottom: BorderSide(color: Colors.grey.withOpacity(0.3)))),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                // Nascondi le linee verticali della griglia
                horizontalInterval: yAxisInterval,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.3),
                    strokeWidth: 1,
                  );
                },
              ),
              barGroups: sortedVotes.asMap().entries.map((entry) {
                final index = entry.key;
                final voteData = entry.value; // MapEntry<String, int>
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: voteData.value.toDouble(),
                      color: Theme.of(context)
                          .colorScheme
                          .primary, // Usa il colore primario del tema
                      width: 20, // Larghezza delle barre
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
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



    List<MapEntry<String, int>>results = [];

    for (var elem in room.cardValues) {
      results.add(MapEntry(elem, 0));
      for (var p in participantsWhoVoted) {
        final vote = p.vote!;
        if(vote == elem){
          results.last = MapEntry(results.last.key, results.last.value + 1);
        }
      }
    }


    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 48),
                // Spazio per bilanciare l'icona di condivisione
                Text('Voting Results',
                    style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: Icon(Icons.share),
                  tooltip: 'Share Results',
                  onPressed: participantsWhoVoted.isNotEmpty
                      ? () => _showShareDialog(context, room)
                      : null,
                ),
              ],
            ),
            const SizedBox(
              height: 12,
            ),
            _buildVoteDistributionChart(
                context, results, participantsWhoVoted.length),
            const SizedBox(
              height: 46,
            ),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              runAlignment: WrapAlignment.spaceAround,
              spacing: 50,
              children: [
                _buildResultStat(context, "Total Voters",
                    participantsWhoVoted.length.toString()),
                // Usare participantsWhoVoted.length per il totale
                _buildResultStat(context, "Average",
                    average != null ? average.toStringAsFixed(1) : "N/A"),
                _buildResultStat(
                    context,
                    "Standard Deviation",
                    consensusStdDev?.toStringAsFixed(1) ?? 'N/A'),
                _buildResultStat(context, "Consensus", consensusText),
              ],
            ),
            const SizedBox(
              height: 26,
            ),
          ],
        ),
      ),
    );
  }

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
                        shareableLink,
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
                              content: const Text('Link copied!'),
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
                Navigator.of(dialogContext).pop();
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
    final List<String> votesToShare = room.participants
        .where((p) => p.vote != null && p.vote!.isNotEmpty)
        .map((p) => p.vote!)
        .toList();
    final baseUrl = '${html.window.location.origin}/result';

    if (votesToShare.isEmpty) {
      return "$baseUrl?error=no_votes";
    }

    final String jsonVotes = jsonEncode(votesToShare);
    final String base64Votes = base64UrlEncode(utf8.encode(jsonVotes));
    return "$baseUrl/$base64Votes";
  }
}
