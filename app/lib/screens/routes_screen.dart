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

  String _selectedDifficulty = 'Totes';

  List<RouteModel> _applyFilter(
    List<RouteModel> routes,
  ) {
    if (_selectedDifficulty == 'Totes') {
      return routes;
    }
    return routes
        .where((r) => r.difficulty == _selectedDifficulty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutes disponibles'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.green[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: DropdownButton<String>(
                        value: _selectedDifficulty,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: Icon(Icons.filter_list, color: Colors.green[700]),
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
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<RouteModel>>(
                  future: _routesService.getRoutes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Error carregant les rutes'),
                      );
                    }

                    final routes =
                        _applyFilter(snapshot.data ?? []);

                    if (routes.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No hi ha rutes per aquesta dificultat',
                            ),
                          ],
                        ),
                      );
                    }

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: ListView.builder(
                        key: ValueKey<String>(_selectedDifficulty),
                        itemCount: routes.length,
                        itemBuilder: (context, index) {
                          final route = routes[index];
                          return AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 500),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: RouteCard(
                                route: route,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RouteDetailScreen(
                                              route: route),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
