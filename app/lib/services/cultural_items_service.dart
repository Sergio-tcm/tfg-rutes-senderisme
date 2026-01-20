import '../models/cultural_item.dart';

class CulturalItemsService {
  Future<List<CulturalItem>> getItems() async {
    return [
      CulturalItem(
        title: 'Monestir de Sant Pere',
        description: 'Monestir romànic del segle XI.',
        latitude: 42.116,
        longitude: 2.764,
        period: 'Edat Mitjana',
        itemType: 'Arquitectura',
      ),
      CulturalItem(
        title: 'Pont medieval',
        description: 'Pont de pedra d’origen medieval.',
        latitude: 42.118,
        longitude: 2.762,
        period: 'Edat Mitjana',
        itemType: 'Història',
      ),
    ];
  }
}
