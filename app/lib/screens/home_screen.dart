import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutes de senderisme'),
      ),
      body: const Center(
        child: Text(
          'Pantalla inicial',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
