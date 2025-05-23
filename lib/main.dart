import 'dart:convert'; // Per jsonDecode, utf8, base64UrlDecode
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // Use this for setUrlStrategy
import 'package:poker_planning/config/theme.dart';
import 'package:poker_planning/pages/create_room_page.dart';
import 'package:poker_planning/pages/join_room_page.dart';
import 'package:poker_planning/pages/planning_room_page.dart';
import 'package:provider/provider.dart';

import 'components/vote_results_summary_view.dart';
import 'models/room.dart';
import 'pages/welcome_page.dart';
import 'services/firebase_service.dart';

const String currentAppVersion = "1.0.4";

// --- Entry Point ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(PathUrlStrategy()); // Use PathUrlStrategy for cleaner URLs

  // Initialize the Firebase service
  final firebaseService = RealtimeFirebaseService();
  await firebaseService.initialize(); // Ensure initialized before use
  runApp(
    MultiProvider(
      providers: [
        // Provide the single instance of the service
        Provider<RealtimeFirebaseService>.value(value: firebaseService),
      ],
      child: PokerPlanningApp(), // Corrected class name
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    checkForUpdates(firebaseService); // Controlla all'avvio
  });
}

void checkForUpdates(RealtimeFirebaseService firebaseService) async {
  try {
    String? version = await firebaseService.getVersion();

    if (version != null && version != currentAppVersion) {
      html.window.location.reload();
      print('App reloaded.');
    } else {
      print('App up-to-date.');
    }
  } catch (e) {
    print('Error checking for updates: $e');
  }
}

// --- App Widget ---
class PokerPlanningApp extends StatelessWidget {
  const PokerPlanningApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker Planning',
      debugShowCheckedModeBanner: false,
      theme: appThemeData,
      // Use initialRoute and onGenerateRoute for better web URL handling
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');

        if (uri.pathSegments.isEmpty || uri.path == '/') {
          return MaterialPageRoute(
              builder: (_) => const WelcomePage(), settings: settings);
        } else if (uri.pathSegments.first == 'create') {
          return MaterialPageRoute(
              builder: (_) => const CreateRoomPage(), settings: settings);
        } else if (uri.pathSegments.first == 'room' &&
            uri.pathSegments.length > 1) {
          final roomId = uri.pathSegments[1];
          final arguments = settings.arguments as Map<String, dynamic>?;

          if (arguments != null && arguments.containsKey('participantId')) {
            return MaterialPageRoute(
              builder: (context) => PlanningRoom(
                roomId: arguments['roomId'] as String,
                currentParticipantId: arguments['participantId'] as String,
                currentUserName: arguments['userName'] as String,
                isSpectator: arguments['isSpectator'] as bool,
              ),
              settings: settings, // Pass settings along
            );
          } else {
            return MaterialPageRoute(
              builder: (context) => JoinRoomPage(roomId: roomId),
              settings: settings,
            );
          }
        } else if (uri.pathSegments.first == 'result' &&
            uri.pathSegments.length > 1) {
          // final arguments = settings.arguments as Map<String, dynamic>?;
          // final data = arguments?['data'] as String;
          final data = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) => Scaffold(
                appBar: AppBar(
                  title: const Text('Planning Poker ♠️'),
                  automaticallyImplyLeading: false,
                  actions: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/');
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Home'),
                    ),
                    const SizedBox(
                      width: 20,
                    )
                  ],
                ),
                body: Center(
                  child: SizedBox(
                    width: 1200,
                    height: 1000,
                    child: Center(
                      child: VoteResultsSummaryView(
                          room: roomFromShareableLinkData(data)),
                    ),
                  ),
                )),
            settings: settings,
          );
        }

        // Fallback to Landing Page for unknown routes
        return MaterialPageRoute(
            builder: (_) => WelcomePage(), settings: settings);
      },
    );
  }

  Room roomFromShareableLinkData(String base64Data) {
    // 1. Decodifica da Base64 a stringa JSON
    final String jsonVotes = utf8.decode(base64Decode(base64Data));

    // 2. Parsa la stringa JSON per ottenere la lista di voti
    // Il risultato di jsonDecode sarà List<dynamic>, quindi facciamo un cast
    final List<dynamic> decodedVotesDynamic =
        jsonDecode(jsonVotes) as List<dynamic>;
    final List<String> votes =
        decodedVotesDynamic.map((e) => e.toString()).toList();

    // 3. Crea un oggetto Room usando il factory constructor
    return Room.fromVotesList(votes);
  }
}
