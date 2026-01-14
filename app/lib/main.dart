import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const MusicLedApp());
}

class MusicLedApp extends StatelessWidget {
  const MusicLedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music-Led 2.0',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'PressStart2P', // Fuente retro, igual que la web
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
