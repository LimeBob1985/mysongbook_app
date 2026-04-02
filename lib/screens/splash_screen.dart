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
      body: SafeArea( 
        child: Column(
          children: [
            // Spazio flessibile superiore (3 parti) per alzare il logo
            const Spacer(flex: 3),

            // LOGO VERTICALE (Rimpicciolito ulteriormente a 65)
            Center(
              child: Image.asset(
                'assets/images/logo_vertical.png',
                height: 65, 
              ),
            ),

            const SizedBox(height: 30),

            // BARRA DI CARICAMENTO
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 100.0),
              child: LinearProgressIndicator(
                value: _controller.value,
                backgroundColor: Colors.white24,
                color: Colors.white,
                minHeight: 2,
              ),
            ),

            // Spazio flessibile inferiore (4 parti) per bilanciare verso l'alto
            const Spacer(flex: 4),
          ],
        ),
      ),
    );
  }
}