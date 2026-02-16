import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/map_config.dart';
import '../models/cultural_item.dart';
import '../services/cultural_items_service.dart';
import '../services/cultural_near_service.dart';
import '../services/location_service.dart';
import '../services/route_files_service.dart';
import '../services/gpx_download_service.dart';
import '../services/gpx_points_parser.dart';
import '../services/routing_service.dart';
import '../services/routes_service.dart';
import '../services/user_preferences_service.dart';
import '../services/recommendation_service.dart';
import '../services/social_service.dart';
import '../models/route_near_item.dart';
import '../models/user_preferences_model.dart';
import 'route_detail_screen.dart';

class MapScreen extends StatefulWidget {
  final int? routeId;
  const MapScreen({super.key, this.routeId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  late final StreamSubscription<MapEvent> _mapEventSubscription;
  Timer? _mapRefreshDebounce;
  StreamSubscription<Position>? _positionSubscription;

  // GPX / Route
  final _routeFilesService = RouteFilesService();
  final _downloadService = GpxDownloadService();
  final _pointsParser = GpxPointsParser();

  // Near me cultural
  final _locationService = LocationService();
  final _culturalNearService = CulturalNearService();
  final _culturalItemsService = CulturalItemsService();
  final _routingService = RoutingService();
  final _routesService = RoutesService();
  final _prefsService = UserPreferencesService();
  final _recoService = RecommendationService();
  final _socialService = SocialService();

  bool _loading = false;
  String? _error;

  List<LatLng> _track = const [];
  List<CulturalItem> _nearItems = const [];
  LatLng? _currentPosition;
  double _currentHeadingDeg = 0;

  // Walking route
  List<LatLng> _walkingTrack = const [];
  double? _walkingDistanceKm;
  int? _walkingDurationMin;
  bool _routingLoading = false;
  String? _routingError;
  CulturalItem? _currentDestination;
  LatLng? _currentRouteStartDestination;
  List<String> _walkingSteps = const [];

  final Map<int, List<LatLng>> _routeTrackCache = {};
  final List<int> _routeTrackCacheOrder = [];
  bool _navigationMode = false;
  List<LatLng> _navigationPath = const [];
  List<LatLng> _navigationCompletedPath = const [];
  double? _distanceToPathM;
  double? _remainingDistanceKm;
  DateTime? _lastOffRouteAlert;
  DateTime? _lastAutoRecalcAt;
  bool _autoRecalculatingRoute = false;
  bool _routeStartReachedNotified = false;
  bool _navActionsExpanded = false;
  int? _activeNavigationRouteId;
  bool _autoFinishingRoute = false;
  final bool _allowPreStartCompletionForTesting = true;

  // valores iniciales "neutros"
  static const LatLng _defaultCenter = LatLng(41.3874, 2.1686); // BCN
  static const double _defaultZoom = 12;

  int _radiusM = 2000;

  @override
  void initState() {
    super.initState();

    _mapEventSubscription = _mapController.mapEventStream.listen((event) {
      _mapRefreshDebounce?.cancel();
      _mapRefreshDebounce = Timer(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() {});
      });
    });

    if (widget.routeId != null) {
      _radiusM = 5000;
      _initRouteMode();
    } else {
      _loadNearMe();
    }
  }

  @override
  void dispose() {
    _mapEventSubscription.cancel();
    _mapRefreshDebounce?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startNavigation(List<LatLng> path) async {
    if (path.length < 2 || !mounted) return;

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    setState(() {
      _navigationMode = true;
      _navActionsExpanded = false;
      _navigationPath = path;
      _navigationCompletedPath = const [];
      _distanceToPathM = null;
      _remainingDistanceKm = null;
      _lastOffRouteAlert = null;
      _lastAutoRecalcAt = null;
      _autoRecalculatingRoute = false;
      _autoFinishingRoute = false;
    });

    if (_currentPosition != null) {
      final targetZoom = max(_mapController.camera.zoom, 16.3).clamp(1.0, 18.0);
      _mapController.move(_currentPosition!, targetZoom);
    }

    try {
      final stream = await _locationService.getPositionStream(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 4,
      );

      _positionSubscription = stream.listen(
        _onPositionUpdate,
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _navigationMode = false;
            _distanceToPathM = null;
            _remainingDistanceKm = null;
            _autoRecalculatingRoute = false;
            _routeStartReachedNotified = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _navigationMode = false;
        _distanceToPathM = null;
        _remainingDistanceKm = null;
        _autoRecalculatingRoute = false;
        _routeStartReachedNotified = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _stopNavigation({bool clearPath = false}) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    if (!mounted) return;
    setState(() {
      _navigationMode = false;
      _navActionsExpanded = false;
      _distanceToPathM = null;
      _remainingDistanceKm = null;
      _lastOffRouteAlert = null;
      _lastAutoRecalcAt = null;
      _autoRecalculatingRoute = false;
      _routeStartReachedNotified = false;
      _autoFinishingRoute = false;
      _navigationCompletedPath = const [];
      _currentRouteStartDestination = null;
      _activeNavigationRouteId = null;
      if (clearPath) {
        _navigationPath = const [];
      }
    });
  }

  void _clearNavigationVisualState() {
    setState(() {
      if (widget.routeId == null) {
        _track = const [];
      }
      _walkingTrack = const [];
      _walkingDistanceKm = null;
      _walkingDurationMin = null;
      _routingError = null;
      _currentDestination = null;
      _currentRouteStartDestination = null;
      _walkingSteps = const [];
      _activeNavigationRouteId = null;
    });
  }

  Future<bool> _showFinishDecisionSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finalitzar ruta',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.green[800],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Has completat la ruta o la deixes per un altre moment?',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('Sí, ruta completada'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, false),
                  icon: const Icon(Icons.schedule),
                  label: const Text('La deixo per un altre moment'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[800],
                    side: BorderSide(color: Colors.green.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    return result == true;
  }

  Future<void> _showCompletionFeedbackSheet(int routeId) async {
    int likesCount = 0;
    bool liked = false;
    try {
      likesCount = await _socialService.getLikesCount(routeId);
      liked = await _socialService.getLikeStatus(routeId);
    } catch (_) {}

    if (!mounted) return;

    int score = 5;
    bool loadingLike = false;
    bool loadingComment = false;
    String? modalError;
    String commentText = '';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final maxHeight = MediaQuery.of(ctx).size.height * 0.82;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  20 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ruta completada! 🎉',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: loadingLike
                            ? null
                            : () async {
                                if (!ctx.mounted) return;
                                setModalState(() => loadingLike = true);
                                try {
                                  liked = liked
                                      ? await _socialService.unlikeRoute(routeId)
                                      : await _socialService.likeRoute(routeId);
                                  likesCount = await _socialService.getLikesCount(routeId);
                                  if (!ctx.mounted) return;
                                  setModalState(() {});
                                } finally {
                                  if (ctx.mounted) {
                                    setModalState(() => loadingLike = false);
                                  }
                                }
                              },
                        icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
                        label: Text('M\'agrada ($likesCount)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: liked ? Colors.pink : Colors.grey[200],
                          foregroundColor: liked ? Colors.white : Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Puntuació:', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: score,
                          items: [1, 2, 3, 4, 5]
                              .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                              .toList(),
                          onChanged: loadingComment
                              ? null
                              : (v) => setModalState(() => score = v ?? 5),
                        ),
                      ],
                    ),
                    TextField(
                      onChanged: (value) {
                        commentText = value;
                      },
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Vols deixar un comentari?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              FocusScope.of(ctx).unfocus();
                              await Future<void>.delayed(
                                const Duration(milliseconds: 80),
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                            },
                            child: const Text(
                              'Tornar al mapa',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: loadingComment
                                ? null
                                : () async {
                                    final comment = commentText.trim();
                                    if (comment.isEmpty) {
                                      if (ctx.mounted) {
                                        setModalState(
                                          () => modalError =
                                              'Escriu un comentari o prem "Tornar al mapa"',
                                        );
                                      }
                                      return;
                                    }

                                    if (!ctx.mounted) return;
                                    setModalState(() => modalError = null);
                                    setModalState(() => loadingComment = true);
                                    var closed = false;
                                    try {
                                      await _socialService.rateRoute(
                                        routeId: routeId,
                                        score: score,
                                        comment: comment,
                                      );
                                      if (ctx.mounted) {
                                        FocusScope.of(ctx).unfocus();
                                        closed = true;
                                        await Future<void>.delayed(
                                          const Duration(milliseconds: 80),
                                        );
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                        }
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setModalState(
                                          () => modalError =
                                              e.toString().replaceFirst('Exception: ', ''),
                                        );
                                      }
                                    } finally {
                                      if (!closed && ctx.mounted) {
                                        setModalState(() => loadingComment = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Desar comentari'),
                          ),
                        ),
                      ],
                    ),
                    if (modalError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        modalError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

  }

  Future<void> _finishNavigationFlow() async {
    setState(() => _navActionsExpanded = false);

    final completed = await _showFinishDecisionSheet();
    if (!completed) {
      await _stopNavigation(clearPath: true);
      _clearNavigationVisualState();
      return;
    }

    final routeIdToComplete = _activeNavigationRouteId ?? widget.routeId;
    if (routeIdToComplete != null) {
      final canPersistCompletion = _routeStartReachedNotified || _allowPreStartCompletionForTesting;
      if (canPersistCompletion) {
        try {
          final completionResult = await _socialService.completeRoute(routeIdToComplete);
          if (mounted) {
            final message = (completionResult['preference_update_message']?.toString().trim().isNotEmpty ?? false)
                ? completionResult['preference_update_message'].toString()
                : 'Ruta completada.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        } catch (e, st) {
          debugPrint('[ROUTE_COMPLETE_ERROR] route_id=$routeIdToComplete message=${e.toString().replaceFirst('Exception: ', '')}');
          debugPrint('[ROUTE_COMPLETE_STACK] $st');
        }
      }

      await _showCompletionFeedbackSheet(routeIdToComplete);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 180));
    }

    await _stopNavigation(clearPath: true);
    _clearNavigationVisualState();
  }

  Future<void> _finishNavigationFlowAutomatically() async {
    if (!mounted || _autoFinishingRoute || !_navigationMode) return;

    setState(() {
      _autoFinishingRoute = true;
      _navActionsExpanded = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Has arribat al final de la ruta')),
    );

    try {
      await _finishNavigationFlow();
    } finally {
      if (mounted) {
        setState(() {
          _autoFinishingRoute = false;
        });
      }
    }
  }

  Future<void> _autoRecalculateToCurrentDestination(LatLng currentPos) async {
    final destination = _currentDestination;
    if (!mounted || destination == null || !_navigationMode || _autoRecalculatingRoute) {
      return;
    }

    setState(() {
      _autoRecalculatingRoute = true;
    });

    try {
      final result = await _routingService.walkingRoute(
        startLat: currentPos.latitude,
        startLon: currentPos.longitude,
        endLat: destination.latitude,
        endLon: destination.longitude,
      );

      final pts = _downsamplePoints(
        result.polyline.map((p) => LatLng(p[0], p[1])).toList(),
        maxPoints: 1000,
      );

      if (pts.length < 2 || !mounted) return;

      setState(() {
        _walkingTrack = pts;
        _walkingDistanceKm = result.distanceKm;
        _walkingDurationMin = ((result.distanceKm / 4.5) * 60).round();
        _walkingSteps = result.steps
            .where((s) => s.toLowerCase() != 'altres')
            .map(_normalizeStepName)
            .where((s) => s.isNotEmpty)
            .toList();
        _navigationPath = pts;
        _navigationCompletedPath = const [];
        _distanceToPathM = null;
        _remainingDistanceKm = result.distanceKm;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta recalculada automàticament')),
      );
    } catch (_) {
      // mantenim la ruta actual si no es pot recalcular
    } finally {
      if (mounted) {
        setState(() {
          _autoRecalculatingRoute = false;
        });
      }
    }
  }

  Future<void> _autoRecalculateToRouteStart(LatLng currentPos) async {
    final routeStart = _currentRouteStartDestination;
    if (!mounted || routeStart == null || !_navigationMode || _autoRecalculatingRoute || _track.length < 2) {
      return;
    }

    setState(() {
      _autoRecalculatingRoute = true;
    });

    try {
      final result = await _routingService.walkingRoute(
        startLat: currentPos.latitude,
        startLon: currentPos.longitude,
        endLat: routeStart.latitude,
        endLon: routeStart.longitude,
      );

      final walkingPts = _downsamplePoints(
        result.polyline.map((p) => LatLng(p[0], p[1])).toList(),
        maxPoints: 1000,
      );

      if (walkingPts.length < 2 || !mounted) return;

      final routeDistanceKm = _trackDistanceKm(_track);
      final totalDistanceKm = result.distanceKm + routeDistanceKm;
      final totalDurationMin = ((totalDistanceKm / 4.5) * 60).round();

      final navPath = <LatLng>[];
      navPath.addAll(walkingPts);
      navPath.addAll(_track);

      setState(() {
        _walkingTrack = walkingPts;
        _walkingDistanceKm = totalDistanceKm;
        _walkingDurationMin = totalDurationMin;
        _walkingSteps = result.steps
            .where((s) => s.toLowerCase() != 'altres')
            .map(_normalizeStepName)
            .where((s) => s.isNotEmpty)
            .toList();
        _navigationPath = navPath;
        _navigationCompletedPath = const [];
        _distanceToPathM = null;
        _remainingDistanceKm = totalDistanceKm;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta fins a l\'inici recalculada automàticament')),
      );
    } catch (_) {
      // mantenim la ruta actual si no es pot recalcular
    } finally {
      if (mounted) {
        setState(() {
          _autoRecalculatingRoute = false;
        });
      }
    }
  }

  void _onPositionUpdate(Position pos) {
    if (!mounted) return;

    final point = LatLng(pos.latitude, pos.longitude);
    final path = _navigationPath;

    int nearestIndex = -1;
    double minDistanceM = double.infinity;

    if (_navigationMode && path.isNotEmpty) {
      for (var i = 0; i < path.length; i++) {
        final distance = _haversineKm(point, path[i]) * 1000;
        if (distance < minDistanceM) {
          minDistanceM = distance;
          nearestIndex = i;
        }
      }
    }

    setState(() {
      _currentPosition = point;
      _currentHeadingDeg = (pos.heading.isFinite && pos.heading >= 0) ? pos.heading : _currentHeadingDeg;
      if (_navigationMode && path.isNotEmpty && nearestIndex >= 0) {
        _distanceToPathM = minDistanceM;
        _navigationCompletedPath = path.sublist(0, nearestIndex + 1);
        final remaining = path.sublist(nearestIndex);
        _remainingDistanceKm = _trackDistanceKm(remaining);
      }
    });

    if (_navigationMode && _currentRouteStartDestination != null && !_routeStartReachedNotified) {
      final distanceToStartM = _haversineKm(point, _currentRouteStartDestination!) * 1000;
      if (distanceToStartM.isFinite && distanceToStartM <= 25) {
        setState(() {
          _routeStartReachedNotified = true;
          _currentRouteStartDestination = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Has arribat a l\'inici. Comença la ruta guiada!'),
          ),
        );
      }
    }

    if (_navigationMode &&
        !_autoFinishingRoute &&
        _activeNavigationRouteId != null &&
        _currentRouteStartDestination == null &&
        _track.isNotEmpty &&
        path.isNotEmpty &&
        nearestIndex >= 0) {
      final tailStartIndex = max(0, path.length - 3);
      final isNearTail = nearestIndex >= tailStartIndex;
      final distanceToEndM = _haversineKm(point, _track.last) * 1000;
      final remainingDistanceM = (_remainingDistanceKm ?? double.infinity) * 1000;
      final reachedEnd = (distanceToEndM.isFinite && distanceToEndM <= 25) ||
          (remainingDistanceM.isFinite && remainingDistanceM <= 30);

      if (isNearTail && reachedEnd) {
        unawaited(_finishNavigationFlowAutomatically());
        return;
      }
    }

    if (_navigationMode && minDistanceM.isFinite && minDistanceM > 50) {
      final now = DateTime.now();
      final shouldNotify = _lastOffRouteAlert == null ||
          now.difference(_lastOffRouteAlert!) >= const Duration(seconds: 20);
      if (shouldNotify && mounted) {
        _lastOffRouteAlert = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('T\'has desviat de la ruta (més de 50 m)')),
        );
      }

      final canAutoRecalc = _currentDestination != null && !_autoRecalculatingRoute;
      final canAutoRecalcRouteStart = _currentRouteStartDestination != null && !_autoRecalculatingRoute;
      final enoughTimeSinceLastRecalc = _lastAutoRecalcAt == null ||
          now.difference(_lastAutoRecalcAt!) >= const Duration(seconds: 30);
      if ((canAutoRecalc || canAutoRecalcRouteStart) && enoughTimeSinceLastRecalc) {
        _lastAutoRecalcAt = now;
        if (canAutoRecalc) {
          unawaited(_autoRecalculateToCurrentDestination(point));
        } else if (canAutoRecalcRouteStart) {
          unawaited(_autoRecalculateToRouteStart(point));
        }
      }
    }
  }

  Future<void> _loadNearMe() async {
    setState(() {
      _loading = true;
      _error = null;
      _nearItems = const [];
      _track = const [];
    });

    Position? lastKnown;
    try {
      lastKnown = await _locationService.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        _currentPosition = LatLng(lastKnown.latitude, lastKnown.longitude);

        final items = await _culturalNearService.near(
          lat: lastKnown.latitude,
          lon: lastKnown.longitude,
          radius: _radiusM,
        );

        if (!mounted) return;
        setState(() {
          _nearItems = items;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _adjustZoomForRadius();
        });

        setState(() => _loading = false);
      }

      final pos = await _locationService.getCurrentPosition(
        accuracy: LocationAccuracy.medium,
        timeout: const Duration(seconds: 8),
      );
      _currentPosition = LatLng(pos.latitude, pos.longitude);

      final items = await _culturalNearService.near(
        lat: pos.latitude,
        lon: pos.longitude,
        radius: _radiusM,
      );

      if (!mounted) return;
      setState(() {
        _nearItems = items;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _adjustZoomForRadius();
      });
    } catch (e) {
      if (lastKnown == null) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadRouteTrack(int routeId) async {
    setState(() {
      _loading = true;
      _error = null;
      _track = const [];
      _nearItems = const [];
    });

    try {
      final files = await _routeFilesService.listFiles(routeId);

      if (files.isEmpty) {
        throw Exception('Aquesta ruta no té cap fitxer associat');
      }

      final gpx = files.firstWhere(
        (f) => (f['file_type']?.toString().toUpperCase() == 'GPX'),
        orElse: () => files.first,
      );

      final url = gpx['file_url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('URL del GPX no disponible');
      }

      final content = await _downloadService.download(url);
      final points = _pointsParser.parsePoints(content);

      if (points.length < 2) {
        throw Exception('El GPX no conté punts suficients');
      }

      setState(() {
        _track = points;
      });

      // Ajustar cámara para ver toda la ruta
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(40),
          ),
        );
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _initRouteMode() async {
    final routeId = widget.routeId;
    if (routeId == null) return;
    await _loadRouteTrack(routeId);
    await _loadRouteCulturalItems(recomputeIfEmpty: true);
  }

  Future<void> _loadRouteCulturalItems({bool recomputeIfEmpty = false}) async {
    final routeId = widget.routeId;
    if (routeId == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _nearItems = const [];
    });

    try {
      var items = await _culturalItemsService.getByRoute(routeId);

      if (items.isEmpty && recomputeIfEmpty) {
        await _culturalItemsService.recomputeForRoute(
          routeId: routeId,
          radiusM: _radiusM,
        );
        items = await _culturalItemsService.getByRoute(routeId);
      }

      setState(() {
        _nearItems = items;
      });

      _fitToRouteAndItems();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _recomputeRouteCulturalItems() async {
    final routeId = widget.routeId;
    if (routeId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _culturalItemsService.recomputeForRoute(
        routeId: routeId,
        radiusM: _radiusM,
      );
      final items = await _culturalItemsService.getByRoute(routeId);
      setState(() {
        _nearItems = items;
      });

      _fitToRouteAndItems();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _fitToRouteAndItems() {
    if (!mounted) return;

    final points = <LatLng>[];
    if (_track.isNotEmpty) {
      points.addAll(_track);
    }
    if (_nearItems.isNotEmpty) {
      points.addAll(
        _nearItems.map((item) => LatLng(item.latitude, item.longitude)),
      );
    }

    if (points.length < 2) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
        ),
      );
    });
  }

  // ---------- UI helpers ----------
  String _getCategory(String type) {
    final t = type.toLowerCase();
    if (t.contains('conjunt arquitectònic') || t.contains('edifici') || t.contains('element arquitectònic') || t.contains('element urbà') || t.contains('obra civil')) {
      return 'arquitectura';
    }
    if (t.contains('jaciment arqueològic') || t.contains('jaciment paleontològic')) {
      return 'arqueologia';
    }
    if (t.contains('espècimen botànic') || t.contains('zona d\'interès')) {
      return 'natural';
    }
    if (t.contains('costumari') || t.contains('manifestació festiva') || t.contains('música i dansa') || t.contains('tradició oral') || t.contains('tècnica artesanal')) {
      return 'cultural';
    }
    if (t.contains('fons bibliogràfic') || t.contains('fons d\'imatges') || t.contains('fons documental')) {
      return 'documental';
    }
    if (t.contains('col·lecció') || t.contains('objecte')) {
      return 'objectes';
    }
    return 'altres';
  }

  IconData _iconForType(String type) {
    final category = _getCategory(type);
    switch (category) {
      case 'arquitectura':
        return Icons.account_balance;
      case 'arqueologia':
        return Icons.museum;
      case 'natural':
        return Icons.park;
      case 'cultural':
        return Icons.celebration;
      case 'documental':
        return Icons.library_books;
      case 'objectes':
        return Icons.inventory;
      default:
        return Icons.place;
    }
  }

  Color _colorForType(String type) {
    final category = _getCategory(type);
    switch (category) {
      case 'arquitectura':
        return Colors.blueGrey;
      case 'arqueologia':
        return Colors.brown;
      case 'natural':
        return Colors.green;
      case 'cultural':
        return Colors.orange;
      case 'documental':
        return Colors.teal;
      case 'objectes':
        return Colors.indigo;
      default:
        return Colors.red;
    }
  }

  String _prettyType(String type) {
    final t = type.toLowerCase();
    if (t == 'conjunt arquitectònic') return 'Conjunt arquitectònic';
    if (t == 'edifici') return 'Edifici';
    if (t == 'element arquitectònic') return 'Element arquitectònic';
    if (t == 'element urbà') return 'Element urbà';
    if (t == 'obra civil') return 'Obra civil';
    if (t == 'jaciment arqueològic') return 'Jaciment arqueològic';
    if (t == 'jaciment paleontològic') return 'Jaciment paleontològic';
    if (t == 'espècimen botànic') return 'Espècimen botànic';
    if (t == 'zona d\'interès') return 'Zona d\'interès';
    if (t == 'costumari') return 'Costumari';
    if (t == 'manifestació festiva') return 'Manifestació festiva';
    if (t == 'música i dansa') return 'Música i dansa';
    if (t == 'tradició oral') return 'Tradició oral';
    if (t == 'tècnica artesanal') return 'Tècnica artesanal';
    if (t == 'fons bibliogràfic') return 'Fons bibliogràfic';
    if (t == 'fons d\'imatges') return 'Fons d\'imatges';
    if (t == 'fons documental') return 'Fons documental';
    if (t == 'col·lecció') return 'Col·lecció';
    if (t == 'objecte') return 'Objecte';
    return 'Altres';
  }

  String _shortText(String text, {int max = 260}) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max)}…';
  }

  String _normalizeStepName(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'[\(\)]'), '');
    if (clean.isEmpty) return clean;

    final lower = clean.toLowerCase();
    const map = {
      'camino': 'Camí',
      'camí': 'Camí',
    };

    return map[lower] ?? clean;
  }

  UserPreferencesModel _prefsFromApi(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const UserPreferencesModel(
        prefId: 0,
        userId: 0,
        preferredDistance: 10,
        environmentType: 'mixt',
        culturalInterest: 'mitja',
        updatedAt: null,
      );
    }
    return UserPreferencesModel.fromJson(data);
  }

  Future<_NearRoutesData> _loadNearRoutesData(CulturalItem item) async {
    final routes = await _routesService.getRoutesNearCulturalItem(
      item.id,
      limit: 5,
      radiusM: _radiusM,
    );

    if (routes.isEmpty) {
      return _NearRoutesData(routes: routes, recommendedRouteId: null);
    }

    try {
      final prefsMap = await _prefsService.getPreferences();
      final prefs = _prefsFromApi(prefsMap);
      final ranked = _recoService.rankRoutes(
        routes: routes.map((e) => e.route).toList(),
        prefs: prefs,
      );
      final recommendedId = ranked.isEmpty ? null : ranked.first.routeId;
      return _NearRoutesData(routes: routes, recommendedRouteId: recommendedId);
    } catch (_) {
      return _NearRoutesData(routes: routes, recommendedRouteId: null);
    }
  }

  String _formatDistanceM(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  List<CulturalItem> _visibleCulturalItems() {
    return _nearItems
        .where((item) =>
            _walkingTrack.isEmpty ||
            _currentDestination == null ||
            item.id == _currentDestination!.id)
        .toList();
  }

  Offset? _toWorldPixel(LatLng point, double zoom) {
    if (!point.latitude.isFinite || !point.longitude.isFinite || !zoom.isFinite) {
      return null;
    }
    if (point.latitude < -90 || point.latitude > 90 || point.longitude < -180 || point.longitude > 180) {
      return null;
    }

    final safeZoom = zoom.clamp(1.0, 20.0);
    final scale = 256.0 * pow(2.0, safeZoom).toDouble();
    final x = (point.longitude + 180.0) / 360.0 * scale;
    final sinLat = sin(point.latitude * pi / 180.0).clamp(-0.9999, 0.9999);
    final y = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi)) * scale;
    if (!x.isFinite || !y.isFinite) return null;
    return Offset(x, y);
  }

  List<_ClusterCategory> _clusterCategories(_CulturalCluster cluster) {
    final byCategory = <String, List<CulturalItem>>{};
    for (final item in cluster.items) {
      final category = _getCategory(item.type);
      byCategory.putIfAbsent(category, () => <CulturalItem>[]).add(item);
    }

    final out = byCategory.entries
        .map((e) => _ClusterCategory(
              category: e.key,
              count: e.value.length,
              sampleType: e.value.first.type,
            ))
        .toList();

    out.sort((a, b) {
      final countCmp = b.count.compareTo(a.count);
      if (countCmp != 0) return countCmp;
      return a.category.compareTo(b.category);
    });
    return out;
  }

  List<_CulturalCluster> _buildCulturalClusters(List<CulturalItem> items) {
    if (items.isEmpty) return const [];

    final rawZoom = _mapController.camera.zoom.isFinite ? _mapController.camera.zoom : 12.0;
    final zoom = (rawZoom * 2).floorToDouble() / 2.0;

    // At close zoom levels, stop clustering so user can tap each cultural point.
    if (zoom >= 16.0) {
      return items
        .where((item) => item.latitude.isFinite && item.longitude.isFinite)
        .map((item) => _CulturalCluster(
          items: [item],
          center: LatLng(item.latitude, item.longitude),
          ))
        .toList();
    }

    final cellSizePx = zoom < 9
        ? 150.0
        : zoom < 11
            ? 130.0
            : zoom < 13
                ? 110.0
                : zoom < 15
                    ? 92.0
            : zoom < 15.5
              ? 72.0
              : 60.0;
    if (!cellSizePx.isFinite || cellSizePx <= 0) {
      return items
          .where((item) => item.latitude.isFinite && item.longitude.isFinite)
          .map((item) => _CulturalCluster(
                items: [item],
                center: LatLng(item.latitude, item.longitude),
              ))
          .toList();
    }

    final grouped = <String, List<CulturalItem>>{};
    for (final item in items) {
      if (!item.latitude.isFinite || !item.longitude.isFinite) {
        continue;
      }
      final pixel = _toWorldPixel(LatLng(item.latitude, item.longitude), zoom);
      if (pixel == null) continue;
      final px = pixel.dx / cellSizePx;
      final py = pixel.dy / cellSizePx;
      if (!px.isFinite || !py.isFinite) continue;
      final cellX = px.floor();
      final cellY = py.floor();
      final key = '$cellX:$cellY';
      grouped.putIfAbsent(key, () => <CulturalItem>[]).add(item);
    }

    final clusters = <_CulturalCluster>[];
    for (final clusterItems in grouped.values) {
      var latSum = 0.0;
      var lonSum = 0.0;
      for (final item in clusterItems) {
        latSum += item.latitude;
        lonSum += item.longitude;
      }
      final center = LatLng(latSum / clusterItems.length, lonSum / clusterItems.length);
      clusters.add(_CulturalCluster(items: clusterItems, center: center));
    }

    return clusters;
  }

  void _zoomToCluster(_CulturalCluster cluster) {
    if (cluster.items.isEmpty) return;
    if (cluster.items.length == 1) {
      _showCulturalItem(cluster.items.first);
      return;
    }

    final points = cluster.items
        .where((e) => e.latitude.isFinite && e.longitude.isFinite)
        .map((e) => LatLng(e.latitude, e.longitude))
        .toList();

    if (points.isEmpty) return;

    if (points.length < 2) {
      _mapController.move(points.first, (_mapController.camera.zoom + 2).clamp(1.0, 18.0));
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    final latSpan = (maxLat - minLat).abs();
    final lonSpan = (maxLon - minLon).abs();
    final tooSmallBounds =
        !latSpan.isFinite ||
        !lonSpan.isFinite ||
        (latSpan < 0.00003 && lonSpan < 0.00003); // ~3m

    if (tooSmallBounds) {
      final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
      // Ensure we reach a zoom level where clusters are split.
      final targetZoom = max(_mapController.camera.zoom + 1.8, 16.2).clamp(1.0, 18.0);
      _mapController.move(center, targetZoom);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  List<Marker> _buildCulturalMarkers() {
    final items = _visibleCulturalItems();
    final clusters = _buildCulturalClusters(items);

    return clusters.map((cluster) {
      final categories = _clusterCategories(cluster);
      final isSingle = cluster.items.length == 1 && categories.length == 1;
      final markerWidthRaw = isSingle ? 50.0 : (categories.length * 34.0 + 18.0).clamp(72.0, 240.0);
      final markerWidth = markerWidthRaw.isFinite ? markerWidthRaw : 72.0;
      final markerHeight = 54.0;

      return Marker(
        point: cluster.center,
        width: markerWidth,
        height: markerHeight,
        child: GestureDetector(
          onTap: () => _zoomToCluster(cluster),
          child: isSingle
              ? Icon(
                  _iconForType(categories.first.sampleType),
                  color: _colorForType(categories.first.sampleType),
                  size: 36,
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(175),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade100),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: categories.map((cat) {
                      final color = _colorForType(cat.sampleType);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              _iconForType(cat.sampleType),
                              color: color,
                              size: 24,
                            ),
                            Positioned(
                              top: -7,
                              right: -9,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 18),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: color, width: 1.4),
                                ),
                                child: Text(
                                  '${cat.count}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
      );
    }).toList();
  }

  Widget _buildNearRouteTile(
    RouteNearItem item, {
    bool isRecommended = false,
    VoidCallback? onRouteStart,
  }) {
    final route = item.route;
    final distanceText = item.distanceM != null ? _formatDistanceM(item.distanceM!) : null;

    final trailingWidgets = <Widget>[];
    trailingWidgets.add(
      Tooltip(
        message: route.completedByUser ? 'Ruta completada' : 'Ruta no completada',
        child: Icon(
          route.completedByUser ? Icons.check_circle : Icons.radio_button_unchecked,
          color: route.completedByUser ? Colors.green[700] : Colors.grey[600],
          size: 18,
        ),
      ),
    );
    if (distanceText != null) {
      trailingWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange[600],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            distanceText,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    if (onRouteStart != null) {
      trailingWidgets.add(
        IconButton(
          tooltip: 'Anar a l\'inici',
          onPressed: _routingLoading ? null : onRouteStart,
          icon: const Icon(Icons.directions_walk, color: Colors.blue, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    final tile = ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        route.name,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isRecommended ? Colors.orange[900] : Colors.green[900],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${route.distanceKm.toStringAsFixed(1)} km · ${route.difficulty} · ${route.location}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailingWidgets.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < trailingWidgets.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  trailingWidgets[i],
                ],
              ],
            ),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RouteDetailScreen(route: route),
          ),
        );
      },
    );

    if (!isRecommended) return tile;

    return Card(
      elevation: 3,
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: tile,
      ),
    );
  }

  Widget _navMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool selected = false,
  }) {
    return SizedBox(
      width: 170,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          elevation: 2,
          backgroundColor: selected ? Colors.green[700] : Colors.white,
          foregroundColor: selected ? Colors.white : Colors.green[800],
          side: BorderSide(color: Colors.green.shade200),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _centerCameraOnce() async {
    LatLng? point = _currentPosition;
    if (point == null) {
      try {
        final pos = await _locationService.getCurrentPosition();
        point = LatLng(pos.latitude, pos.longitude);
        if (!mounted) return;
        setState(() {
          _currentPosition = point;
        });
      } catch (_) {
        return;
      }
    }

    final zoom = _mapController.camera.zoom;
    final targetZoom = zoom.isFinite ? max(zoom, 16.2).clamp(1.0, 18.0) : 16.2;
    _mapController.move(point, targetZoom);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  double _calculatePixelRadius(double meters) {
    if (_currentPosition == null) return 0;
    if (!meters.isFinite || meters <= 0) return 0;
    final zoom = _mapController.camera.zoom;
    if (!zoom.isFinite) return 0;
    final lat = _currentPosition!.latitude;
    if (!lat.isFinite) return 0;
    final metersPerPixel = 156543.0339 * cos(lat * pi / 180) / pow(2, zoom);
    if (!metersPerPixel.isFinite || metersPerPixel <= 0) return 0;
    return meters / metersPerPixel;
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * pi / 180.0;
    final dLon = (b.longitude - a.longitude) * pi / 180.0;
    final lat1 = a.latitude * pi / 180.0;
    final lat2 = b.latitude * pi / 180.0;

    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return r * c;
  }

  double _trackDistanceKm(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _haversineKm(points[i - 1], points[i]);
    }
    return total;
  }

  List<LatLng> _downsamplePoints(List<LatLng> points, {int maxPoints = 1200}) {
    if (maxPoints <= 1 || points.length <= maxPoints) return points;
    final step = (points.length / maxPoints).ceil();
    final sampled = <LatLng>[];
    for (var i = 0; i < points.length; i += step) {
      sampled.add(points[i]);
    }
    if (sampled.isEmpty || sampled.last != points.last) {
      sampled.add(points.last);
    }
    return sampled;
  }

  Future<List<LatLng>> _getRouteTrackPoints(int routeId) async {
    final cached = _routeTrackCache[routeId];
    if (cached != null && cached.isNotEmpty) return cached;

    final files = await _routeFilesService.listFiles(routeId);
    if (files.isEmpty) {
      throw Exception('Aquesta ruta no té cap GPX');
    }

    String? gpxUrl;
    for (final f in files) {
      final type = (f['file_type'] ?? '').toString().toUpperCase();
      if (type == 'GPX') {
        gpxUrl = f['file_url']?.toString();
        break;
      }
    }
    gpxUrl ??= files.first['file_url']?.toString();
    if (gpxUrl == null || gpxUrl.isEmpty) {
      throw Exception('No s\'ha trobat cap GPX');
    }

    final gpx = await _downloadService.download(gpxUrl);
    final points = await _pointsParser.parsePointsAsync(gpx, maxPoints: 2500);
    if (points.length < 2) {
      throw Exception('GPX sense punts suficients');
    }

    _routeTrackCache[routeId] = points;
    _routeTrackCacheOrder.remove(routeId);
    _routeTrackCacheOrder.add(routeId);
    if (_routeTrackCacheOrder.length > 5) {
      final toRemove = _routeTrackCacheOrder.removeAt(0);
      _routeTrackCache.remove(toRemove);
    }

    return points;
  }

  void _adjustZoomForRadius() {
    if (_currentPosition == null) return;
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final diameterMeters = 2 * _radiusM * 1.2; // 20% margin
    final desiredMetersPerPixel = diameterMeters / screenWidth;
    final lat = _currentPosition!.latitude;
    final zoom = log(156543.0339 * cos(lat * pi / 180) / desiredMetersPerPixel) / log(2);
    _mapController.move(_currentPosition!, zoom.clamp(1.0, 18.0));
  }

  Future<void> _routeToPoi(CulturalItem item) async {
    setState(() {
      _routingLoading = true;
      _routingError = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calculant ruta...')),
      );
    }

    try {
      final pos = await _locationService.getCurrentPosition();

      final result = await _routingService.walkingRoute(
        startLat: pos.latitude,
        startLon: pos.longitude,
        endLat: item.latitude,
        endLon: item.longitude,
      );

      final pts = _downsamplePoints(
        result.polyline.map((p) => LatLng(p[0], p[1])).toList(),
        maxPoints: 1000,
      );

      setState(() {
        _walkingTrack = pts;
        _walkingDistanceKm = result.distanceKm;
        _walkingDurationMin = ((result.distanceKm / 4.5) * 60).round();
        _currentDestination = item;
        _currentRouteStartDestination = null;
        _activeNavigationRouteId = null;
        _routeStartReachedNotified = false;
        _walkingSteps = result.steps
            .where((s) => s.toLowerCase() != 'altres')
            .map(_normalizeStepName)
            .where((s) => s.isNotEmpty)
            .toList();
      });

      // Opcional: encuadrar la ruta en pantalla
      if (pts.length >= 2) {
        final bounds = LatLngBounds.fromPoints(pts);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
        );
      }

      await _startNavigation(pts);
    } catch (e) {
      setState(() {
        _routingError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _routingLoading = false);
    }
  }

  Future<void> _routeToRouteStart(RouteNearItem item) async {
    if (!mounted) return;
    setState(() {
      _routingLoading = true;
      _routingError = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calculant ruta...')),
    );

    try {
      final pos = await _locationService.getCurrentPosition();
      final track = await _getRouteTrackPoints(item.route.routeId);

      final start = track.first;
      final walking = await _routingService.walkingRoute(
        startLat: pos.latitude,
        startLon: pos.longitude,
        endLat: start.latitude,
        endLon: start.longitude,
      );

      final walkingPts = _downsamplePoints(
        walking.polyline.map((p) => LatLng(p[0], p[1])).toList(),
        maxPoints: 1000,
      );

      final routeDistanceKm = _trackDistanceKm(track);
      final totalDistanceKm = walking.distanceKm + routeDistanceKm;
      final totalDurationMin = walking.durationMin + ((routeDistanceKm / 4.5) * 60).round();

      if (!mounted) return;
      setState(() {
        _track = track;
        _walkingTrack = walkingPts;
        _walkingDistanceKm = totalDistanceKm;
        _walkingDurationMin = totalDurationMin;
        _walkingSteps = walking.steps
            .where((s) => s.toLowerCase() != 'altres')
            .map(_normalizeStepName)
            .where((s) => s.isNotEmpty)
            .toList();
        _currentDestination = null;
        _currentRouteStartDestination = start;
        _activeNavigationRouteId = item.route.routeId;
        _routeStartReachedNotified = false;
      });

      final allPoints = <LatLng>[];
      allPoints.addAll(walkingPts);
      allPoints.addAll(track);
      if (allPoints.length >= 2) {
        final bounds = LatLngBounds.fromPoints(allPoints);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
        );
      }

      final navPath = <LatLng>[];
      navPath.addAll(walkingPts);
      navPath.addAll(track);
      await _startNavigation(navPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ruta total: ${totalDistanceKm.toStringAsFixed(2)} km · $totalDurationMin min',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _routingError = msg;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'Error calculant ruta' : msg)),
      );
    } finally {
      if (mounted) {
        setState(() => _routingLoading = false);
      }
    }
  }

  void _showCulturalItem(CulturalItem item) {
    final isRouteMode = widget.routeId != null;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.green[50]!, Colors.white],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = MediaQuery.of(context).size.height * 0.85;
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Card(
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
                          Row(
                            children: [
                              Icon(Icons.place, color: Colors.green[700], size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  _prettyType(item.type),
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                backgroundColor: Colors.green[600],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              if (item.period != null && item.period!.isNotEmpty)
                                Chip(
                                  label: Text(
                                    'Període: ${item.period}',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  backgroundColor: Colors.blue[600],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              if (item.distanceM != null)
                                Chip(
                                  label: Text(
                                    item.distanceM! >= 1000
                                        ? 'A ${(item.distanceM! / 1000).toStringAsFixed(1)} km'
                                        : 'A ${item.distanceM!.toStringAsFixed(0)} m',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  backgroundColor: Colors.orange[600],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Text(
                            _shortText(item.description),
                            style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                  if (!isRouteMode) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Rutes properes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.green[900]),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<_NearRoutesData>(
                      future: _loadNearRoutesData(item),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No s\'han pogut carregar les rutes properes', style: TextStyle(color: Colors.red)),
                          );
                        }

                        final data = snapshot.data ?? const _NearRoutesData(routes: [], recommendedRouteId: null);
                        final routes = data.routes;
                        final recommendedId = data.recommendedRouteId;
                        if (routes.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No hi ha rutes associades a aquest punt.'),
                          );
                        }

                        final recommendedItem = recommendedId == null
                            ? null
                            : routes.firstWhere(
                                (r) => r.route.routeId == recommendedId,
                                orElse: () => routes.first,
                              );

                        final others = recommendedItem == null
                            ? routes
                            : routes.where((r) => r.route.routeId != recommendedItem.route.routeId).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (recommendedItem != null) ...[
                              Row(
                                children: [
                                  Icon(Icons.star, color: Colors.orange[700]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Recomanada per tu',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildNearRouteTile(
                                recommendedItem,
                                isRecommended: true,
                                onRouteStart: () {
                                  Navigator.pop(context);
                                  Future.microtask(() => _routeToRouteStart(recommendedItem));
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (others.isNotEmpty) ...[
                              Text(
                                recommendedItem == null ? 'Rutes properes' : 'Altres rutes properes',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.green[900]),
                              ),
                              const SizedBox(height: 6),
                              ...others.map((r) => Column(
                                    children: [
                                      _buildNearRouteTile(
                                        r,
                                        onRouteStart: () {
                                          Navigator.pop(context);
                                          Future.microtask(() => _routeToRouteStart(r));
                                        },
                                      ),
                                      const Divider(height: 1),
                                    ],
                                  )),
                            ],
                          ],
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Container(
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
                          onPressed: (item.sourceUrl != null && item.sourceUrl!.isNotEmpty)
                              ? () => _openUrl(item.sourceUrl!)
                              : null,
                          icon: const Icon(Icons.open_in_new, color: Colors.white),
                          label: const Text(
                            'Fitxa oficial',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _routingLoading ? null : () async {
                        Navigator.pop(context); // cerrar sheet
                        await _routeToPoi(item);
                      },
                      icon: const Icon(Icons.directions_walk, color: Colors.white),
                      label: const Text(
                        'Ruta fins aquí',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green[700],
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Tancar'),
                    ),
                  ],
                ),

                if (_routingError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_routingError!, style: const TextStyle(color: Colors.red, fontSize: 16)),
                  ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRouteMode = widget.routeId != null;

    final polylines = _track.isEmpty
        ? <Polyline>[]
        : [
            Polyline(
              points: _track,
              strokeWidth: 4.0,
              color: Colors.green,
            ),
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(isRouteMode ? 'Mapa de la ruta' : 'Mapa cultural'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 4,
        actions: _navigationMode
            ? const []
            : [
                if (!isRouteMode)
                  PopupMenuButton<int>(
                    tooltip: 'Radi de cerca',
                    onSelected: (v) {
                      setState(() => _radiusM = v);
                      _adjustZoomForRadius();
                      _reloadNearItems();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 500, child: Text('500 m', style: TextStyle(fontSize: 16))),
                      PopupMenuItem(value: 1000, child: Text('1 km', style: TextStyle(fontSize: 16))),
                      PopupMenuItem(value: 2000, child: Text('2 km', style: TextStyle(fontSize: 16))),
                      PopupMenuItem(value: 3000, child: Text('3 km', style: TextStyle(fontSize: 16))),
                      PopupMenuItem(value: 5000, child: Text('5 km', style: TextStyle(fontSize: 16))),
                      PopupMenuItem(value: 10000, child: Text('10 km', style: TextStyle(fontSize: 16))),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.green[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _radiusM >= 1000 ? '${(_radiusM / 1000).toInt()} km' : '$_radiusM m',
                        style: TextStyle(color: Colors.green[800], fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: isRouteMode ? 'Recalcular punts' : 'Recarregar (prop)',
                  icon: Icon(isRouteMode ? Icons.refresh : Icons.my_location, color: Colors.white),
                  onPressed: isRouteMode ? _recomputeRouteCulturalItems : _loadNearMe,
                ),
              ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[50]!, Colors.white],
          ),
        ),
        child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/${MapConfig.mapboxStyleId}/tiles/256/{z}/{x}/{y}@2x?access_token=${MapConfig.mapboxAccessToken}',
                userAgentPackageName: 'com.example.app',
              ),

              if (_track.isNotEmpty) PolylineLayer(polylines: polylines),

              if (_walkingTrack.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _walkingTrack,
                      strokeWidth: 5,
                      color: Colors.blue,
                    ),
                  ],
                ),

              if (_navigationCompletedPath.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _navigationCompletedPath,
                      strokeWidth: 7,
                      color: Colors.orange,
                    ),
                  ],
                ),

              // markers inicio/fin si hay track
              if (_track.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _track.first,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.flag, color: Colors.green),
                    ),
                    Marker(
                      point: _track.last,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.flag_outlined, color: Colors.red),
                    ),
                  ],
                ),

              // markers culturales
              if (_nearItems.isNotEmpty)
                MarkerLayer(markers: _buildCulturalMarkers()),

              // marker ubicación actual
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 40,
                      height: 40,
                      child: _navigationMode
                          ? Transform.rotate(
                              angle: _currentHeadingDeg * pi / 180,
                              child: const Icon(Icons.navigation, color: Colors.blue, size: 30),
                            )
                          : const Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ],
                ),

              // círculo de radio
              if (_currentPosition != null && !_navigationMode)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _currentPosition!,
                      radius: _calculatePixelRadius(_radiusM.toDouble()),
                      color: Colors.blue.withAlpha(51),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
            ],
          ),

          if (_loading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(),
            ),

          if (_error != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),

          if (_walkingDistanceKm != null && _walkingDurationMin != null)
            Positioned(
              left: 12,
              right: 70,
              top: 12,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withAlpha(206), Colors.white.withAlpha(170)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withAlpha(165)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentDestination != null
                            ? 'Navegació fins al punt cultural'
                            : (_currentRouteStartDestination != null
                                ? 'Navegació fins a l\'inici de ruta'
                                : 'Ruta en curs'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[800],
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_walkingDistanceKm!.toStringAsFixed(2)} km · ${_walkingDurationMin!} min',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      if (_navigationMode && _remainingDistanceKm != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Restant: ${_remainingDistanceKm!.toStringAsFixed(2)} km',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_navigationMode && _distanceToPathM != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Desviació: ${_distanceToPathM!.toStringAsFixed(0)} m',
                          style: TextStyle(
                            fontSize: 12,
                            color: (_distanceToPathM ?? 0) > 50 ? Colors.red[700] : Colors.green[700],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (_navigationMode && _autoRecalculatingRoute) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Recalculant...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (_walkingSteps.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Vies: ${_walkingSteps.join(", ")}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          if (_walkingDistanceKm != null && _walkingDurationMin != null)
            Positioned(
              right: 12,
              bottom: 88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: !_navActionsExpanded
                        ? const SizedBox.shrink()
                        : Container(
                            key: const ValueKey('nav-menu-open'),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(238),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.green.shade100),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _navMenuItem(
                                  icon: Icons.center_focus_strong,
                                  label: 'Centrar càmera',
                                  selected: false,
                                  onTap: () async {
                                    setState(() => _navActionsExpanded = false);
                                    await _centerCameraOnce();
                                  },
                                ),
                                const SizedBox(height: 6),
                                _navMenuItem(
                                  icon: Icons.cleaning_services,
                                  label: 'Finalitzar ruta',
                                  onTap: _autoFinishingRoute ? null : _finishNavigationFlow,
                                ),
                              ],
                            ),
                          ),
                  ),
                  FloatingActionButton.small(
                    heroTag: 'nav_actions_fab',
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    onPressed: () {
                      setState(() => _navActionsExpanded = !_navActionsExpanded);
                    },
                    child: Icon(_navActionsExpanded ? Icons.close : Icons.menu),
                  ),
                ],
              ),
            ),

          if (isRouteMode && !_loading && _nearItems.isEmpty && _error == null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Sense punts culturals per aquest radi',
                    style: TextStyle(color: Colors.green[800], fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),

          // contador simple
          if (_nearItems.isNotEmpty && !_navigationMode)
            Positioned(
              left: 12,
              bottom: 12,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    '${_nearItems.length} punts',
                    style: TextStyle(color: Colors.green[800], fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  Future<void> _reloadNearItems() async {
    if (_currentPosition == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _nearItems = const [];
    });

    try {
      final items = await _culturalNearService.near(
        lat: _currentPosition!.latitude,
        lon: _currentPosition!.longitude,
        radius: _radiusM,
      );

      setState(() {
        _nearItems = items;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _loading = false);
    }
  }
}

class _NearRoutesData {
  final List<RouteNearItem> routes;
  final int? recommendedRouteId;

  const _NearRoutesData({
    required this.routes,
    required this.recommendedRouteId,
  });
}

class _CulturalCluster {
  final List<CulturalItem> items;
  final LatLng center;

  const _CulturalCluster({
    required this.items,
    required this.center,
  });
}

class _ClusterCategory {
  final String category;
  final int count;
  final String sampleType;

  const _ClusterCategory({
    required this.category,
    required this.count,
    required this.sampleType,
  });
}
