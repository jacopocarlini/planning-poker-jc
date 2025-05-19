import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/vote_history_entry.dart';
import 'HistoryListItemCard.dart';

class FullVotingHistoryListView extends StatelessWidget {
  final List<VoteHistoryEntry> votingHistory;
  final Function(BuildContext, VoteHistoryEntry) onItemTap;
  final Function(VoteHistoryEntry entry) onSelectedEntry;
  final Function(VoteHistoryEntry) onItemDelete;
  final Function(VoteHistoryEntry entry, String newTitle) onUpdateEntryTitle;

  const FullVotingHistoryListView({
    Key? key,
    required this.votingHistory,
    required this.onItemTap,
    required this.onItemDelete, // Aggiunto
    required this.onUpdateEntryTitle,
    required this.onSelectedEntry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (votingHistory.isEmpty) {
      return const Center(
        child: Text('No voting history available.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: votingHistory.length,
      itemBuilder: (context, index) {
        final entry = votingHistory[index];
        return HistoryListItemCard(
            key: ValueKey(entry.id),
            entry: entry,
            onItemTap: onItemTap,
            onItemDelete: onItemDelete,
            onUpdateEntryTitle: onUpdateEntryTitle,
            onSelectedEntry: onSelectedEntry);
      },
    );
  }
}
