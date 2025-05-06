import 'package:flutter/material.dart';
import 'dart:html' as html; // Per clipboard

class ShareRoomDialogContent extends StatelessWidget {
  final String roomId;
  final String roomUrl;

  const ShareRoomDialogContent({
    Key? key,
    required this.roomId,
    required this.roomUrl,
  }) : super(key: key);

  Widget _buildShareItem(
      BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                  value,
                  style: TextStyle(color: Colors.blue.shade800, fontSize: 15),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Copy to clipboard',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  html.window.navigator.clipboard?.writeText(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('$label copied!'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.all(10),
                        duration: const Duration(seconds: 2)),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Share this link with your team to join:'),
        const SizedBox(height: 16),
        _buildShareItem(context, 'Room Link:', roomUrl),
        const SizedBox(height: 12),
        Text('Or they can enter Room ID:', style: Theme.of(context).textTheme.bodySmall),
        _buildShareItem(context, 'Room ID:', roomId),
      ],
    );
  }
}