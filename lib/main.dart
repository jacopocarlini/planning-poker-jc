import 'dart:convert'; // Per jsonDecode, utf8, base64UrlDecode
import 'dart:html' as html; // Usato solo per html.window.location.reload()

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // Per setUrlStrategy
import 'package:poker_planning/config/theme.dart'; // Assumendo che appThemeData sia definito qui
import 'package:poker_planning/pages/create_room_page.dart';
import 'package:poker_planning/pages/join_room_page.dart';
import 'package:poker_planning/pages/planning_room_page.dart';
import 'package:provider/provider.dart';

import 'components/vote_results_summary_view.dart';
import 'models/room.dart'; // Assumendo che Room.fromVotesList esista
import 'pages/welcome_page.dart';
import 'services/firebase_service.dart';

const String currentAppVersion = "2.0.3";

// --- Entry Point ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(PathUrlStrategy());

  final firebaseService = RealtimeFirebaseService();
  // Se RealtimeFirebaseService().initialize() è un Future<void> che DEVE essere eseguito:
  await firebaseService.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<RealtimeFirebaseService>.value(value: firebaseService),
      ],
      // AppWrapper ora costruirà MaterialApp al suo interno
      child: const AppWrapper(),
    ),
  );
}

// AppWrapper ora costruisce MaterialApp e gestisce il controllo degli aggiornamenti
class AppWrapper extends StatefulWidget {
  const AppWrapper({Key? key}) : super(key: key);

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  // Una GlobalKey per accedere al Navigator di MaterialApp senza un BuildContext diretto
  // che sia discendente di MaterialApp, utile per chiamare showDialog da initState
  // o da addPostFrameCallback.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ora il contesto per showDialog sarà preso da _navigatorKey.currentContext,
      // che appartiene a MaterialApp
      if (mounted) {
        // Controlla se il widget è ancora montato
        _checkForUpdates(context.read<RealtimeFirebaseService>());
      }
    });
  }

  Future<void> _checkForUpdates(RealtimeFirebaseService firebaseService) async {
    // Usa _navigatorKey.currentContext per ottenere un contesto che è un discendente di MaterialApp
    final BuildContext? dialogContext = _navigatorKey.currentContext;

    if (dialogContext == null || !dialogContext.mounted) {
      print(
          "Cannot show update dialog: Navigator context is not available or not mounted.");
      return;
    }

    try {
      String? version = await firebaseService.getVersion();
      print(
          "Version check: Fetched version = $version, Current app version = $currentAppVersion");

      var isBreaking = isBreakingUpdate(version);

      if (isBreaking == true) {
        if (mounted && dialogContext.mounted) {
          // Doppia verifica
          showDialog(
            context: dialogContext,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Update Available'),
                content: const Text(
                    'A new version of the app is available. Please refresh to get the latest features.'),
                actions: [
                  TextButton(
                    child: const Text('Refresh Now'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      html.window.location.reload();
                    },
                  ),
                ],
              );
            },
          );
          print(
              'Update dialog shown. New version: $version, Current: $currentAppVersion');
        }
      }

      if (isBreaking == false) {
        showDialog(
          context: dialogContext,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Update Available'),
              content: const Text(
                  'A new version of the app is available. Please refresh to get the latest features.'),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Refresh Now'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    html.window.location.reload();
                  },
                ),
              ],
            );
          },
        );
        print('App is up-to-date or version check failed severely.');
      } else {
        print('App is up-to-date or version check failed mildly.');
      }
    } catch (e, s) {
      print('Error checking for updates: $e\nStacktrace: $s');
    }
  }

  bool? isBreakingUpdate(String? version) {
    int major = int.parse(version?.split('.')[0] ?? '0');
    int minor = int.parse(version?.split('.')[1] ?? '0');
    int patch = int.parse(version?.split('.')[2] ?? '0');

    int currentMajor = int.parse(currentAppVersion.split('.')[0]);
    int currentMinor = int.parse(currentAppVersion.split('.')[1]);
    int currentPatch = int.parse(currentAppVersion.split('.')[2]);

    if (major > currentMajor) {
      return true;
    }
    if (major == currentMajor && minor > currentMinor) {
      return true;
    }
    if (major == currentMajor &&
        minor == currentMinor &&
        patch > currentPatch) {
      return false;
    }
    return null;
  }

  Room _roomFromShareableLinkData(String base64Data) {
    final String jsonVotes =
        utf8.decode(base64Url.decode(base64Url.normalize(base64Data)));
    final List<dynamic> decodedVotesDynamic =
        jsonDecode(jsonVotes) as List<dynamic>;
    final List<String> votes =
        decodedVotesDynamic.map((e) => e.toString()).toList();
    return Room.fromVotesList(votes);
  }

  @override
  Widget build(BuildContext context) {
    // AppWrapper ora è responsabile della costruzione di MaterialApp
    return MaterialApp(
      navigatorKey: _navigatorKey,
      // Assegna la GlobalKey al Navigator
      title: 'Poker Planning',
      debugShowCheckedModeBanner: false,
      theme: appThemeData,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');
        print(
            "Navigating to: ${uri.path}, segments: ${uri.pathSegments}, arguments: ${settings.arguments}");

        if (uri.pathSegments.isEmpty || uri.path == '/') {
          return MaterialPageRoute(
              builder: (_) => const WelcomePage(), settings: settings);
        }
        if (uri.pathSegments.first == 'create') {
          return MaterialPageRoute(
              builder: (_) => const CreateRoomPage(), settings: settings);
        }
        if (uri.pathSegments.first == 'room' && uri.pathSegments.length > 1) {
          final roomId = uri.pathSegments[1];
          final arguments = settings.arguments;
          if (arguments is Map<String, dynamic> &&
              arguments.containsKey('participantId') &&
              arguments.containsKey('userName') &&
              arguments.containsKey('isSpectator')) {
            return MaterialPageRoute(
              builder: (context) => PlanningRoom(
                roomId: roomId,
                currentParticipantId: arguments['participantId'] as String,
                currentUserName: arguments['userName'] as String,
                isSpectator: arguments['isSpectator'] as bool,
              ),
              settings: settings,
            );
          } else {
            return MaterialPageRoute(
                builder: (context) => JoinRoomPage(roomId: roomId),
                settings: settings);
          }
        }
        if (uri.pathSegments.first == 'result' && uri.pathSegments.length > 1) {
          final base64Data = uri.pathSegments[1];
          try {
            final roomForResults = _roomFromShareableLinkData(base64Data);
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Poker Planning ♠️ Results'),
                    automaticallyImplyLeading: true,
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(
                                context, '/', (route) => false);
                          },
                          icon: const Icon(Icons.home),
                          label: const Text('Home'),
                        ),
                      ),
                    ],
                  ),
                  body: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: VoteResultsSummaryView(room: roomForResults),
                      ),
                    ),
                  )),
              settings: settings,
            );
          } catch (e) {
            print("Error processing result route: $e");
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text("Error")),
                body: Center(
                    child:
                        Text("Could not display results due to an error: $e")),
              ),
              settings: settings,
            );
          }
        }
        print("Unknown route: ${settings.name}");
        return MaterialPageRoute(
            builder: (_) => const WelcomePage(), settings: settings);
      },
    );
  }
}
