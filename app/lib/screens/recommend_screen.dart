import 'package:flutter/material.dart';

class RecommendScreen extends StatelessWidget {
  const RecommendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recomanar ruta'),
      ),
      body: const Center(
        child: Text(
          'Aquí es recomanarà una ruta',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
