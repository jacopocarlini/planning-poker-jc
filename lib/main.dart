import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // Use this for setUrlStrategy
import 'package:poker_planning/pages/create_room_page.dart';
import 'package:poker_planning/pages/join_room_page.dart';
import 'package:poker_planning/pages/landing_page.dart';
import 'package:poker_planning/pages/planning_room_page.dart';
import 'package:provider/provider.dart';

import 'services/firebase_service.dart';


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
}

// --- App Widget ---
class PokerPlanningApp extends StatelessWidget {
  const PokerPlanningApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker Planning',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        // Example of enhancing the theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2.0),
          ),
        ),
      ),
      // Use initialRoute and onGenerateRoute for better web URL handling
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');
        print("Navigating to: ${uri.path}, segments: ${uri.pathSegments}");

        if (uri.pathSegments.isEmpty || uri.path == '/') {
          return MaterialPageRoute(
              builder: (_) => const LandingPage(), settings: settings);
        } else if (uri.pathSegments.first == 'create') {
          return MaterialPageRoute(
              builder: (_) => const CreateRoomPage(), settings: settings);
        } else if (uri.pathSegments.first == 'join') {
          return MaterialPageRoute(
              builder: (_) => const JoinRoomPage(), settings: settings);
        } else if (uri.pathSegments.first == 'room' &&
            uri.pathSegments.length > 1) {
          final roomId = uri.pathSegments[1];
          final arguments = settings.arguments as Map<String, dynamic>?;

          print("Room Route: roomId=$roomId, args=$arguments");

          if (arguments != null && arguments.containsKey('participantId')) {
            // Navigated internally via Create/Join page, args provided
            return MaterialPageRoute(
              builder: (context) => PlanningRoom(
                roomId: arguments['roomId'] as String,
                currentParticipantId: arguments['participantId'] as String,
                currentUserName: arguments['userName'] as String,
                // isCreator might be useful: arguments['isCreator'] as bool? ?? false,
              ),
              settings: settings, // Pass settings along
            );
          } else {
            // Direct URL access or refresh: Need to join the room
            // Pass only the roomId, PlanningRoom will handle joining
            return MaterialPageRoute(
              builder: (context) => PlanningRoom(roomId: roomId),
              settings: settings,
            );
          }
        }

        // Fallback to Landing Page for unknown routes
        return MaterialPageRoute(
            builder: (_) => const LandingPage(), settings: settings);
      },
    );
  }
}
