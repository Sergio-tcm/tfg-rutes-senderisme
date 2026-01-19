import 'package:flutter/material.dart';

class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutes disponibles'),
      ),
      body: const Center(
        child: Text(
          'Aquí es mostraran les rutes',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
