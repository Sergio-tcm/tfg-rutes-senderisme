import 'package:flutter/material.dart';

import '../models/route_model.dart';
import '../services/social_service.dart';
import '../widgets/route_card.dart';
import 'route_detail_screen.dart';

class FavoriteRoutesScreen extends StatefulWidget {
  const FavoriteRoutesScreen({super.key});

  @override
  State<FavoriteRoutesScreen> createState() => _FavoriteRoutesScreenState();
}

class _FavoriteRoutesScreenState extends State<FavoriteRoutesScreen> {
  final SocialService _socialService = SocialService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutes favorites'),
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
            future: _socialService.getLikedRoutes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Error carregant rutes favorites'));
              }

              final routes = snapshot.data ?? [];
              if (routes.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Encara no tens rutes favorites'),
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
