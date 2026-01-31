import 'package:app/screens/map_screen.dart';
import 'package:flutter/material.dart';
import '../models/cultural_item.dart';
import '../models/rating_item.dart';
import '../models/route_model.dart';
import '../services/cultural_items_service.dart';
import '../services/social_service.dart';

class RouteDetailScreen extends StatefulWidget {
  final RouteModel route;
  static final _culturalItemsService = CulturalItemsService();

  const RouteDetailScreen({super.key, required this.route});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final _socialService = SocialService();
  final _commentCtrl = TextEditingController();

  int _likesCount = 0;
  bool _liked = false;
  bool _likeLoading = false;
  int _score = 5;
  bool _ratingLoading = false;
  Future<List<RatingItem>>? _ratingsFuture;

  @override
  void initState() {
    super.initState();
    _loadSocial();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSocial() async {
    try {
      final likes = await _socialService.getLikesCount(widget.route.routeId);
      bool liked = false;
      try {
        liked = await _socialService.getLikeStatus(widget.route.routeId);
      } catch (_) {
        liked = false;
      }

      if (!mounted) return;
      setState(() {
        _likesCount = likes;
        _liked = liked;
        _ratingsFuture = _socialService.getRatings(widget.route.routeId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ratingsFuture = _socialService.getRatings(widget.route.routeId);
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    setState(() => _likeLoading = true);
    try {
      final wasLiked = _liked;
      final newLiked = wasLiked
          ? await _socialService.unlikeRoute(widget.route.routeId)
          : await _socialService.likeRoute(widget.route.routeId);
      final likes = await _socialService.getLikesCount(widget.route.routeId);

      if (!mounted) return;
      setState(() {
        _liked = newLiked;
        _likesCount = likes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _submitRating() async {
    if (_ratingLoading) return;
    setState(() => _ratingLoading = true);
    try {
      await _socialService.rateRoute(
        routeId: widget.route.routeId,
        score: _score,
        comment: _commentCtrl.text.trim(),
      );

      if (!mounted) return;
      _commentCtrl.clear();
      setState(() {
        _ratingsFuture = _socialService.getRatings(widget.route.routeId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comentari enviat')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _ratingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre + dificultad
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          route.name,
                          style: TextStyle(
                            fontSize: 24, // Aumentado de 22 a 24
                            fontWeight: FontWeight.w800,
                            color: Colors.green[900], // Más oscuro para mejor contraste
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _DifficultyBadge(difficulty: route.difficulty),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _likeLoading ? null : _toggleLike,
                        icon: Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                          color: Colors.white,
                        ),
                        label: Text(
                          '$_likesCount',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _liked ? Colors.pink : Colors.grey[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _liked ? 'T\'agrada aquesta ruta' : 'M\'agrada',
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Ubicación
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      Icon(Icons.place, size: 18, color: Colors.green[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          route.location,
                          style: const TextStyle(color: Colors.black87, fontSize: 16), // Cambiado a negro y tamaño mayor
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Métricas principales
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(title: 'Dades de la ruta'),
                            const SizedBox(height: 10),
                            _InfoRow(
                              label: 'Distància',
                              value: '${route.distanceKm.toStringAsFixed(1)} km',
                            ),
                            _InfoRow(
                              label: 'Desnivell positiu',
                              value: '${route.elevationGain} m+',
                            ),
                            _InfoRow(label: 'Temps estimat', value: route.estimatedTime),
                            _InfoRow(label: 'Dificultat', value: route.difficulty),
                            _InfoRow(
                              label: 'Creat per',
                              value: (route.creatorName != null && route.creatorName!.isNotEmpty)
                                  ? route.creatorName!
                                  : 'Usuari #${route.creatorId}',
                            ),
                            _InfoRow(label: 'Creada el', value: _formatDate(route.createdAt)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Descripción
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(title: 'Descripció'),
                            const SizedBox(height: 8),
                            Text(
                              route.description.isEmpty ? '—' : route.description,
                              style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87), // Aumentado tamaño y color
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Cultural summary
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(title: 'Resum cultural'),
                            const SizedBox(height: 8),
                            FutureBuilder<List<CulturalItem>>(
                              future: _loadCulturalItemsWithRecompute(route.routeId),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState != ConnectionState.done) {
                                  return const LinearProgressIndicator();
                                }

                                if (snapshot.hasError || snapshot.data == null) {
                                  final fallback = route.culturalSummary.isEmpty ? '—' : route.culturalSummary;
                                  return Text(
                                    fallback,
                                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                                  );
                                }

                                final items = snapshot.data!;
                                final summary = _buildCulturalTypesSummary(items);
                                return Text(
                                  summary.isEmpty ? '—' : summary,
                                  style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Chips culturales
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(title: 'Etiquetes culturals'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _buildCulturalChips(route),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(title: 'Comentaris'),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Text('Puntuació:', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                DropdownButton<int>(
                                  value: _score,
                                  items: [1, 2, 3, 4, 5]
                                      .map((v) => DropdownMenuItem(
                                            value: v,
                                            child: Text('$v'),
                                          ))
                                      .toList(),
                                  onChanged: _ratingLoading
                                      ? null
                                      : (v) => setState(() => _score = v ?? 5),
                                ),
                                const Spacer(),
                                ElevatedButton(
                                  onPressed: _ratingLoading ? null : _submitRating,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[700],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Enviar'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _commentCtrl,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Escriu un comentari sobre la ruta...'
                                    ,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<List<RatingItem>>(
                              future: _ratingsFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState != ConnectionState.done) {
                                  return const LinearProgressIndicator();
                                }
                                if (snapshot.hasError) {
                                  return const Text('Error carregant comentaris');
                                }
                                final ratings = snapshot.data ?? [];
                                if (ratings.isEmpty) {
                                  return const Text('Encara no hi ha comentaris.');
                                }

                                return Column(
                                  children: ratings.map((r) {
                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.green[100]!),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${(r.userName != null && r.userName!.isNotEmpty) ? r.userName! : 'Usuari #${r.userId}'} · ${r.score}/5',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            r.comment.isEmpty ? '—' : r.comment,
                                            style: const TextStyle(fontSize: 15, color: Colors.black87),
                                          ),
                                          if (r.createdAt != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              _formatDate(r.createdAt!),
                                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                                            ),
                                          ]
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Botón futuro: ver mapa / ver GPX / POIs
                // (lo dejamos preparado para el sprint del GPX)
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[600]!, Colors.green[800]!],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withAlpha(77),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapScreen(routeId: route.routeId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map, color: Colors.white),
                      label: const Text(
                        'Veure al mapa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCulturalChips(RouteModel r) {
    final chips = <Widget>[];

    if (r.hasHistoricalValue) chips.add(_chip('Històric'));
    if (r.hasArchaeology) chips.add(_chip('Arqueologia'));
    if (r.hasArchitecture) chips.add(_chip('Arquitectura'));
    if (r.hasNaturalInterest) chips.add(_chip('Naturalesa'));

    if (chips.isEmpty) {
      chips.add(_chip('Sense cultura destacada'));
    }

    return chips;
  }

  Widget _chip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)), // Aumentado tamaño de fuente
      visualDensity: VisualDensity.compact,
      backgroundColor: Colors.green[600],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Añadido padding
    );
  }

  Future<List<CulturalItem>> _loadCulturalItemsWithRecompute(int routeId) async {
    var items = await RouteDetailScreen._culturalItemsService.getByRoute(routeId);
    if (items.isEmpty) {
      await RouteDetailScreen._culturalItemsService.recomputeForRoute(routeId: routeId, radiusM: 5000);
      items = await RouteDetailScreen._culturalItemsService.getByRoute(routeId);
    }
    return items;
  }

  String _buildCulturalTypesSummary(List<CulturalItem> items) {
    if (items.isEmpty) return '';

    final counts = <String, int>{};
    for (final item in items) {
      final key = _normalizeType(item.type);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final parts = counts.entries.map((e) {
      final singular = _prettyType(e.key);
      final plural = _pluralizeType(e.key, singular);
      return e.value == 1 ? singular : plural;
    }).toList();

    parts.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return parts.join(', ');
  }

  String _normalizeType(String type) => type.trim().toLowerCase();

  String _prettyType(String type) {
    switch (type) {
      case 'conjunt arquitectònic':
        return 'Conjunt arquitectònic';
      case 'edifici':
        return 'Edifici';
      case 'element arquitectònic':
        return 'Element arquitectònic';
      case 'element urbà':
        return 'Element urbà';
      case 'obra civil':
        return 'Obra civil';
      case 'jaciment arqueològic':
        return 'Jaciment arqueològic';
      case 'jaciment paleontològic':
        return 'Jaciment paleontològic';
      case 'espècimen botànic':
        return 'Espècimen botànic';
      case 'zona d\'interès':
        return 'Zona d\'interès';
      case 'costumari':
        return 'Costumari';
      case 'manifestació festiva':
        return 'Manifestació festiva';
      case 'música i dansa':
        return 'Música i dansa';
      case 'tradició oral':
        return 'Tradició oral';
      case 'tècnica artesanal':
        return 'Tècnica artesanal';
      case 'fons bibliogràfic':
        return 'Fons bibliogràfic';
      case 'fons d\'imatges':
        return 'Fons d\'imatges';
      case 'fons documental':
        return 'Fons documental';
      case 'col·lecció':
        return 'Col·lecció';
      case 'objecte':
        return 'Objecte';
      default:
        return 'Altres';
    }
  }

  String _pluralizeType(String type, String singular) {
    const plurals = {
      'conjunt arquitectònic': 'Conjunts arquitectònics',
      'edifici': 'Edificis',
      'element arquitectònic': 'Elements arquitectònics',
      'element urbà': 'Elements urbans',
      'obra civil': 'Obres civils',
      'jaciment arqueològic': 'Jaciments arqueològics',
      'jaciment paleontològic': 'Jaciments paleontològics',
      'espècimen botànic': 'Espècimens botànics',
      'zona d\'interès': 'Zones d\'interès',
      'costumari': 'Costumaris',
      'manifestació festiva': 'Manifestacions festives',
      'música i dansa': 'Músiques i danses',
      'tradició oral': 'Tradicions orals',
      'tècnica artesanal': 'Tècniques artesanals',
      'fons bibliogràfic': 'Fons bibliogràfics',
      'fons d\'imatges': 'Fons d\'imatges',
      'fons documental': 'Fons documentals',
      'col·lecció': 'Col·leccions',
      'objecte': 'Objectes',
    };

    return plurals[type] ?? '${singular}s';
  }

  String _formatDate(DateTime dt) {
    // Formato simple (sin intl para no meter más dependencias)
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.info_outline, color: Colors.green[700], size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.green[800],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.green[800],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87), // Aumentado tamaño y cambiado a negro
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    switch (difficulty.toLowerCase()) {
      case 'fàcil':
        bgColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case 'mitjana':
        bgColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        break;
      case 'difícil':
        bgColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        break;
      default:
        bgColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Aumentado padding
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bgColor.withAlpha(128)),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          fontSize: 14, // Aumentado de 12 a 14
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
