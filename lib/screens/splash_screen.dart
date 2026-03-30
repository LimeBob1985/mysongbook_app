import 'package:flutter/material.dart';
import 'crea_spartito_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Aggiorna la UI mentre l’animazione avanza
    _controller.addListener(() {
      setState(() {});
    });

    _controller.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CreaSpartitoScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // LOGO VERTICALE
          Center(
            child: Image.asset(
              'assets/images/logo_vertical.png',
              height: 200,
            ),
          ),

          const SizedBox(height: 40),

          // BARRA DI CARICAMENTO PIÙ PICCOLA E PIÙ CORTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 100.0),
            child: LinearProgressIndicator(
              value: _controller.value,
              backgroundColor: Colors.white24,
              color: Colors.white,
              minHeight: 2, // più sottile, come nella tua foto
            ),
          ),
        ],
      ),
    );
  }
}
