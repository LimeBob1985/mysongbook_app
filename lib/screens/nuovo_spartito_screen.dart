import 'package:flutter/material.dart';
import 'componi_spartito_screen.dart'; // Import per la navigazione

class NuovoSpartitoScreen extends StatefulWidget {
  const NuovoSpartitoScreen({super.key});

  @override
  State<NuovoSpartitoScreen> createState() => _NuovoSpartitoScreenState();
}

class _NuovoSpartitoScreenState extends State<NuovoSpartitoScreen> {
  final _titoloController = TextEditingController();
  final _artistaController = TextEditingController();
  final _testoController = TextEditingController();

  final _formKey = GlobalKey<FormState>(); // Per validazione opzionale

  bool proseguiAttivo = false;

  void _checkValidazione() {
    setState(() {
      proseguiAttivo = _titoloController.text.trim().isNotEmpty &&
          _artistaController.text.trim().isNotEmpty;
    });
  }

  void _prosegui() {
    if (!proseguiAttivo) return;
    // Navigazione alla schermata di composizione passando i dati
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComponiSpartitoScreen(
          titolo: _titoloController.text,
          artista: _artistaController.text,
          testoIniziale: _testoController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF303030), // Sfondo aggiornato per coerenza
      body: Column(
        children: [
          // --- HEADER NERO (STESSO STILE DI ELIMINATI) ---
          Container(
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 70,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Tasto Indietro a sinistra
                    Positioned(
                      left: 10,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    // Titolo centrato
                    const Text(
                      "NUOVO SPARTITO",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // -----------------------------------------------

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Campo Titolo
                    const Text(
                      'Titolo del brano',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    _buildRoundedTextField(
                      controller: _titoloController,
                      hintText: 'Inserisci il titolo',
                      onChanged: (_) => _checkValidazione(),
                    ),
                    const SizedBox(height: 20),

                    // Campo Artista
                    const Text(
                      'Nome Artista/Band',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    _buildRoundedTextField(
                      controller: _artistaController,
                      hintText: 'Inserisci l\'artista',
                      onChanged: (_) => _checkValidazione(),
                    ),
                    const SizedBox(height: 20),

                    // Campo Testo
                    const Text(
                      'Scrivi/Incolla il testo',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    _buildRoundedTextField(
                      controller: _testoController,
                      hintText: 'Scrivi o incolla qui il testo della canzone...',
                      maxLines: 15, // Più linee per il testo
                    ),
                    const SizedBox(height: 30),

                    // Pulsante Prosegui - CENTRATO E PICCOLO
                    Align(
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: proseguiAttivo ? _prosegui : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: proseguiAttivo
                                ? const Color(0xFFFFC107)
                                : const Color(0xFFFFC107).withOpacity(0.3), // Trasparenza se non attivo
                            borderRadius: BorderRadius.circular(20), // Arrotondato
                          ),
                          child: Text(
                            'PROSEGUI',
                            style: TextStyle(
                              color: proseguiAttivo ? Colors.black : Colors.black38, 
                              fontWeight: FontWeight.bold,
                              fontSize: 12, // Più piccolo
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30), // Spazio extra in fondo
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper per costruire i TextField arrotondati e bianchi
  Widget _buildRoundedTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15), // Angoli molto arrotondati
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey),
          contentPadding: const EdgeInsets.all(15),
          border: InputBorder.none, // Rimuove il bordo predefinito
        ),
      ),
    );
  }
}