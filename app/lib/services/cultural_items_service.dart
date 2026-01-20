import '../models/cultural_item.dart';

class CulturalItemsService {
  Future<List<CulturalItem>> getItemsByRoute(int routeId) async {
    final allItems = [
      CulturalItem(
        routeId: 1,
        title: 'Monestir de Sant Pere',
        description: 'Monestir romànic del segle XI.',
        latitude: 42.116,
        longitude: 2.764,
        period: 'Edat Mitjana',
        itemType: 'Arquitectura',
      ),
      CulturalItem(
        routeId: 1,
        title: 'Pont medieval',
        description: 'Pont de pedra d’origen medieval.',
        latitude: 42.118,
        longitude: 2.762,
        period: 'Edat Mitjana',
        itemType: 'Història',
      ),
      CulturalItem(
        routeId: 2,
        title: 'Restes ibèriques',
        description: 'Jaciment arqueològic ibèric.',
        latitude: 41.820,
        longitude: 3.070,
        period: 'Antiguitat',
        itemType: 'Arqueologia',
      ),
    ];

    return allItems.where((item) => item.routeId == routeId).toList();
  }
}
