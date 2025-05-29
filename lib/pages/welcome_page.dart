import 'dart:math';

import 'package:flutter/material.dart';
import 'package:poker_planning/services/user_preferences_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/user_profile_chip.dart';
import '../main.dart';
import '../models/room.dart';
import '../services/firebase_service.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _prefsService = UserPreferencesService();
  bool _isLoading = false; // Per il form del nome
  late Future<bool> _hasUsernameFuture;
  late RealtimeFirebaseService _firebaseService;

  List<Room> _createdRooms = [];
  bool _isLoadingRooms = true; // Per il caricamento della lista stanze
  String? _roomsError; // Per errori nel caricamento stanze

  final String _githubUrl =
      'https://github.com/jacopocarlini/planning-poker-jc';

  @override
  void initState() {
    super.initState();
    _firebaseService =
        Provider.of<RealtimeFirebaseService>(context, listen: false);

    _hasUsernameFuture = _prefsService.hasUsername().then((hasUsername) {
      if (hasUsername) {
        _loadCreatedRooms();
      } else if (!hasUsername) {
        // Se non c'è username, non c'è bisogno di mostrare il caricamento per le stanze
        if (mounted) {
          setState(() {
            _isLoadingRooms = false;
          });
        }
      }
      return hasUsername;
    });
  }

  Future<void> _loadCreatedRooms() async {
    setState(() {
      _isLoadingRooms = true;
      _roomsError = null;
    });
    await _firebaseService.getCreatedRoomsStream().listen((List<Room> rooms) {
      setState(() {
        _createdRooms = rooms;
        _isLoadingRooms = false;
      });
    });
  }

  static String generateUserId() {
    return "user_${Random().nextInt(9999999).toString().padLeft(7, '0')}";
  }

  Future<void> _saveNameAndProceed() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final name = _nameController.text.trim();
      try {
        await _prefsService.saveUsername(name);
        await _prefsService.saveId(generateUserId());
        if (mounted) {
          Navigator.pushNamed(context, '/create'); // Va a creare una stanza
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to save name: $e'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open the link.'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _confirmDeleteRoom(Room room, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
              'Are you sure you want to delete the Room "${index}"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _deleteRoom(room.id);
    }
  }

  Future<void> _deleteRoom(String roomId) async {
    // Potresti voler mostrare un indicatore di caricamento specifico per l'eliminazione
    // setState(() => _isDeletingRoom = true);
    try {
      await _firebaseService
          .deleteRoom(roomId); // Assicurati che questo metodo esista!
      if (mounted) {
        setState(() {
          _createdRooms.removeWhere((room) => room.id == roomId);
          // _isDeletingRoom = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Room deleted successfully.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        // setState(() => _isDeletingRoom = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to delete room: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasUsernameFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(
                child: Text('Error loading preferences: ${snapshot.error}')),
          );
        } else {
          final hasUsername = snapshot.data ?? false;
          return body(context, hasUsername);
        }
      },
    );
  }

  Widget body(BuildContext context, bool hasUsername) {
    return Scaffold(
      appBar: hasUsername
          ? AppBar(
              title: const Text('Planning Poker ♠️'),
              automaticallyImplyLeading: true,
              actions: const [
                UserProfileChip(),
                SizedBox(width: 20),
              ],
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              // Aumentato un po' per la lista
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                // Per far sì che la lista usi la larghezza
                children: buildWelcome(context, hasUsername),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> buildWelcome(BuildContext context, bool hasUsername) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 30.0),
        child: Image.asset(
          'assets/logo/logo.png',
          height: 150, // Leggermente ridotto per più spazio
          errorBuilder: (context, error, stackTrace) {
            return const Text("♠️", style: TextStyle(fontSize: 120));
          },
        ),
      ),
      Text(
        'Welcome to Planning Poker!',
        style: Theme.of(context)
            .textTheme
            .headlineMedium
            ?.copyWith(fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 10),
      Text(
        hasUsername
            ? 'Create a new room or manage your existing ones below.'
            : 'Let\'s get started. Please enter your name to join or create a room.',
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 40),
      if (!hasUsername)
        Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a valid name';
                  }
                  return null;
                },
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                onFieldSubmitted: (_) {
                  if (!_isLoading) _saveNameAndProceed();
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continue'),
                      onPressed: _saveNameAndProceed,
                      style:
                          ElevatedButton.styleFrom(minimumSize: Size(500, 50)),
                    ),
            ],
          ),
        )
      else ...[
        // Se l'utente ha un nome, mostra il pulsante Crea e la lista
        buildCreateRoomButton(),
        const SizedBox(height: 42),
        _buildCreatedRoomsList(),
      ],
      const SizedBox(height: 60),
      buildFooter(context),
    ];
  }

  Widget buildCreateRoomButton() {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('Create New Room'),
        onPressed: () {
          Navigator.pushNamed(context, '/create');
        },
        style: ElevatedButton.styleFrom(
          minimumSize: Size(400, 50),
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 12), // Padding per estetica
          // textStyle: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  Widget _buildCreatedRoomsList() {
    if (_isLoadingRooms) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ));
    }

    if (_roomsError != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(_roomsError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ));
    }

    if (_createdRooms.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: Text(
            'You haven\'t created any rooms yet.',
            style: TextStyle(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            'Your Persistent Rooms',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _createdRooms.length,
          itemBuilder: (context, index) {
            final room = _createdRooms[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6.0),
              child: ListTile(
                title: Text('Room ${index + 1}'),
                subtitle: Text('${room.id}'),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error),
                  tooltip: 'Delete Room',
                  onPressed: () => _confirmDeleteRoom(room, index),
                ),
                onTap: () {
                  // Potresti aggiungere la navigazione per entrare in una stanza esistente
                  Navigator.pushNamed(context, '/room/${room.id}');
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget buildFooter(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => _launchUrl(_githubUrl),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.code,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'View on GitHub',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Created with ',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
            RotatedBox(
              // Carta Picche
              quarterTurns: 2,
              // Per capovolgere il simbolo se è una picca standard
              child: Text(
                '♠', // Simbolo Picche (o altro seme a piacere)
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                    fontSize: 14), // Leggermente più grande
              ),
            ),
            Text(
              ' by Jacopo Carlini',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Version ${currentAppVersion}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}
