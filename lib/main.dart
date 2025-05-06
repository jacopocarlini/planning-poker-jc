import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // Use this for setUrlStrategy
import 'package:poker_planning/config/theme.dart';
import 'package:poker_planning/pages/create_room_page.dart';
import 'package:poker_planning/pages/join_room_page.dart';
import 'package:poker_planning/pages/planning_room_page.dart';
import 'package:poker_planning/services/user_preferences_service.dart';
import 'package:provider/provider.dart';

import 'pages/welcome_page.dart';
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
              ),
              settings: settings, // Pass settings along
            );
          } else {
            return MaterialPageRoute(
              builder: (context) => JoinRoomPage(roomId: roomId),
              settings: settings,
            );
          }
        }

        // Fallback to Landing Page for unknown routes
        return MaterialPageRoute(
            builder: (_) => WelcomePage(), settings: settings);
      },
    );
  }
}
