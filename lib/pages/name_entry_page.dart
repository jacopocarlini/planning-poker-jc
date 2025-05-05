import 'package:flutter/material.dart';
import 'package:poker_planning/services/user_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart'; // Importa se usi url_launcher

class NameEntryPage extends StatefulWidget {
  const NameEntryPage({Key? key}) : super(key: key);

  @override
  State<NameEntryPage> createState() => _NameEntryPageState();
}

class _NameEntryPageState extends State<NameEntryPage> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _prefsService = UserPreferencesService();
  bool _isLoading = false;

  // --- Definisci i percorsi e URL ---
  final String _logoPath = 'assets/logo/logo.png'; // <-- CAMBIA CON IL TUO PATH REALE
  final String _githubUrl = 'https://github.com/jacopocarlini/planning-poker-jc'; // <-- URL REPO

  Future<void> _saveNameAndProceed() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final name = _nameController.text.trim();
      try {
        await _prefsService.saveUsername(name);
        if (mounted) {
          // Naviga alla Landing Page (che ora è la home dopo l'autenticazione)
          // Assicurati che '/' sia gestita correttamente da onGenerateRoute per mostrare LandingPage
          Navigator.pushReplacementNamed(context, '/');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save name: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        // Assicurati che lo stato isLoading sia aggiornato anche se il widget è stato rimosso (unmounted)
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // Funzione per lanciare URL (se usi url_launcher)
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
      // Opzionale: mostra un messaggio all'utente se il link non funziona
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the link.'), backgroundColor: Colors.orange),
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
    // Usiamo SingleChildScrollView per evitare overflow su schermi piccoli
    return Scaffold(
      // Rimuoviamo l'AppBar per dare più spazio e un look da pagina di benvenuto
      // appBar: AppBar(
      //   title: const Text('Welcome to Planning Poker!'),
      // ),
      body: SafeArea( // Assicura che il contenuto non si sovrapponga alla status bar/notch
        child: Center(
          child: SingleChildScrollView( // Permette lo scroll se il contenuto eccede
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox( // Limita la larghezza massima del contenuto centrale
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Centra verticalmente nel viewport (se c'è spazio)
                crossAxisAlignment: CrossAxisAlignment.center, // Centra orizzontalmente gli elementi nella colonna
                children: [
                  // --- Logo/Immagine ---
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30.0), // Spazio sotto l'immagine
                    // child: Image.asset(
                    //   _logoPath,
                    //   height: 120, // Altezza del logo
                    //   errorBuilder: (context, error, stackTrace) => const Icon(Icons.style, size: 80, color: Colors.grey),
                    // ),
                    child: Text("♠️", style: TextStyle(fontSize: 120) ),
                  ),

                  // --- Messaggio di Benvenuto ---
                  Text(
                    'Welcome to Planning Poker!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Let\'s get started. Please enter your name to join or create a room.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40), // Spazio prima del form

                  // --- Form per l'inserimento del nome ---
                  Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Il form occupa solo lo spazio necessario
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Your Name',
                            // border: OutlineInputBorder(), // Sta usando il tema globale ora
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
                            : ElevatedButton.icon( // Pulsante con icona
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Continue'),
                          onPressed: _saveNameAndProceed,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50), // Pulsante largo
                          ),
                        ),
                      ],
                    ),
                  ),
                  // --- Fine Form ---

                  const SizedBox(height: 60), // Spazio maggiore prima del footer

                  // --- Footer con Link e Crediti ---
                  InkWell(
                    onTap: () => _launchUrl(_githubUrl),
                    borderRadius: BorderRadius.circular(4), // Arrotonda l'area cliccabile
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                      child: Row( // Usa Row per icona e testo
                        mainAxisSize: MainAxisSize.min, // Occupa solo lo spazio necessario
                        children: [
                          Icon(Icons.code, size: 18, color: Theme.of(context).colorScheme.primary), // Icona GitHub (o un'icona specifica)
                          const SizedBox(width: 8),
                          Text(
                            'View on GitHub',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              // decoration: TextDecoration.underline, // L'icona aiuta a indicare che è un link
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Created with ♥ by Jacopo Carlini',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  // --- Fine Footer ---
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}