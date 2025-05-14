// history_side_panel.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:poker_planning/config/theme.dart'; // Se necessario
import '../models/vote_history_entry.dart'; // Assicurati che il percorso sia corretto

class HistorySidePanel extends StatefulWidget {
  final List<VoteHistoryEntry> votingHistory;
  final double collapsedWidth;
  final double expandedWidth;
  // final VoidCallback onToggleExpand; // Non più necessario se gestito internamente

  // CALLBACKS
  final Function(VoteHistoryEntry entry, String newTitle) onUpdateEntryTitle;
  final VoidCallback onAddNewHistoryEntry;
  final Function(VoteHistoryEntry entry) onDeleteEntry; // NUOVO CALLBACK PER LA CANCELLAZIONE

  const HistorySidePanel({
    Key? key,
    required this.votingHistory,
    required this.collapsedWidth,
    required this.expandedWidth,
    // required this.onToggleExpand, // Rimosso perché gestito internamente
    required this.onUpdateEntryTitle,
    required this.onAddNewHistoryEntry,
    required this.onDeleteEntry, // Aggiunto
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
        return _VoteDetailsDialog(
          entry: entry,
          onSave: (updatedEntry, newTitle) {
            widget.onUpdateEntryTitle(updatedEntry, newTitle);
          },
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
                ? _FullVotingHistoryListView(
              votingHistory: displayedHistory,
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
            if (!isExpanded) {
              _toggleExpand();
            }
            Future.delayed(const Duration(milliseconds: 50), () {
              if (ModalRoute.of(context)?.isCurrent ?? false) {
                _showDetailsDialog(context, entry);
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
                  decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      color: CupertinoColors.lightBackgroundGray),
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

class _VoteDetailsDialog extends StatefulWidget {
  final VoteHistoryEntry entry;
  final Function(VoteHistoryEntry entry, String newTitle) onSave;

  const _VoteDetailsDialog({
    Key? key,
    required this.entry,
    required this.onSave,
  }) : super(key: key);

  @override
  __VoteDetailsDialogState createState() => __VoteDetailsDialogState();
}

class __VoteDetailsDialogState extends State<_VoteDetailsDialog> {
  late TextEditingController _titleController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.storyTitle ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSave(widget.entry, _titleController.text.trim());
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final average = widget.entry.averageVote;

    return AlertDialog(
      title: const Text('Vote Details & Edit Title'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: ListBody(
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Story Title',
                  hintText: 'Enter story title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title cannot be empty';
                  }
                  return null;
                },

              ),
              const SizedBox(height: 16),
              if (average != null)
                Text('Average Vote: ${average.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Vote Counts:',
                  style: Theme.of(context).textTheme.titleMedium),
              if (widget.entry.voteCounts.isEmpty)
                const Text('No vote counts recorded.')
              else
                ...widget.entry.voteCounts.entries.map((voteCountEntry) {
                  return Text(
                      '  • Vote "${voteCountEntry.key}": ${voteCountEntry.value} participant(s)');
                }).toList(),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: const Text('Save'),
          onPressed: _handleSave,
        ),
      ],
    );
  }
}

// WIDGET PER CIASCUN ELEMENTO DELLA HISTORY LIST QUANDO ESPANSA
class _HistoryListItemCard extends StatefulWidget {
  final VoteHistoryEntry entry;
  final Function(BuildContext, VoteHistoryEntry) onItemTap;
  final Function(VoteHistoryEntry) onItemDelete; // Callback per la cancellazione
  final Function(VoteHistoryEntry entry, String newTitle) onUpdateEntryTitle;

  const _HistoryListItemCard({
    Key? key,
    required this.entry,
    required this.onItemTap,
    required this.onItemDelete,
    required this.onUpdateEntryTitle,
  }) : super(key: key);

  @override
  __HistoryListItemCardState createState() => __HistoryListItemCardState();

}

class __HistoryListItemCardState extends State<_HistoryListItemCard> {
  bool _isHovered = false;
  // Non useremo un controller qui per l'editing inline in questo esempio,
  // l'editing avviene tramite il dialog. Il TextFormField è solo per visualizzazione.
  // Se si volesse l'editing inline, questo controller sarebbe necessario insieme a onUpdateEntryTitle.

  @override
  Widget build(BuildContext context) {
    final title = widget.entry.storyTitle ?? 'Unnamed Story';
    final average = widget.entry.averageVote;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        elevation: _isHovered ? 4 : 2, // Leggero effetto di sollevamento sull'hover
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Il TextFormField qui è più per una visualizzazione consistente
              // con la tua implementazione precedente. L'editing del titolo
              // avviene principalmente tramite il _VoteDetailsDialog.
              // Per un vero editing inline, dovresti gestire il salvataggio da qui.
              TextFormField( // Sostituito TextFormField con Text per semplicità
                // se l'editing inline non è il focus qui
                initialValue: title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                decoration: InputDecoration(fillColor: Colors.white),
                onChanged: (value){
                  widget.onUpdateEntryTitle(widget.entry, value);
                },
                // overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Average Vote:',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        average != null
                            ? average.toStringAsFixed(2)
                            : 'N/A',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [if (_isHovered) // Mostra il pulsante solo sull'hover
                    Material( // Per il ripple effect e il tooltip
                      color: Colors.transparent,
                      child: IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        iconSize: 20,
                        tooltip: 'Delete Round',
                        splashRadius: 20,
                        onPressed: () {
                          widget.onItemDelete(widget.entry);
                        },
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.bar_chart, size: 18),
                      label: const Text('Details'),
                      onPressed: () {
                        widget.onItemTap(context, widget.entry);
                      },
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 14)),
                    ),],)

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _FullVotingHistoryListView extends StatelessWidget {
  final List<VoteHistoryEntry> votingHistory;
  final Function(BuildContext, VoteHistoryEntry) onItemTap;
  final Function(VoteHistoryEntry) onItemDelete; // NUOVO callback
  final Function(VoteHistoryEntry entry, String newTitle) onUpdateEntryTitle;

  const _FullVotingHistoryListView({
    Key? key,
    required this.votingHistory,
    required this.onItemTap,
    required this.onItemDelete, // Aggiunto
    required this.onUpdateEntryTitle, // Aggiunto
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
        return _HistoryListItemCard( // Utilizza il nuovo widget stateful
          key: ValueKey(entry.id), // Chiave univoca per ogni elemento
          entry: entry,
          onItemTap: onItemTap,
          onItemDelete: onItemDelete, // Passa il callback
          onUpdateEntryTitle: onUpdateEntryTitle,
        );
      },
    );
  }
}

