import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/vote_history_entry.dart'; // Assicurati che il percorso sia corretto

class HistoryListItemCard extends StatefulWidget {
  final VoteHistoryEntry entry;
  final Function(BuildContext, VoteHistoryEntry) onItemTap;
  final Function(VoteHistoryEntry)
      onItemDelete; // Callback per la cancellazione
  final Function(VoteHistoryEntry entry, String newTitle) onUpdateEntryTitle;
  final Function(VoteHistoryEntry entry) onSelectedEntry;

  const HistoryListItemCard({
    Key? key,
    required this.entry,
    required this.onItemTap,
    required this.onItemDelete,
    required this.onUpdateEntryTitle,
    required this.onSelectedEntry,
  }) : super(key: key);

  @override
  HistoryListItemCardState createState() => HistoryListItemCardState();
}

class HistoryListItemCardState extends State<HistoryListItemCard> {
  bool _isHovered = false;

  // Non useremo un controller qui per l'editing inline in questo esempio,
  // l'editing avviene tramite il dialog. Il TextFormField è solo per visualizzazione.
  // Se si volesse l'editing inline, questo controller sarebbe necessario insieme a onUpdateEntryTitle.

  @override
  Widget build(BuildContext context) {
    final title = widget.entry.storyTitle ?? 'Unnamed Task';
    final average = widget.entry.averageVote;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            elevation: _isHovered ? 4 : 2,
            shape: RoundedRectangleBorder(
                side: BorderSide(
                    width: 2,
                    color: widget.entry.selected == true
                        ? primaryBlue
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(8.0)),
            // Leggero effetto di sollevamento sull'hover
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Il TextFormField qui è più per una visualizzazione consistente
                  // con la tua implementazione precedente. L'editing del titolo
                  // avviene principalmente tramite il _VoteDetailsDialog.
                  // Per un vero editing inline, dovresti gestire il salvataggio da qui.
                  TextFormField(
                    // Sostituito TextFormField con Text per semplicità
                    // se l'editing inline non è il focus qui
                    initialValue: title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    decoration: InputDecoration(fillColor: Colors.white),
                    onChanged: (value) {
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
                            widget.entry.voteCounts.isEmpty
                                ? '-'
                                : average != null
                                    ? average.toStringAsFixed(2)
                                    : 'N/A',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (widget.entry.voteCounts.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ElevatedButton(
                                child: const Icon(Icons.bar_chart, size: 18),
                                // label: const Text(''),
                                onPressed: () {
                                  widget.onItemTap(context, widget.entry);
                                },
                                style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 14)),
                              ),
                            ),
                          if (widget.entry.selected == true)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.how_to_vote, size: 18),
                              label: Text('Voting'),
                              onPressed: () {
                                widget.onSelectedEntry(widget.entry);
                              },
                              style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 14)),
                            )
                          else
                            ElevatedButton.icon(
                              icon: const Icon(Icons.how_to_vote, size: 18),
                              label: const Text('Select to vote'),
                              onPressed: () {
                                widget.onSelectedEntry(widget.entry);
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: lightBlueGrey,

                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 14)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isHovered) // Mostra il pulsante solo sull'hover
            Positioned(
              top: 0,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                iconSize: 24,
                tooltip: 'Delete Round',
                splashRadius: 24,
                onPressed: () {
                  widget.onItemDelete(widget.entry);
                },
              ),
            ),
        ],
      ),
    );
  }
}
