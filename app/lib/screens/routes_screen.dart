import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../services/routes_service.dart';
import '../widgets/route_card.dart';
import 'route_detail_screen.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final RoutesService _routesService = RoutesService();

  late List<RouteModel> _allRoutes;
  late List<RouteModel> _filteredRoutes;

  String _selectedDifficulty = 'Totes';

  @override
  void initState() {
    super.initState();
    _allRoutes = _routesService.getRoutes();
    _filteredRoutes = _allRoutes;
  }

  void _filterRoutes() {
    setState(() {
      if (_selectedDifficulty == 'Totes') {
        _filteredRoutes = _allRoutes;
      } else {
        _filteredRoutes = _allRoutes
            .where((route) => route.difficulty == _selectedDifficulty)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutes disponibles')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: DropdownButton<String>(
              value: _selectedDifficulty,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 'Totes',
                  child: Text('Totes les dificultats'),
                ),
                DropdownMenuItem(value: 'Fàcil', child: Text('Fàcil')),
                DropdownMenuItem(value: 'Mitjana', child: Text('Mitjana')),
                DropdownMenuItem(value: 'Difícil', child: Text('Difícil')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _selectedDifficulty = value;
                  _filterRoutes();
                }
              },
            ),
          ),
          Expanded(
            child: _filteredRoutes.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No hi ha rutes per aquesta dificultat',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredRoutes.length,
                    itemBuilder: (context, index) {
                      final route = _filteredRoutes[index];
                      return RouteCard(
                        route: route,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RouteDetailScreen(route: route),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
