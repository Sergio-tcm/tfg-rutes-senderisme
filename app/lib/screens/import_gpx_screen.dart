import 'package:flutter/material.dart';

class ImportGpxScreen extends StatelessWidget {
  const ImportGpxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar ruta GPX'),
      ),
      body: const Center(
        child: Text(
          'Aquí es podrà importar un fitxer GPX',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
