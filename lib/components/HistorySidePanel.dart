import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:poker_planning/components/vote_results_summary_view.dart';
import 'package:poker_planning/config/theme.dart';
import 'package:poker_planning/models/room.dart';
import '../models/vote_history_entry.dart';
import 'FullVotingHistoryListView.dart';

class HistorySidePanel extends StatefulWidget {
  final List<VoteHistoryEntry> votingHistory;
  final double collapsedWidth;
  final double expandedWidth;

  final Function(VoteHistoryEntry entry, String newTitle) onUpdateEntryTitle;
  final VoidCallback onAddNewHistoryEntry;
  final Function(VoteHistoryEntry entry) onDeleteEntry;
  final Function(VoteHistoryEntry entry) onSelectedEntry;


  const HistorySidePanel({
    Key? key,
    required this.votingHistory,
    required this.collapsedWidth,
    required this.expandedWidth,
    required this.onUpdateEntryTitle,
    required this.onAddNewHistoryEntry,
    required this.onDeleteEntry,
    required this.onSelectedEntry, // Aggiunto
  }) : super(key: key);

  @override
  _HistorySidePanelState createState() => _HistorySidePanelState();
}

class _HistorySidePanelState extends State<HistorySidePanel> {
  bool isExpanded = false;


  void _toggleExpand() {
    setState(() {
      isExpanded = !isExpanded;
    });
  }

  void _showDetailsDialog(BuildContext context, VoteHistoryEntry entry) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          content: SizedBox(
              height: MediaQuery.sizeOf(context).height / 2,
              width:  MediaQuery.sizeOf(context).width / 2,
              child: VoteResultsSummaryView(room: Room.fromVotesList(entry.voteCounts.keys.toList()))),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
        );
      },
    );
  }

  // Funzione per mostrare il dialogo di conferma cancellazione
  void _showDeleteConfirmationDialog(BuildContext context, VoteHistoryEntry entry) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete the round "${entry.storyTitle ?? 'Unnamed Story'}"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Chiudi il dialogo di conferma
                widget.onDeleteEntry(entry); // Chiama il callback di cancellazione
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final width = isExpanded ? widget.expandedWidth : widget.collapsedWidth;
    final List<VoteHistoryEntry> displayedHistory = List.from(widget.votingHistory)
      ..sort((a, b) => a.id.compareTo(b.id)); // Assumendo che 'id' sia un timestamp o simile per l'ordinamento

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              spreadRadius: 1,
              offset: const Offset(-1, 0),
            ),
          ],
          border: Border(
            left: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
          )),
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.05),
            child: InkWell(
              onTap: _toggleExpand,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    vertical: 12.0, horizontal: isExpanded ? 16.0 : 0),
                child: Row(
                  mainAxisAlignment: isExpanded
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.center,
                  children: [
                    if (isExpanded)
                      Text(
                        'Voting History',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    Icon(
                      isExpanded
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.arrow_back_ios_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: CupertinoColors.lightBackgroundGray),
          Expanded(
            child: displayedHistory.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  isExpanded ? 'No voting history yet.' : '...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ),
            )
                : isExpanded
                ? FullVotingHistoryListView(
              votingHistory: displayedHistory,
              onSelectedEntry: (entry){
                widget.onSelectedEntry(entry);
              },
              onItemTap: _showDetailsDialog,
              onItemDelete: (entry) { // Passa la funzione che mostra il dialogo di conferma
                _showDeleteConfirmationDialog(context, entry);
              }, onUpdateEntryTitle: widget.onUpdateEntryTitle,
            )
                : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: displayedHistory.length,
              itemBuilder: (context, index) {
                final entry = displayedHistory[index];
                return _buildCollapsedHistoryItem(context, entry);
              },
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: CupertinoColors.lightBackgroundGray,),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add New Round'),
                onPressed: widget.onAddNewHistoryEntry,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildCollapsedHistoryItem(BuildContext context, VoteHistoryEntry entry) {
    final title = entry.storyTitle ?? 'Unnamed Story';
    final average = entry.averageVote;

    return Tooltip(
      message: title,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // if (!isExpanded) {
            //   _toggleExpand();
            // }
            Future.delayed(const Duration(milliseconds: 50), () {
              if (ModalRoute.of(context)?.isCurrent ?? false) {
                // _showDetailsDialog(context, entry);
                setState(() {
                  widget.onSelectedEntry(entry);
                });
              }
            });
          },
          child: Container(
            width: widget.collapsedWidth,
            padding: const EdgeInsets.all(4.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      color: entry.selected??false ?  lightBlueGrey :CupertinoColors.lightBackgroundGray ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 50,
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              _getInitials(title),
                              style: TextStyle(fontSize: 14 , fontWeight: FontWeight.bold),
                              overflow: TextOverflow.clip,
                            ),
                            Text(
                              (average?.toStringAsFixed(0) ?? '-'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 14),
                              overflow: TextOverflow.clip,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Funzione per generare iniziali dal nome
  static String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    List<String> nameParts = name.trim().split(' ');
    if (nameParts.length > 1) {
      // Prendi le iniziali del primo e dell'ultimo nome
      return nameParts.first[0].toUpperCase() + nameParts.last[0].toUpperCase();
    } else if (nameParts.isNotEmpty && nameParts.first.isNotEmpty) {
      // Prendi le prime due lettere se c'è solo una parola
      return nameParts.first.length > 1
          ? nameParts.first.substring(0, 2).toUpperCase()
          : nameParts.first[0].toUpperCase();
    }
    return '?';
  }
}
