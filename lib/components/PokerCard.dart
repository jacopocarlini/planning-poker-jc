import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';

class PokerCard extends StatefulWidget {
  bool isSelected;
  String value;

  PokerCard({super.key, required this.isSelected, required this.value});


  @override
  _PokerCardState createState() => _PokerCardState();
}

class _PokerCardState extends State<PokerCard> {

  List<Widget> poker_card(bool isSelected, String value) {
    return [
      // Contenitore interno per lo sfondo del numero principale
      Container(
        width: 60,
        height: 100,
        decoration: BoxDecoration(
          color: isSelected ? lightBlueGrey : Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(
              4), // Raggio leggermente più piccolo
        ),
      ),
      // Numero grande centrale
      Padding(
        padding: const EdgeInsets.all(12.0),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown, // Scala il testo se è troppo grande
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                // Dimensione base alta, FittedBox la abbasserà se serve
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade800,
              ),
              maxLines: 2, // Permette di andare a capo una volta se necessario
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      // Numero piccolo in alto a sinistra
      Positioned(
        top: 6,
        left: 4,
        child: Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(8))),
          child: SizedBox(
            height: 20,
            width: 20,
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade700,
                ),
              ),
            ),
          ),
        ),
      ),
      // Numero piccolo in basso a destra
      Positioned(
        bottom: 6,
        right: 4,
        child: Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8))),
          child: SizedBox(
            height: 20,
            width: 20,
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade700,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
        alignment: Alignment.center,
        children: poker_card(widget.isSelected, widget.value));
  }
}
