import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../services/recommendation_service.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  final RecommendationService _recommendationService =
      RecommendationService();

  String _selectedDifficulty = 'Totes';
  double _maxDistance = 15;

  RouteModel? _recommendedRoute;
  bool _isLoading = false;

  Future<void> _recommend() async {
    setState(() {
      _isLoading = true;
      _recommendedRoute = null;
    });

    final result = await _recommendationService.recommendRoute(
      difficulty: _selectedDifficulty,
      maxDistance: _maxDistance,
    );

    setState(() {
      _recommendedRoute = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recomanar ruta'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona les teves preferències',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            DropdownButton<String>(
              value: _selectedDifficulty,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 'Totes',
                  child: Text('Totes les dificultats'),
                ),
                DropdownMenuItem(
                  value: 'Fàcil',
                  child: Text('Fàcil'),
                ),
                DropdownMenuItem(
                  value: 'Mitjana',
                  child: Text('Mitjana'),
                ),
                DropdownMenuItem(
                  value: 'Difícil',
                  child: Text('Difícil'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedDifficulty = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            Text('Distància màxima: ${_maxDistance.toInt()} km'),
            Slider(
              min: 5,
              max: 30,
              divisions: 5,
              value: _maxDistance,
              onChanged: (value) {
                setState(() {
                  _maxDistance = value;
                });
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _recommend,
                child: const Text('Recomanar'),
              ),
            ),

            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_recommendedRoute != null)
              Text(
                'Ruta recomanada:\n'
                '${_recommendedRoute!.name}\n'
                '${_recommendedRoute!.distance} km · '
                '${_recommendedRoute!.difficulty}',
                style: const TextStyle(fontSize: 16),
              )
            else
              const Text(
                'No s’ha trobat cap ruta amb aquests criteris',
              ),
          ],
        ),
      ),
    );
  }
}
