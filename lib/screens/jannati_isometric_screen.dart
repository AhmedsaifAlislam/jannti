import 'dart:math';

import 'package:flutter/material.dart';

import '../models/reward.dart';
import '../models/reward_type.dart';
import '../services/spiritual_audio_service.dart';
import '../services/storage_service.dart';
import '../utils/garden_assets.dart';
import '../utils/number_formatter.dart';
import 'jannati_3d_screen.dart';

enum TileType { grass, water, sand, plateau, bridge }

class _TileInfo {
  final TileType type;
  final double elevation;
  bool isOccupied;

  _TileInfo({
    required this.type,
    this.elevation = 0.0,
  }) : isOccupied = false;
}

class _IsometricBuilding {
  final RewardType type;
  final int gx;
  final int gy;
  final int sizeW; // 1 or 2
  final int sizeH; // 1 or 2
  final double elevation;
  final String assetPath;
  final int tier;
  final int bornAt;
  final Reward? sourceReward;

  _IsometricBuilding({
    required this.type,
    required this.gx,
    required this.gy,
    required this.sizeW,
    required this.sizeH,
    required this.elevation,
    required this.assetPath,
    this.tier = 1,
    required this.bornAt,
    this.sourceReward,
  });

  double get depth => (gx + sizeW * 0.5) + (gy + sizeH * 0.5) + elevation * 0.1;
}

class JannatiIsometricScreen extends StatefulWidget {
  const JannatiIsometricScreen({super.key});

  @override
  State<JannatiIsometricScreen> createState() => _JannatiIsometricScreenState();
}

class _JannatiIsometricScreenState extends State<JannatiIsometricScreen>
    with TickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final TransformationController _transController = TransformationController();

  late AnimationController _waveController;
  late AnimationController _particleController;

  // 📐 Expanded 28x28 Clash-of-Clans Matrix Grid
  static const int _gridSize = 28;
  static const double _canvasW = 3200.0;
  static const double _canvasH = 2200.0;
  static const double _tileW = 84.0;
  static const double _tileH = 42.0;
  static const double _originX = 1600.0;
  static const double _originY = 220.0;

  late List<List<_TileInfo>> _grid;
  final List<_IsometricBuilding> _buildings = [];
  RewardType? _selectedFilter;
  bool _soundEnabled = false;
  final Random _rng = Random(42);

  // Floating Atmospheric Particles
  final List<_Particle> _particles = [];
  final List<_Petal> _petals = [];

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _initGrid();
    _initParticles();
    _loadItemsFromStorage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerView();
    });
  }

  void _initGrid() {
    _grid = List.generate(_gridSize, (x) {
      return List.generate(_gridSize, (y) {
        // 1. High East Plateau (x >= 18 && y <= 10)
        if (x >= 18 && y <= 10) {
          return _TileInfo(type: TileType.plateau, elevation: 1.25);
        }

        // 2. Marble Bridge over River (at x: 13, 14 & y: 13, 14)
        if ((x == 13 || x == 14) && (y == 13 || y == 14)) {
          return _TileInfo(type: TileType.bridge, elevation: 0.35);
        }

        // 3. Diagonal River Bed (flowing along x - y ≈ 0)
        final riverCenter = x - y;
        if (riverCenter.abs() <= 1) {
          return _TileInfo(type: TileType.water, elevation: -0.2);
        }

        // 4. Sand Shorelines flanking the river
        if (riverCenter.abs() == 2) {
          return _TileInfo(type: TileType.sand, elevation: 0.0);
        }

        // 5. Default Emerald Grass
        return _TileInfo(type: TileType.grass, elevation: 0.0);
      });
    });
  }

  void _initParticles() {
    for (int i = 0; i < 48; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble() * _canvasW,
        y: _rng.nextDouble() * _canvasH,
        radius: 1.5 + _rng.nextDouble() * 2.5,
        speed: 0.3 + _rng.nextDouble() * 0.7,
        phase: _rng.nextDouble() * pi * 2,
      ));
    }

    for (int i = 0; i < 32; i++) {
      _petals.add(_Petal(
        x: _rng.nextDouble() * _canvasW,
        y: _rng.nextDouble() * _canvasH,
        size: 8.0 + _rng.nextDouble() * 8.0,
        speedX: 0.8 + _rng.nextDouble() * 1.2,
        speedY: 0.4 + _rng.nextDouble() * 0.6,
        rotation: _rng.nextDouble() * pi * 2,
        color: i % 2 == 0 ? const Color(0xFFF8BBD0) : const Color(0xFFFFD54F),
      ));
    }
  }

  void _centerView() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final scale = (size.width / 1400.0).clamp(0.60, 1.2);
    final tx = (size.width - _canvasW * scale) / 2;
    final ty = (size.height - _canvasH * scale) / 2 + 60;

    _transController.value = Matrix4.diagonal3Values(scale, scale, 1.0)
      ..setTranslationRaw(tx, ty, 0);
  }

  int _calculateTier(int count) {
    if (count >= 10000) return 5;
    if (count >= 2000) return 4;
    if (count >= 500) return 3;
    if (count >= 100) return 2;
    return 1;
  }

  // Sizing: House, Mosque, Palace = 2x2. Tree, Palm, Treasure = 1x1.
  int _getItemFootprint(RewardType type) {
    switch (type) {
      case RewardType.house:
      case RewardType.mosque:
      case RewardType.palace:
        return 2; // 2x2 tiles
      case RewardType.palmTree:
      case RewardType.tree:
      case RewardType.treasure:
        return 1; // 1x1 tile
    }
  }

  double _getSpriteVisualSize(RewardType type) {
    switch (type) {
      case RewardType.treasure:
        return 72.0; // Smallest & delicate
      case RewardType.palmTree:
      case RewardType.tree:
        return 135.0; // Medium-large natural foliage
      case RewardType.house:
        return 175.0; // Large 2x2 villa
      case RewardType.mosque:
      case RewardType.palace:
        return 220.0; // Equal to mosque! ("القصر يكون قد المسجد")
    }
  }

  bool _canPlaceAt(int gx, int gy, int footSize) {
    if (gx < 0 || gy < 0 || gx + footSize > _gridSize || gy + footSize > _gridSize) {
      return false;
    }

    for (int x = gx; x < gx + footSize; x++) {
      for (int y = gy; y < gy + footSize; y++) {
        final tile = _grid[x][y];
        // STRICT: Cannot place on water or bridge or already occupied tile!
        if (tile.type == TileType.water || tile.type == TileType.bridge || tile.isOccupied) {
          return false;
        }
      }
    }
    return true;
  }

  void _markOccupied(int gx, int gy, int footSize, bool occupied) {
    for (int x = gx; x < gx + footSize; x++) {
      for (int y = gy; y < gy + footSize; y++) {
        if (x < _gridSize && y < _gridSize) {
          _grid[x][y].isOccupied = occupied;
        }
      }
    }
  }

  Point<int>? _findFreeSpotFor(RewardType type) {
    final footSize = _getItemFootprint(type);

    List<Point<int>> candidateList = [];

    if (type == RewardType.palace || type == RewardType.mosque) {
      // 1. High East Plateau with generous 3-tile spacing
      for (int x = 18; x <= 24; x += 3) {
        for (int y = 2; y <= 8; y += 3) {
          candidateList.add(Point(x, y));
        }
      }
      // Fallback: East Bank
      for (int x = 16; x <= 24; x += 3) {
        for (int y = 6; y <= 22; y += 3) {
          candidateList.add(Point(x, y));
        }
      }
    } else if (type == RewardType.house) {
      // West residential meadow
      for (int x = 2; x <= 14; x += 3) {
        for (int y = 10; y <= 24; y += 3) {
          candidateList.add(Point(x, y));
        }
      }
    } else if (type == RewardType.palmTree) {
      // Along the sand shores
      for (int x = 0; x < _gridSize; x++) {
        for (int y = 0; y < _gridSize; y++) {
          if (_grid[x][y].type == TileType.sand || _grid[x][y].type == TileType.grass) {
            candidateList.add(Point(x, y));
          }
        }
      }
    } else {
      // Trees and treasures across all open grass
      for (int x = 0; x < _gridSize; x++) {
        for (int y = 0; y < _gridSize; y++) {
          if (_grid[x][y].type == TileType.grass) {
            candidateList.add(Point(x, y));
          }
        }
      }
    }

    candidateList.shuffle(_rng);

    for (final pt in candidateList) {
      if (_canPlaceAt(pt.x, pt.y, footSize)) {
        return pt;
      }
    }

    // Comprehensive fallback search across the full 28x28 grid
    for (int x = 0; x <= _gridSize - footSize; x++) {
      for (int y = 0; y <= _gridSize - footSize; y++) {
        if (_canPlaceAt(x, y, footSize)) {
          return Point(x, y);
        }
      }
    }
    return null;
  }

  void _loadItemsFromStorage() {
    final allRewards = _storage.getAllRewards();
    _buildings.clear();
    _initGrid();

    if (allRewards.isEmpty) {
      // Default starter village with generous spacing
      _tryPlaceBuilding(RewardType.mosque, tier: 1);
      _tryPlaceBuilding(RewardType.palace, tier: 1);
      _tryPlaceBuilding(RewardType.house, tier: 1);
      _tryPlaceBuilding(RewardType.palmTree, tier: 1);
      _tryPlaceBuilding(RewardType.palmTree, tier: 1);
      _tryPlaceBuilding(RewardType.tree, tier: 1);
      _tryPlaceBuilding(RewardType.tree, tier: 1);
      _tryPlaceBuilding(RewardType.treasure, tier: 1);
      return;
    }

    final byType = <RewardType, List<Reward>>{};
    for (final r in allRewards) {
      byType.putIfAbsent(r.type, () => []).add(r);
    }

    for (final type in RewardType.values) {
      final list = byType[type] ?? [];
      final count = list.length;
      if (count == 0) continue;
      final tier = _calculateTier(count);

      int displayCount = (count < 8) ? count : (8 + (count - 8) ~/ 25).clamp(1, 24);

      for (int i = 0; i < displayCount; i++) {
        final reward = i < list.length ? list[i] : list.last;
        _tryPlaceBuilding(type, tier: tier, source: reward);
      }
    }
  }

  bool _tryPlaceBuilding(RewardType type, {int tier = 1, Reward? source}) {
    final spot = _findFreeSpotFor(type);
    if (spot == null) return false;

    final footSize = _getItemFootprint(type);
    _markOccupied(spot.x, spot.y, footSize, true);

    final asset = GardenAssets.getRandomAsset(type, seed: spot.x * 100 + spot.y);
    final elev = _grid[spot.x][spot.y].elevation;

    _buildings.add(_IsometricBuilding(
      type: type,
      gx: spot.x,
      gy: spot.y,
      sizeW: footSize,
      sizeH: footSize,
      elevation: elev,
      assetPath: asset,
      tier: tier,
      bornAt: DateTime.now().millisecondsSinceEpoch,
      sourceReward: source,
    ));
    return true;
  }

  void _undoLast() {
    if (_buildings.isEmpty) return;
    final last = _buildings.removeLast();
    _markOccupied(last.gx, last.gy, last.sizeW, false);
    setState(() {});
  }

  static Offset gridToScreen(double gx, double gy, double elev) {
    final sx = _originX + (gx - gy) * (_tileW / 2);
    final sy = _originY + (gx + gy) * (_tileH / 2) - (elev * 26.0);
    return Offset(sx, sy);
  }

  void _showRewardSheet(_IsometricBuilding building) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2818).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Image.asset(
                    building.assetPath,
                    width: 54,
                    height: 54,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${building.type.displayName} في رياض الجنة',
                          style: const TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                        Text(
                          'مرتبة النماء: المستوى ${building.tier} (مساحة البناء ${building.sizeW}×${building.sizeH})',
                          style: const TextStyle(
                            fontFamily: 'GESSTwo',
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildModalStat('النوع', building.type.displayName),
                    _buildModalStat('الموقع', '(${building.gx}, ${building.gy})'),
                    _buildModalStat('الحالة', 'نضرة وثابتة 🌿'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: const Color(0xFFFFD700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'تم',
                    style: TextStyle(
                      fontFamily: 'GESSTwo',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalStat(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Amiri',
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'GESSTwo',
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _particleController.dispose();
    _transController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedFilter == null
        ? _buildings
        : _buildings.where((b) => b.type == _selectedFilter).toList();

    // Absolute Depth Sorting for Clash-of-Clans rendering
    filtered.sort((a, b) => a.depth.compareTo(b.depth));

    return Scaffold(
      backgroundColor: const Color(0xFF04140D),
      body: Stack(
        children: [
          // 1. Interactive 2.5D Canvas
          InteractiveViewer(
            transformationController: _transController,
            minScale: 0.45,
            maxScale: 2.8,
            boundaryMargin: const EdgeInsets.all(600),
            constrained: false,
            child: SizedBox(
              width: _canvasW,
              height: _canvasH,
              child: Stack(
                children: [
                  // A. The Isometric Tile Grid Matrix
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(_canvasW, _canvasH),
                        painter: _IsometricGridPainter(
                          grid: _grid,
                          waveProgress: _waveController.value,
                        ),
                      );
                    },
                  ),

                  // B. Placed Buildings & Trees strictly anchored to Isometric Base
                  ...filtered.map((b) {
                    final anchorPos = gridToScreen(
                      b.gx + b.sizeW * 0.5,
                      b.gy + b.sizeH * 0.5,
                      b.elevation,
                    );

                    final visualSize = _getSpriteVisualSize(b.type);

                    return Positioned(
                      left: anchorPos.dx - visualSize / 2,
                      top: anchorPos.dy - visualSize * 0.88,
                      child: GestureDetector(
                        onTap: () => _showRewardSheet(b),
                        child: _buildBuildingSprite(b, visualSize),
                      ),
                    );
                  }),

                  // C. Atmospheric Particles
                  AnimatedBuilder(
                    animation: _particleController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(_canvasW, _canvasH),
                        painter: _AtmosphereParticlesPainter(
                          particles: _particles,
                          petals: _petals,
                          progress: _particleController.value,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 2. Top Glassmorphic HUD
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildTopBar(),
              ),
            ),
          ),

          // 3. Bottom Category Filter & Planting Controls
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _buildBottomPanel(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingSprite(_IsometricBuilding b, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Isometric Soft Shadow Decal on the ground
          Positioned(
            bottom: 6,
            child: Container(
              width: size * (b.sizeW == 2 ? 0.75 : 0.55),
              height: size * 0.22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(size * 0.25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // Main Building / Tree Sprite
          Image.asset(
            b.assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
          ),

          // Tier 5 Radiant Golden Aura
          if (b.tier >= 5)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                        blurRadius: 22,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'واحة جنتي الآيزومترية 🌿✨',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                  Text(
                    '${NumberFormatter.toArabic(_buildings.length)} معالم وغراس (شبكة آيزومترية 120 FPS)',
                    style: TextStyle(
                      fontFamily: 'GESSTwo',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: _soundEnabled ? 'كتم الصوت' : 'تشغيل الصوت',
              icon: Icon(
                _soundEnabled ? Icons.volume_up : Icons.volume_off,
                color: _soundEnabled ? const Color(0xFFFFD700) : Colors.white54,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _soundEnabled = !_soundEnabled;
                  SpiritualAudioService().toggle();
                });
              },
            ),
            IconButton(
              tooltip: 'إعادة التوسيط',
              icon: const Icon(Icons.center_focus_strong, color: Color(0xFFFFD700), size: 20),
              onPressed: _centerView,
            ),
            IconButton(
              tooltip: 'الانتقال إلى عالم 3D',
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                ),
                child: const Text(
                  '3D',
                  style: TextStyle(
                    fontFamily: 'GESSTwo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Jannati3DScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final counts = <RewardType, int>{};
    for (final b in _buildings) {
      counts[b.type] = (counts[b.type] ?? 0) + 1;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Filter Pills
        SizedBox(
          height: 40,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: RewardType.values.map((type) {
                final count = counts[type] ?? 0;
                final isSelected = _selectedFilter == type;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedFilter = isSelected ? null : type;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFFD700).withValues(alpha: 0.25)
                            : const Color(0xFF0D2818).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFFD700)
                              : const Color(0xFFFFD700).withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            GardenAssets.getIconAsset(type),
                            width: 18,
                            height: 18,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${type.displayName} (${NumberFormatter.toArabic(count)})',
                            style: TextStyle(
                              fontFamily: 'GESSTwo',
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFFFFD700) : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Quick Planting Actions Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2818).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    final targetType = _selectedFilter ?? RewardType.palmTree;
                    final placed = _tryPlaceBuilding(targetType, tier: 1);
                    if (!placed) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الواحة عامرة! لا توجد مساحة شاغرة.'),
                          backgroundColor: Color(0xFF1B5E20),
                        ),
                      );
                    } else {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    'اغرس ${_selectedFilter?.displayName ?? "نخلة"}',
                    style: const TextStyle(fontFamily: 'GESSTwo', fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: const Color(0xFFFFD700),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                if (_buildings.isNotEmpty)
                  TextButton.icon(
                    onPressed: _undoLast,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text(
                      'تراجع',
                      style: TextStyle(fontFamily: 'GESSTwo', fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade300,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// 📐 CLASH-OF-CLANS ISOMETRIC GRID PAINTER
// =========================================================================

class _IsometricGridPainter extends CustomPainter {
  final List<List<_TileInfo>> grid;
  final double waveProgress;

  _IsometricGridPainter({
    required this.grid,
    required this.waveProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Realtime Celestial Sky Gradient based on current hour
    final hour = DateTime.now().hour;
    final List<Color> skyColors;
    if (hour >= 4 && hour < 7) {
      // 🌅 الفجر (Fajr Dawn)
      skyColors = const [
        Color(0xFF031A12),
        Color(0xFF0A3C28),
        Color(0xFF1B6B48),
      ];
    } else if (hour >= 7 && hour < 17) {
      // ☀️ الضحى والنهار (Golden Duha & Day)
      skyColors = const [
        Color(0xFF072418),
        Color(0xFF145332),
        Color(0xFF1E7044),
      ];
    } else if (hour >= 17 && hour < 20) {
      // 🌇 الغروب والأصيل (Sunset Amber)
      skyColors = const [
        Color(0xFF1C0D26),
        Color(0xFF421C2B),
        Color(0xFF7A341E),
      ];
    } else {
      // 🌌 الليل والتهجد (Cosmic Night)
      skyColors = const [
        Color(0xFF010A06),
        Color(0xFF051810),
        Color(0xFF0B2418),
      ];
    }

    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: skyColors,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    final gridSize = grid.length;

    // 2. Render Tiles diagonally from back to front (d = 0 to 2*N-2)
    for (int d = 0; d < 2 * gridSize - 1; d++) {
      for (int x = 0; x < gridSize; x++) {
        final y = d - x;
        if (y < 0 || y >= gridSize) continue;

        final tile = grid[x][y];
        _drawSingleTile(canvas, x, y, tile);
      }
    }
  }

  void _drawSingleTile(Canvas canvas, int gx, int gy, _TileInfo tile) {
    final elev = tile.elevation;
    final top = _JannatiIsometricScreenState.gridToScreen(gx.toDouble(), gy.toDouble(), elev);
    final right = _JannatiIsometricScreenState.gridToScreen(gx + 1.0, gy.toDouble(), elev);
    final bottom = _JannatiIsometricScreenState.gridToScreen(gx + 1.0, gy + 1.0, elev);
    final left = _JannatiIsometricScreenState.gridToScreen(gx.toDouble(), gy + 1.0, elev);

    final diamond = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..close();

    // 1. If elevated plateau, draw extruded cliff sides first
    if (elev > 0.0) {
      final baseLeft = _JannatiIsometricScreenState.gridToScreen(gx.toDouble(), gy + 1.0, 0.0);
      final baseBottom = _JannatiIsometricScreenState.gridToScreen(gx + 1.0, gy + 1.0, 0.0);
      final baseRight = _JannatiIsometricScreenState.gridToScreen(gx + 1.0, gy.toDouble(), 0.0);

      // Left Cliff Face (Darker)
      final leftCliff = Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(bottom.dx, bottom.dy)
        ..lineTo(baseBottom.dx, baseBottom.dy)
        ..lineTo(baseLeft.dx, baseLeft.dy)
        ..close();
      canvas.drawPath(leftCliff, Paint()..color = const Color(0xFF163E26));

      // Right Cliff Face (Mid Tone)
      final rightCliff = Path()
        ..moveTo(bottom.dx, bottom.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(baseRight.dx, baseRight.dy)
        ..lineTo(baseBottom.dx, baseBottom.dy)
        ..close();
      canvas.drawPath(rightCliff, Paint()..color = const Color(0xFF1E5233));
    }

    // 2. Fill the Top Tile Surface based on TileType
    switch (tile.type) {
      case TileType.grass:
        // Checkerboard subtle variation for true game grid texture
        final isEven = (gx + gy) % 2 == 0;
        final grassColor = isEven ? const Color(0xFF389E5B) : const Color(0xFF318F50);
        canvas.drawPath(diamond, Paint()..color = grassColor);

        // Thin delicate tile border for seamless grid definition
        final borderPaint = Paint()
          ..color = const Color(0xFF43AE67).withValues(alpha: 0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.75;
        canvas.drawPath(diamond, borderPaint);
        break;

      case TileType.plateau:
        final isEven = (gx + gy) % 2 == 0;
        final platColor = isEven ? const Color(0xFF42A864) : const Color(0xFF389A57);
        canvas.drawPath(diamond, Paint()..color = platColor);
        break;

      case TileType.sand:
        final isEven = (gx + gy) % 2 == 0;
        final sandColor = isEven ? const Color(0xFFD9BD88) : const Color(0xFFCCAE77);
        canvas.drawPath(diamond, Paint()..color = sandColor);
        break;

      case TileType.water:
        // Multi-layered Crystal Turquoise Water with dynamic wave foam
        final waterPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF007791),
              Color(0xFF00B4D8),
              Color(0xFF0096C7),
            ],
          ).createShader(Rect.fromPoints(top, bottom));
        canvas.drawPath(diamond, waterPaint);

        // Dynamic Flowing Sparkling Wave Crests
        final wavePhase1 = ((gx * 3 + gy * 4) / 25.0 + waveProgress) % 1.0;
        final wavePhase2 = ((gx * 2 + gy * 5) / 20.0 + waveProgress * 1.3) % 1.0;

        final w1P1 = Offset.lerp(top, left, wavePhase1)!;
        final w1P2 = Offset.lerp(right, bottom, wavePhase1)!;
        final waveLine1 = Paint()
          ..color = Colors.white.withValues(alpha: 0.55 * sin(wavePhase1 * pi))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawLine(w1P1, w1P2, waveLine1);

        final w2P1 = Offset.lerp(left, bottom, wavePhase2)!;
        final w2P2 = Offset.lerp(top, right, wavePhase2)!;
        final waveLine2 = Paint()
          ..color = const Color(0xFFE0F7FA).withValues(alpha: 0.45 * sin(wavePhase2 * pi))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawLine(w2P1, w2P2, waveLine2);
        break;

      case TileType.bridge:
        // Marble Bridge Tile with Golden Trim
        canvas.drawPath(diamond, Paint()..color = const Color(0xFFF5F5F5));
        final bridgeTrim = Paint()
          ..color = const Color(0xFFFFD700)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawPath(diamond, bridgeTrim);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricGridPainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress;
  }
}

// =========================================================================
// ✨ ATMOSPHERIC PARTICLES
// =========================================================================

class _Particle {
  double x;
  double y;
  double radius;
  double speed;
  double phase;

  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
  });
}

class _Petal {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  double rotation;
  Color color;

  _Petal({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.rotation,
    required this.color,
  });
}

class _AtmosphereParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final List<_Petal> petals;
  final double progress;

  _AtmosphereParticlesPainter({
    required this.particles,
    required this.petals,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Golden Light Motes
    final motePaint = Paint()..color = const Color(0xFFFFF9C4);

    for (final p in particles) {
      final curY = (p.y - progress * 120 * p.speed) % size.height;
      final curX = p.x + sin(progress * pi * 4 + p.phase) * 12;
      canvas.drawCircle(Offset(curX, curY), p.radius, motePaint);
    }

    // 2. Drifting Wind Petals
    for (final pet in petals) {
      final curX = (pet.x + progress * 200 * pet.speedX) % size.width;
      final curY = (pet.y + progress * 100 * pet.speedY) % size.height;

      final pPaint = Paint()..color = pet.color.withValues(alpha: 0.85);

      canvas.save();
      canvas.translate(curX, curY);
      canvas.rotate(pet.rotation + progress * pi * 2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: pet.size, height: pet.size * 0.5),
        pPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AtmosphereParticlesPainter oldDelegate) => true;
}
