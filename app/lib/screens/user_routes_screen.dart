import 'package:flutter/material.dart';

import '../models/route_model.dart';
import '../services/routes_service.dart';
import '../widgets/route_card.dart';
import 'route_detail_screen.dart';

class UserRoutesScreen extends StatefulWidget {
  final int userId;
  final String userName;

  const UserRoutesScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserRoutesScreen> createState() => _UserRoutesScreenState();
}

class _UserRoutesScreenState extends State<UserRoutesScreen> {
  final RoutesService _routesService = RoutesService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rutes de ${widget.userName}'),
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
          child: FutureBuilder<List<RouteModel>>(
            future: _routesService.getRoutes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Error carregant les rutes'));
              }

              final routes = (snapshot.data ?? [])
                  .where((r) => r.creatorId == widget.userId)
                  .toList();

              if (routes.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.route, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Encara no has creat cap ruta'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: routes.length,
                itemBuilder: (context, index) {
                  final route = routes[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: RouteCard(
                      route: route,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RouteDetailScreen(route: route),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
