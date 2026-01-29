import 'package:flutter/material.dart';

import '../services/user_preferences_service.dart';

class UserPreferencesScreen extends StatefulWidget {
  const UserPreferencesScreen({super.key});

  @override
  State<UserPreferencesScreen> createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends State<UserPreferencesScreen> {
  final _prefs = UserPreferencesService();

  int _step = 0;
  bool _loading = false;
  String? _error;

  String _sportFrequency = 'Algunes vegades al mes';
  String _outingDuration = '1-2 hores';
  String _environmentType = 'Mixt';
  String _routeMotivation = 'Paisatge i natura';
  String _cultureFocus = 'Em resulta indiferent';
  String _elevation = 'Algunes pujades';

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final data = await _prefs.getPreferences();
      if (data.isEmpty) return;

      final fitness = (data['fitness_level'] ?? '').toString().toLowerCase();
      final dist = (data['preferred_distance'] as num?)?.toDouble() ?? 10;
      final env = (data['environment_type'] ?? 'mixt').toString();
      final cult = (data['cultural_interest'] ?? '').toString().toLowerCase();

      setState(() {
        _sportFrequency = _frequencyFromFitness(fitness);
        _outingDuration = _durationFromDistance(dist);
        _environmentType = _capitalize(env);
        _routeMotivation = cult.contains('alt')
            ? 'Descobrir cultura i història'
            : 'Paisatge i natura';
        _cultureFocus = cult.contains('alt')
            ? 'Molt important'
            : cult.contains('mitj')
                ? 'M’agrada si és una part de la ruta'
                : 'Em resulta indiferent';
        _elevation = 'Algunes pujades';
      });
    } catch (_) {
      // ignore load errors silently
    }
  }

  String _capitalize(String v) {
    if (v.isEmpty) return v;
    return v[0].toUpperCase() + v.substring(1);
  }

  String _frequencyFromFitness(String fitness) {
    if (fitness.contains('alta')) return '3+ cops per setmana';
    if (fitness.contains('baixa')) return 'Un cop al mes o menys';
    return '1-2 cops per setmana';
  }

  String _durationFromDistance(double d) {
    if (d <= 6) return '30-60 minuts';
    if (d <= 12) return '1-2 hores';
    if (d <= 20) return '2-4 hores';
    return 'Més de 4 hores';
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final derived = _derivePreferences();
      await _prefs.upsertPreferences(
        fitnessLevel: derived['fitness_level'] as String,
        preferredDistance: derived['preferred_distance'] as double,
        environmentType: derived['environment_type'] as String,
        culturalInterest: derived['cultural_interest'] as String,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferències guardades')),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _answerAndNext(String value) {
    final question = _questions[_step];
    switch (question.id) {
      case 'frequency':
        _sportFrequency = value;
        break;
      case 'duration':
        _outingDuration = value;
        break;
      case 'environment':
        _environmentType = value;
        break;
      case 'motivation':
        _routeMotivation = value;
        break;
      case 'culture_focus':
        _cultureFocus = value;
        break;
      case 'elevation':
        _elevation = value;
        break;
    }

    if (_step == _questions.length - 1) {
      _submit();
      return;
    }

    setState(() {
      _step += 1;
    });
  }

  void _goBack() {
    if (_step == 0) return;
    setState(() {
      _step -= 1;
    });
  }

  Map<String, Object> _derivePreferences() {
    final baseFitness = _fitnessFromFrequency(_sportFrequency);
    final baseDistance = _distanceFromDuration(_outingDuration);
    final fitnessLevel = _adjustFitnessForElevation(baseFitness, _elevation);
    final preferredDistance = _adjustDistanceForElevation(baseDistance, _elevation);
    final culturalInterest = _combineCulturalSignals(
      _culturalFromMotivation(_routeMotivation),
      _culturalFromFocus(_cultureFocus),
    );

    return {
      'fitness_level': fitnessLevel.toLowerCase(),
      'preferred_distance': preferredDistance,
      'environment_type': _environmentType.toLowerCase(),
      'cultural_interest': culturalInterest.toLowerCase(),
    };
  }

  String _fitnessFromFrequency(String value) {
    switch (value) {
      case 'Mai o gairebé mai':
      case 'Un cop al mes o menys':
        return 'Baixa';
      case 'Algunes vegades al mes':
      case '1-2 cops per setmana':
        return 'Mitjana';
      case '3+ cops per setmana':
      case 'Cada dia o gairebé cada dia':
        return 'Alta';
      default:
        return 'Mitjana';
    }
  }

  double _distanceFromDuration(String value) {
    switch (value) {
      case '30-60 minuts':
        return 5;
      case '1-2 hores':
        return 10;
      case '2-4 hores':
        return 18;
      case 'Més de 4 hores':
        return 25;
      default:
        return 10;
    }
  }

  String _culturalFromMotivation(String value) {
    switch (value) {
      case 'Descobrir cultura i història':
        return 'Alt';
      case 'Una mica de tot':
        return 'Mitjà';
      case 'Paisatge i natura':
      case 'Desconnectar i relaxar':
        return 'Baix';
      default:
        return 'Mitjà';
    }
  }

  String _culturalFromFocus(String value) {
    switch (value) {
      case 'Molt important':
        return 'Alt';
      case 'M’agrada si és una part de la ruta':
        return 'Mitjà';
      case 'Em resulta indiferent':
      default:
        return 'Baix';
    }
  }

  String _combineCulturalSignals(String a, String b) {
    const rank = {'baixa': 0, 'mitjana': 1, 'alta': 2};
    final ra = rank[a.toLowerCase()] ?? 1;
    final rb = rank[b.toLowerCase()] ?? 1;
    final r = (ra + rb) >= 3 ? 2 : (ra + rb) <= 1 ? 0 : 1;
    if (r == 2) return 'Alta';
    if (r == 0) return 'Baixa';
    return 'Mitjana';
  }

  String _adjustFitnessForElevation(String base, String elevation) {
    if (elevation == 'Prefereixo planer' && base == 'Alta') return 'Mitjana';
    if (elevation == 'No em fa res' && base == 'Baixa') return 'Mitjana';
    return base;
  }

  double _adjustDistanceForElevation(double base, String elevation) {
    if (elevation == 'Prefereixo planer') return (base - 2).clamp(5, 30);
    if (elevation == 'No em fa res') return (base + 2).clamp(5, 30);
    return base;
  }

  List<_Question> get _questions => const [
        _Question(
          id: 'frequency',
          title: 'Amb quina freqüència fas activitat física?',
          icon: Icons.fitness_center,
          options: [
            'Mai o gairebé mai',
            'Un cop al mes o menys',
            'Algunes vegades al mes',
            '1-2 cops per setmana',
            '3+ cops per setmana',
            'Cada dia o gairebé cada dia',
          ],
        ),
        _Question(
          id: 'duration',
          title: 'Quanta estona t’agrada passar caminant?',
          icon: Icons.timer,
          options: [
            '30-60 minuts',
            '1-2 hores',
            '2-4 hores',
            'Més de 4 hores',
          ],
        ),
        _Question(
          id: 'environment',
          title: 'Quin entorn t’atrau més?',
          icon: Icons.landscape,
          options: [
            'Muntanya',
            'Costa',
            'Bosc',
            'Urbà',
            'Mixt',
          ],
        ),
        _Question(
          id: 'motivation',
          title: 'Què busques principalment en una ruta?',
          icon: Icons.explore,
          options: [
            'Paisatge i natura',
            'Descobrir cultura i història',
            'Desconnectar i relaxar',
            'Una mica de tot',
          ],
        ),
        _Question(
          id: 'culture_focus',
          title: 'Quan una ruta té elements culturals, per a tu és…',
          icon: Icons.museum,
          options: [
            'Molt important',
            'M’agrada si és una part de la ruta',
            'Em resulta indiferent',
          ],
        ),
        _Question(
          id: 'elevation',
          title: 'Com et sents amb els desnivells?',
          icon: Icons.terrain,
          options: [
            'Prefereixo planer',
            'Algunes pujades',
            'No em fa res',
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferències de ruta'),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Icon(Icons.tune, size: 70, color: Colors.green[700]),
                const SizedBox(height: 12),
                Text(
                  'Actualitza les teves preferències',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Aquestes respostes es poden modificar sempre que vulguis.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (_step > 0)
                      IconButton(
                        onPressed: _loading ? null : _goBack,
                        icon: const Icon(Icons.arrow_back),
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        'Pregunta ${_step + 1} de ${_questions.length}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      child: const Text('Tancar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.green[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        ),
                        child: _QuestionCard(
                          key: ValueKey(_step),
                          question: _questions[_step],
                          onSelect: _loading ? null : _answerAndNext,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Question {
  final String id;
  final String title;
  final IconData icon;
  final List<String> options;

  const _Question({
    required this.id,
    required this.title,
    required this.icon,
    required this.options,
  });
}

class _QuestionCard extends StatelessWidget {
  final _Question question;
  final void Function(String value)? onSelect;

  const _QuestionCard({
    super.key,
    required this.question,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(question.icon, size: 56, color: Colors.green[700]),
        const SizedBox(height: 12),
        Text(
          question.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.green[800],
          ),
        ),
        const SizedBox(height: 16),
        ...question.options.map(
          (opt) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              height: 48,
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
                      color: Colors.green.withAlpha(51),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: onSelect == null ? null : () => onSelect!(opt),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    opt,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
