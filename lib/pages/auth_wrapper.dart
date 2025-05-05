import 'package:flutter/material.dart';
import 'package:poker_planning/pages/landing_page.dart';
import 'package:poker_planning/pages/name_entry_page.dart';
import 'package:poker_planning/services/user_preferences_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _prefsService = UserPreferencesService();
  late Future<bool> _hasUsernameFuture;

  @override
  void initState() {
    super.initState();
    _hasUsernameFuture = _prefsService.hasUsername();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasUsernameFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Mostra uno splash screen o un indicatore di caricamento
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          // Gestisci l'errore (raro con shared_preferences)
          return Scaffold(
            body: Center(child: Text('Error loading preferences: ${snapshot.error}')),
          );
        } else {
          final hasUsername = snapshot.data ?? false;
          // Se l'utente ha un nome, va alla HomePage, altrimenti alla NameEntryPage
          return hasUsername ? LandingPage() : const NameEntryPage();
        }
      },
    );
  }
}