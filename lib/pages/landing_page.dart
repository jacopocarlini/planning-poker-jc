// --- Landing Page (New) ---
import 'package:flutter/material.dart';
import 'package:poker_planning/components/user_profile_chip.dart';


class LandingPage extends StatelessWidget {
  LandingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning Poker ♠️'),
        automaticallyImplyLeading: false,
        actions: const [
          UserProfileChip(),
          SizedBox(
            width: 20,
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Welcome to Agile Poker Planning!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create New Room'),
              onPressed: () {
                Navigator.pushNamed(context, '/create');
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
