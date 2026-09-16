import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gl_flutterflow/flutter_gl.dart';
import 'package:three_dart_flutterflow/three_dart.dart' as three;
import 'package:three_dart_jsm_flutterflow/three_dart_jsm.dart' as three_jsm;

import '../models/reward_type.dart';
import '../services/spiritual_audio_service.dart';
import '../services/storage_service.dart';
import '../three/asset_map.dart';
import '../utils/garden_assets.dart';
import '../utils/number_formatter.dart';

class _AnimatedModel {
  final three.Object3D mesh;
  final int bornAt;
  final RewardType type;
  final int tier;
  _AnimatedModel(this.mesh, this.bornAt, this.type, {this.tier = 1});
}

class _SavedEntry {
  final RewardType type;
  final double x;
  final double y;
  final double z;
  final int tier;

  _SavedEntry(this.type, this.x, this.y, this.z, {this.tier = 1});

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'x': x,
        'y': y,
        'z': z,
        'tier': tier,
      };

  static _SavedEntry fromJson(Map<String, dynamic> m) => _SavedEntry(
        RewardType.values.byName(m['type'] as String),
        (m['x'] as num).toDouble(),
        (m['y'] as num).toDouble(),
        (m['z'] as num).toDouble(),
        tier: (m['tier'] as num?)?.toInt() ?? 1,
      );
}

class Jannati3DScreen extends StatefulWidget {
  const Jannati3DScreen({super.key});

  @override
  State<Jannati3DScreen> createState() => _Jannati3DScreenState();
}

class _Jannati3DScreenState extends State<Jannati3DScreen> with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  late FlutterGlPlugin _three3dRender;
  three.WebGLRenderer? _renderer;
  double _width = 800;
  double _height = 600;
  Size? _screenSize;
  late three.Scene _scene;
  late three.Camera _camera;
  final double _dpr = 1.0;
  bool _disposed = false;
  bool _loaded = false;
  bool _didSync = false;
  bool _platformInitStarted = false; // guard: prevent double initPlatformState
  bool _autoRotate = true;
  bool _soundEnabled = true;
  RewardType? _selectedFilter;

  // ignore: unused_field
  late three.WebGLRenderTarget _renderTarget;
  dynamic _sourceTexture;
  final GlobalKey<three_jsm.DomLikeListenableState> _globalKey =
      GlobalKey<three_jsm.DomLikeListenableState>();
  late three_jsm.OrbitControls _controls;
  final List<_AnimatedModel> _animatedModels = [];
  final List<_SavedEntry> _savedEntries = [];
  final Map<String, three.Object3D> _glbCache = {};

  // Environment & Atmosphere Elements
  three.Mesh? _waterMesh;
  final List<three.Mesh> _riverRipples = [];
  final List<three.Group> _clouds = [];
  final three.Group _particlesGroup = three.Group();
  final List<double> _particleInitialY = [];
  final List<double> _particleSpeeds = [];
  final three.Group _birdsGroup = three.Group();
  final three.Group _fallingLeavesGroup = three.Group();
  final List<three.Vector3> _leafVelocities = [];
  int _frameCount = 0;

  final Random _rng = Random(42);

  static const double _kGroundW = 280.0;
  static const double _kGroundD = 180.0;
  static const double _kMinSpacing = 8.5;
  static const int _kMaxSceneModels = 65;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  double _calculateGroundElevation(double x, double z) {
    // East Bluff is centered at (48, -26) with radius 33.0 and height 2.5
    final dx = x - 48.0;
    final dz = z - (-26.0);
    final distSq = dx * dx + dz * dz;
    if (distSq < (33.0 * 33.0)) {
      return 2.5; // Elevated on hill
    }
    return 0.0;
  }

  void _loadSaved() {
    final raw = _storage.getRewards3D();
    _savedEntries.clear();
    bool needsSave = false;
    for (final r in raw) {
      final entry = _SavedEntry.fromJson(r);
      double sx = entry.x;
      double sz = entry.z;

      // 1. Relocate anything in the river corridor (x: -24..24)
      if (sx.abs() < 24.0) {
        sx = sx >= 0 ? 35.0 : -35.0;
        needsSave = true;
      }
      // 2. Relocate anything inside outer mountains (|x| > 72 or |z| > 50)
      if (sx.abs() > 72.0) {
        sx = 62.0 * sx.sign;
        needsSave = true;
      }
      if (sz.abs() > 50.0) {
        sz = 42.0 * sz.sign;
        needsSave = true;
      }

      // 3. Dynamic Hill Elevation Clamping
      final double sy = _calculateGroundElevation(sx, sz);
      if ((sy - entry.y).abs() > 0.1) {
        needsSave = true;
      }

      _savedEntries.add(_SavedEntry(entry.type, sx, sy, sz, tier: entry.tier));
    }
    if (needsSave) {
      _storage.saveRewards3D(_savedEntries.map((e) => e.toJson()).toList());
      debugPrint('🧹 Cleaned up and elevated 3D rewards on hills');
    }
    debugPrint('📂 Loaded ${_savedEntries.length} 3D entries from storage');
  }

  int _calculateTier(int dhikrCount) {
    if (dhikrCount >= 10000) return 5;
    if (dhikrCount >= 2000) return 4;
    if (dhikrCount >= 500) return 3;
    if (dhikrCount >= 100) return 2;
    return 1;
  }

  void _syncFromDhikrRewards() {
    if (_didSync) return;
    _didSync = true;

    final allRewards = _storage.getAllRewards();
    if (allRewards.isEmpty) return;

    final byType = <RewardType, int>{};
    for (final r in allRewards) {
      byType[r.type] = (byType[r.type] ?? 0) + 1;
    }

    final current3D = <RewardType, int>{};
    for (final e in _savedEntries) {
      current3D[e.type] = (current3D[e.type] ?? 0) + 1;
    }

    int totalAdded = 0;
    for (final type in RewardType.values) {
      final totalRewards = byType[type] ?? 0;
      if (totalRewards <= 0) continue;

      final tier = _calculateTier(totalRewards);

      int targetCount;
      if (totalRewards < 50) {
        targetCount = (totalRewards / 10).ceil();
      } else if (totalRewards < 200) {
        targetCount = 5 + ((totalRewards - 50) ~/ 30);
      } else if (totalRewards < 1000) {
        targetCount = 10 + ((totalRewards - 200) ~/ 100);
      } else {
        targetCount = 18 + ((totalRewards - 1000) ~/ 500);
      }

      targetCount = targetCount.clamp(1, 15);

      final currentCount = current3D[type] ?? 0;
      final missing = targetCount - currentCount;

      for (var i = 0; i < missing; i++) {
        if (_animatedModels.length >= _kMaxSceneModels) break;
        addModelAt(type: type, tier: tier);
        totalAdded++;
      }
    }

    if (totalAdded > 0) {
      debugPrint('🔄 Synced $totalAdded new 3D rewards according to Tier progression');
    }
  }

  void initSize(BuildContext context) {
    if (_screenSize != null) return;
    final mqd = MediaQuery.of(context);
    _screenSize = mqd.size;
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    if (_platformInitStarted) return; // guard: skip if already initializing
    _platformInitStarted = true;
    _width = _screenSize!.width;
    _height = _screenSize!.height;

    _three3dRender = FlutterGlPlugin();

    Map<String, dynamic> options = {
      "antialias": true,
      "alpha": false,
      "width": _width.toInt(),
      "height": _height.toInt(),
      "dpr": _dpr,
    };

    await _three3dRender.initialize(options: options);
    setState(() {});

    Future.delayed(const Duration(milliseconds: 100), () async {
      await _three3dRender.prepareContext();
      initScene();
    });
  }

  void _onResize(double newW, double newH) {
    if (newW <= 0 || newH <= 0) return;
    if ((_width - newW).abs() < 1 && (_height - newH).abs() < 1) return;
    _width = newW;
    _height = newH;
    if (_renderer != null && _camera is three.PerspectiveCamera) {
      final pCam = _camera as three.PerspectiveCamera;
      pCam.aspect = newW / newH;
      if (newW < newH) {
        pCam.fov = 56.0;
      } else {
        pCam.fov = 44.0;
      }
      pCam.updateProjectionMatrix();
      _renderer!.setSize(newW, newH, false);
      _controls.update();
    }
  }

  // =========================================================================
  // 🌅 1. RICH EMERALD ATMOSPHERE & GOLDEN SUN
  // =========================================================================

  void _buildAtmosphere() {
    // 1. Celestial Emerald Sky Dome
    final skyGeo = three.SphereGeometry(380, 24, 16);
    final skyMat = three.MeshBasicMaterial({
      "color": 0x1A543E,
      "side": three.BackSide,
    });
    final sky = three.Mesh(skyGeo, skyMat);
    _scene.add(sky);

    // 2. Radiant Golden Sun
    final sunGroup = three.Group();
    sunGroup.position.set(50, 90, -90);

    final sunCore = three.Mesh(
      three.SphereGeometry(16, 16, 16),
      three.MeshBasicMaterial({"color": 0xFFFDF0}),
    );
    sunGroup.add(sunCore);

    final sunCorona = three.Mesh(
      three.SphereGeometry(32, 16, 16),
      three.MeshBasicMaterial({
        "color": 0xFFE082,
        "transparent": true,
        "opacity": 0.5,
      }),
    );
    sunGroup.add(sunCorona);
    _scene.add(sunGroup);

    // 3. Floating Stylized Clouds
    _clouds.clear();
    final cloudMat = three.MeshPhongMaterial({
      "color": 0xFFFAF0,
      "emissive": 0x1A3A28,
      "shininess": 30,
      "transparent": true,
      "opacity": 0.88,
      "flatShading": true,
    });

    final cloudPositions = [
      three.Vector3(-110, 75, -50),
      three.Vector3(-30, 85, 60),
      three.Vector3(70, 80, -70),
      three.Vector3(110, 70, 40),
      three.Vector3(-5, 90, -30),
    ];

    for (final cPos in cloudPositions) {
      final cloud = three.Group();
      cloud.position.copy(cPos);

      final puffSizes = [9.0, 14.0, 10.0, 8.0];
      final puffOffsets = [
        three.Vector3(-9, 0, 0),
        three.Vector3(0, 3, 0),
        three.Vector3(9, -1, 0),
        three.Vector3(0, -1, 5),
      ];

      for (int p = 0; p < puffSizes.length; p++) {
        final puffGeo = three.SphereGeometry(puffSizes[p], 7, 6);
        final puff = three.Mesh(puffGeo, cloudMat);
        puff.position.copy(puffOffsets[p]);
        puff.scale.set(1.4, 0.7, 1.0);
        cloud.add(puff);
      }

      _clouds.add(cloud);
      _scene.add(cloud);
    }
  }

  // =========================================================================
  // 🌿 2. SCULPTED HIGH-CONTRAST TERRAIN & FINE VOLUMETRIC MEADOW
  // =========================================================================

  void _buildSculptedTerrain() {
    final terrainGroup = three.Group();

    // 1. Rich Emerald Green Meadows
    final grassMat = three.MeshPhongMaterial({
      "color": 0x227744,
      "emissive": 0x082414,
      "specular": 0x55C578,
      "shininess": 22,
      "flatShading": true,
    });

    // 2. Warm Sandy River Shorelines
    final bankSandMat = three.MeshPhongMaterial({
      "color": 0xC9A974,
      "emissive": 0x1E1408,
      "specular": 0xDDC59A,
      "shininess": 12,
      "flatShading": true,
    });

    // West Bank (Forest & Villas) - from x: -140 to -16
    final westGeo = three.PlaneGeometry(124, _kGroundD, 16, 16);
    final westBank = three.Mesh(westGeo, grassMat);
    westBank.rotation.x = -three.Math.pi / 2;
    westBank.position.set(-78, 0, 0);
    terrainGroup.add(westBank);

    // East Bank (Oasis & Palaces) - from x: 16 to 140
    final eastGeo = three.PlaneGeometry(124, _kGroundD, 16, 16);
    final eastBank = three.Mesh(eastGeo, grassMat);
    eastBank.rotation.x = -three.Math.pi / 2;
    eastBank.position.set(78, 0, 0);
    terrainGroup.add(eastBank);

    // Sloping Shorelines
    final slopeGeo = three.PlaneGeometry(7, _kGroundD, 4, 16);

    final leftSlope = three.Mesh(slopeGeo, bankSandMat);
    leftSlope.rotation.x = -three.Math.pi / 2;
    leftSlope.rotation.y = 0.26;
    leftSlope.position.set(-13.5, -0.6, 0);
    terrainGroup.add(leftSlope);

    final rightSlope = three.Mesh(slopeGeo, bankSandMat);
    rightSlope.rotation.x = -three.Math.pi / 2;
    rightSlope.rotation.y = -0.26;
    rightSlope.position.set(13.5, -0.6, 0);
    terrainGroup.add(rightSlope);

    // Elevated East Bluff for Mosque / Palaces
    final palacePlateauMat = three.MeshPhongMaterial({
      "color": 0x2A864D,
      "specular": 0x55C578,
      "shininess": 22,
      "flatShading": true,
    });
    final palaceBluff = three.Mesh(
      three.CylinderGeometry(28, 33, 2.5, 12),
      palacePlateauMat,
    );
    palaceBluff.position.set(48, 1.25, -26);
    palaceBluff.scale.set(1.3, 1.0, 0.9);
    terrainGroup.add(palaceBluff);

    // Distant Outer Mountains
    final mountainMat = three.MeshPhongMaterial({
      "color": 0x144C2D,
      "emissive": 0x081F12,
      "shininess": 8,
      "flatShading": true,
    });

    final perimeterMountains = [
      three.Vector3(-95, 0, -90),
      three.Vector3(-35, 0, -98),
      three.Vector3(35, 0, -98),
      three.Vector3(95, 0, -90),
      three.Vector3(-95, 0, 90),
      three.Vector3(-35, 0, 98),
      three.Vector3(35, 0, 98),
      three.Vector3(95, 0, 90),
      three.Vector3(-135, 0, 0),
      three.Vector3(135, 0, 0),
    ];

    for (int i = 0; i < perimeterMountains.length; i++) {
      final pos = perimeterMountains[i];
      final radius = 32.0 + (i % 3) * 8.0;
      final height = 18.0 + (i % 4) * 5.0;
      final cone = three.Mesh(
        three.ConeGeometry(radius, height, 8),
        mountainMat,
      );
      cone.position.set(pos.x, height * 0.45, pos.z);
      cone.scale.set(1.4, 0.65, 1.1);
      terrainGroup.add(cone);
    }

    // Organic Soil & Moss Patches for Natural Roughness
    final mossMat = three.MeshPhongMaterial({"color": 0x175432, "shininess": 15, "flatShading": true});
    final soilPatchMat = three.MeshPhongMaterial({"color": 0x3E2B1D, "shininess": 10, "flatShading": true});

    for (int p = 0; p < 45; p++) {
      final isEast = p % 2 == 0;
      final px = isEast ? 25.0 + _rng.nextDouble() * 45.0 : -25.0 - _rng.nextDouble() * 45.0;
      final pz = (_rng.nextDouble() * 95.0) - 47.5;
      final py = _calculateGroundElevation(px, pz);
      final pr = 2.0 + _rng.nextDouble() * 4.5;
      final patchMat = (p % 3 == 0) ? soilPatchMat : mossMat;
      final patch = three.Mesh(three.CircleGeometry(radius: pr, segments: 8), patchMat);
      patch.rotation.x = -three.Math.pi / 2;
      patch.position.set(px, py + 0.01, pz);
      patch.scale.set(1.3, 1.0, 0.9);
      terrainGroup.add(patch);
    }

    _scene.add(terrainGroup);

    // 3. Fine Volumetric Grass Tufts & Flowers
    _buildMeadowFlora();

    // 4. Crystalline Geode Rock Formations on Riverbanks
    _buildCrystalGeodes();
  }

  void _buildMeadowFlora() {
    final grassColors = [0x2E7D32, 0x388E3C, 0x43A047, 0x4CAF50, 0x66BB6A];
    final flowerWhite = three.MeshBasicMaterial({"color": 0xFFFFFF});
    final flowerGold = three.MeshBasicMaterial({"color": 0xFFD54F});
    final flowerPink = three.MeshBasicMaterial({"color": 0xF48FB1});

    // Fine, natural-scale volumetric grass (280 tufts across meadows)
    for (int i = 0; i < 280; i++) {
      final isEast = i % 2 == 0;
      final x = isEast
          ? 22.0 + _rng.nextDouble() * 46.0
          : -22.0 - _rng.nextDouble() * 46.0;
      final z = (_rng.nextDouble() * 90.0) - 45.0;
      final groundY = _calculateGroundElevation(x, z);

      final tuftGroup = three.Group();
      tuftGroup.position.set(x, groundY + 0.02, z);

      final gMat = three.MeshPhongMaterial({
        "color": grassColors[i % grassColors.length],
        "shininess": 24,
        "flatShading": true,
      });

      // 3 to 4 delicate, fine grass blades
      final bladeCount = 3 + (i % 2);
      for (int b = 0; b < bladeCount; b++) {
        final bAngle = (b / bladeCount) * three.Math.pi * 2 + _rng.nextDouble() * 0.3;
        final bHeight = 0.35 + _rng.nextDouble() * 0.35; // Finer, realistic lawn scale
        final blade = three.Mesh(
          three.ConeGeometry(0.08, bHeight, 4),
          gMat,
        );
        blade.position.set(0.12 * sin(bAngle), bHeight * 0.45, 0.12 * cos(bAngle));
        blade.rotation.z = sin(bAngle) * 0.28;
        blade.rotation.x = cos(bAngle) * 0.28;
        tuftGroup.add(blade);
      }

      // Delicate Meadow Blossoms
      if (i % 4 == 0) {
        final fMat = (i % 8 == 0) ? flowerPink : (i % 12 == 0 ? flowerGold : flowerWhite);
        final blossom = three.Mesh(three.SphereGeometry(0.12, 4, 4), fMat);
        blossom.position.set(
          (_rng.nextDouble() - 0.5) * 0.35,
          0.35 + _rng.nextDouble() * 0.25,
          (_rng.nextDouble() - 0.5) * 0.35,
        );
        tuftGroup.add(blossom);
      }

      _scene.add(tuftGroup);
    }
  }

  void _buildCrystalGeodes() {
    final geodeRockMat = three.MeshPhongMaterial({
      "color": 0x125437,
      "emissive": 0x062416,
      "specular": 0x33B880,
      "shininess": 60,
      "flatShading": true,
    });

    final crystalPurple = three.MeshPhongMaterial({
      "color": 0xBA68C8,
      "emissive": 0x4A148C,
      "specular": 0xFFFFFF,
      "shininess": 100,
    });

    final crystalCyan = three.MeshPhongMaterial({
      "color": 0x80DEEA,
      "emissive": 0x006064,
      "specular": 0xFFFFFF,
      "shininess": 100,
    });

    final geodePositions = [
      three.Vector3(-18.5, 0.2, 16.0),
      three.Vector3(18.5, 0.2, -16.0),
      three.Vector3(-19.0, 0.2, -26.0),
      three.Vector3(19.0, 0.2, 28.0),
    ];

    for (int g = 0; g < geodePositions.length; g++) {
      final gPos = geodePositions[g];
      final geodeGroup = three.Group();
      geodeGroup.position.copy(gPos);

      final rock = three.Mesh(three.DodecahedronGeometry(2.2), geodeRockMat);
      rock.scale.set(1.4, 0.65, 1.2);
      geodeGroup.add(rock);

      final cMat = g % 2 == 0 ? crystalPurple : crystalCyan;
      for (int c = 0; c < 8; c++) {
        final angle = (c / 8) * three.Math.pi * 2;
        final h = 1.0 + _rng.nextDouble() * 1.1;
        final spike = three.Mesh(three.ConeGeometry(0.25, h, 6), cMat);
        spike.position.set(0.55 * sin(angle), 0.85 + h * 0.45, 0.55 * cos(angle));
        spike.rotation.z = sin(angle) * 0.35;
        spike.rotation.x = cos(angle) * 0.35;
        geodeGroup.add(spike);
      }

      _scene.add(geodeGroup);
    }
  }

  // =========================================================================
  // 🌊 3. FLOWING DYNAMIC RIVER & RIPPLES
  // =========================================================================

  void _buildRiverAndFeatures() {
    // 1. Crystal Turquoise Water Base
    final waterGeo = three.PlaneGeometry(30, _kGroundD * 1.02, 16, 32);
    final waterMat = three.MeshPhongMaterial({
      "color": 0x00B4D8,
      "emissive": 0x005F73,
      "specular": 0xFFFFFF,
      "shininess": 160,
      "transparent": true,
      "opacity": 0.82,
      "side": three.DoubleSide,
    });
    _waterMesh = three.Mesh(waterGeo, waterMat);
    _waterMesh!.rotation.x = -three.Math.pi / 2;
    _waterMesh!.position.set(0, 0.15, 0);
    _scene.add(_waterMesh!);

    // 2. Dynamic River Stream Ripple Lines
    _riverRipples.clear();
    final rippleMat = three.MeshBasicMaterial({
      "color": 0xE0F7FA,
      "transparent": true,
      "opacity": 0.45,
      "side": three.DoubleSide,
    });

    for (int r = 0; r < 24; r++) {
      final rGeo = three.PlaneGeometry(2.5 + _rng.nextDouble() * 4.0, 0.35);
      final ripple = three.Mesh(rGeo, rippleMat);
      ripple.rotation.x = -three.Math.pi / 2;
      ripple.position.set(
        ((_rng.nextDouble() * 16.0) - 8.0),
        0.18,
        (_rng.nextDouble() * _kGroundD) - (_kGroundD / 2),
      );
      _riverRipples.add(ripple);
      _scene.add(ripple);
    }

    // 3. Sandy Riverbed Floor
    final bedGeo = three.PlaneGeometry(34, _kGroundD * 1.02, 8, 16);
    final bedMat = three.MeshPhongMaterial({
      "color": 0x0C3825,
      "side": three.DoubleSide,
    });
    final bed = three.Mesh(bedGeo, bedMat);
    bed.rotation.x = -three.Math.pi / 2;
    bed.position.set(0, -1.3, 0);
    _scene.add(bed);

    // 4. Riverbed Stones
    _buildRiverPebbles();

    // 5. White Marble Arched Bridge
    _buildArchedMarbleBridge();

    // 6. Water Lilies
    _buildWaterLilies();
  }

  void _buildRiverPebbles() {
    final stoneColors = [0x607D8B, 0x455A64, 0x795548, 0x90A4AE, 0x8D6E63];

    for (int i = 0; i < 45; i++) {
      final z = (_rng.nextDouble() * _kGroundD * 0.8) - (_kGroundD * 0.4);
      final x = ((_rng.nextDouble() * 18.0) - 9.0);
      final cMat = three.MeshPhongMaterial({
        "color": stoneColors[i % stoneColors.length],
        "shininess": 25,
        "flatShading": true,
      });

      final size = 0.6 + _rng.nextDouble() * 0.9;
      final stone = three.Mesh(three.DodecahedronGeometry(size), cMat);
      stone.position.set(x, -1.25 + size * 0.3, z);
      stone.scale.set(1.3, 0.6, 1.2);
      stone.rotation.set(_rng.nextDouble() * 3, _rng.nextDouble() * 3, _rng.nextDouble() * 3);
      _scene.add(stone);
    }
  }

  void _buildArchedMarbleBridge() {
    final bridgeGroup = three.Group();
    bridgeGroup.position.set(0, 0, 0);

    final marbleMat = three.MeshPhongMaterial({
      "color": 0xFFFFFF,
      "emissive": 0x111111,
      "specular": 0xFFFFFF,
      "shininess": 80,
      "flatShading": true,
    });
    final goldMat = three.MeshPhongMaterial({
      "color": 0xFFA000,
      "emissive": 0x6A4400,
      "shininess": 100,
    });

    // Arch Deck
    final arch = three.Mesh(three.BoxGeometry(36, 1.2, 7.5), marbleMat);
    arch.position.set(0, 1.6, 0);
    bridgeGroup.add(arch);

    // Ramps
    final leftRamp = three.Mesh(three.BoxGeometry(10, 0.9, 7.5), marbleMat);
    leftRamp.position.set(-20, 0.7, 0);
    leftRamp.rotation.z = 0.16;
    bridgeGroup.add(leftRamp);

    final rightRamp = three.Mesh(three.BoxGeometry(10, 0.9, 7.5), marbleMat);
    rightRamp.position.set(20, 0.7, 0);
    rightRamp.rotation.z = -0.16;
    bridgeGroup.add(rightRamp);

    // Balustrades
    for (int side in [-1, 1]) {
      final rail = three.Mesh(three.BoxGeometry(46, 0.6, 0.5), marbleMat);
      rail.position.set(0, 2.7, side * 3.4);
      bridgeGroup.add(rail);

      for (int p = -2; p <= 2; p++) {
        final post = three.Mesh(
          three.CylinderGeometry(0.3, 0.4, 1.6, 8),
          p.abs() == 2 ? goldMat : marbleMat,
        );
        post.position.set(p * 9.0, 2.4, side * 3.4);
        bridgeGroup.add(post);

        final lantern = three.Mesh(
          three.SphereGeometry(0.38, 8, 8),
          three.MeshBasicMaterial({"color": 0xFFF9C4}),
        );
        lantern.position.set(p * 9.0, 3.3, side * 3.4);
        bridgeGroup.add(lantern);
      }
    }

    _scene.add(bridgeGroup);
  }

  void _buildWaterLilies() {
    final padMat = three.MeshPhongMaterial({"color": 0x2E7D32, "shininess": 40});
    final lotusWhite = three.MeshPhongMaterial({"color": 0xFFFFFF, "emissive": 0xF48FB1, "shininess": 90});

    for (int i = 0; i < 16; i++) {
      final z = (_rng.nextDouble() * _kGroundD * 0.8) - (_kGroundD * 0.4);
      if (z.abs() < 12) continue;
      final x = ((_rng.nextDouble() * 18.0) - 9.0);

      final lilyGroup = three.Group();
      lilyGroup.position.set(x, 0.2, z);

      final pad = three.Mesh(three.CylinderGeometry(1.2, 1.2, 0.06, 8), padMat);
      lilyGroup.add(pad);

      final lotus = three.Mesh(three.ConeGeometry(0.5, 0.65, 6), lotusWhite);
      lotus.position.y = 0.35;
      lilyGroup.add(lotus);

      _scene.add(lilyGroup);
    }
  }

  // =========================================================================
  // 🍃 4. FLUTTERING WIND LEAVES & BIRDS & FIREFLIES
  // =========================================================================

  void _buildLightParticlesAndWildlife() {
    // 1. Floating Golden Fireflies
    _particlesGroup.clear();
    _scene.add(_particlesGroup);
    _particleInitialY.clear();
    _particleSpeeds.clear();

    final particleGeo = three.SphereGeometry(0.2, 4, 4);
    final particleMat = three.MeshBasicMaterial({"color": 0xFFF59D});

    for (int i = 0; i < 80; i++) {
      final pMesh = three.Mesh(particleGeo, particleMat);
      final x = (_rng.nextDouble() * _kGroundW * 0.7) - (_kGroundW * 0.35);
      final y = 3.0 + _rng.nextDouble() * 24.0;
      final z = (_rng.nextDouble() * _kGroundD * 0.7) - (_kGroundD * 0.35);
      pMesh.position.set(x, y, z);
      _particlesGroup.add(pMesh);
      _particleInitialY.add(y);
      _particleSpeeds.add(0.015 + _rng.nextDouble() * 0.02);
    }

    // 2. Fluttering Falling Wind Leaves & Sakura Petals
    _fallingLeavesGroup.clear();
    _leafVelocities.clear();
    _scene.add(_fallingLeavesGroup);

    final leafMatPink = three.MeshBasicMaterial({"color": 0xF8BBD0, "side": three.DoubleSide});
    final leafMatGold = three.MeshBasicMaterial({"color": 0xFFD54F, "side": three.DoubleSide});
    final leafMatGreen = three.MeshBasicMaterial({"color": 0x81C784, "side": three.DoubleSide});

    final leafGeo = three.PlaneGeometry(0.45, 0.3);

    for (int l = 0; l < 45; l++) {
      final mat = (l % 3 == 0) ? leafMatPink : (l % 3 == 1 ? leafMatGold : leafMatGreen);
      final leaf = three.Mesh(leafGeo, mat);
      final lx = (_rng.nextDouble() * _kGroundW * 0.6) - (_kGroundW * 0.3);
      final ly = 2.0 + _rng.nextDouble() * 26.0;
      final lz = (_rng.nextDouble() * _kGroundD * 0.6) - (_kGroundD * 0.3);
      leaf.position.set(lx, ly, lz);
      leaf.rotation.set(_rng.nextDouble() * 3, _rng.nextDouble() * 3, _rng.nextDouble() * 3);
      _fallingLeavesGroup.add(leaf);
      _leafVelocities.add(three.Vector3(
        0.04 + _rng.nextDouble() * 0.03, // Drift with wind along +X
        -0.015 - _rng.nextDouble() * 0.02, // Gentle downward glide
        0.03 + _rng.nextDouble() * 0.02, // Drift along +Z
      ));
    }

    // 3. White Doves Flying
    _birdsGroup.clear();
    final doveMat = three.MeshBasicMaterial({"color": 0xFFFFFF, "side": three.DoubleSide});
    for (int b = 0; b < 5; b++) {
      final bird = three.Group();
      bird.position.set(-45 + b * 20.0, 42.0 + (b % 3) * 5.0, -35.0 + b * 14.0);

      final w1 = three.Mesh(three.PlaneGeometry(1.3, 0.5), doveMat);
      w1.position.set(0.55, 0, 0);
      bird.add(w1);

      final w2 = three.Mesh(three.PlaneGeometry(1.3, 0.5), doveMat);
      w2.position.set(-0.55, 0, 0);
      bird.add(w2);

      _birdsGroup.add(bird);
    }
    _scene.add(_birdsGroup);
  }

  // =========================================================================
  // 🏛️ 5. DISTINCT ARCHITECTURE & VISUAL PROGRESSION (TIERS 1 TO 5)
  // =========================================================================

  three.Object3D _buildProceduralPalm({int tier = 1}) {
    final group = three.Group();
    final isGoldTier = tier >= 5;

    final segmentCount = tier == 1 ? 4 : (tier == 2 ? 5 : (tier == 3 ? 6 : 8));
    final trunkColor = isGoldTier ? 0xFFD700 : 0x795548;

    for (int s = 0; s < segmentCount; s++) {
      final topR = 0.44 - s * 0.035;
      final botR = 0.50 - s * 0.03;
      final mat = three.MeshPhongMaterial({
        "color": isGoldTier ? 0xFFD700 : (s % 2 == 0 ? 0x8D6E63 : trunkColor),
        "emissive": isGoldTier ? 0x665200 : 0x000000,
        "shininess": isGoldTier ? 90 : 15,
        "flatShading": true,
      });
      final segment = three.Mesh(three.CylinderGeometry(topR, botR, 1.0, 10), mat);
      segment.position.set(sin(s * 0.12) * 0.25, 0.5 + s * 0.95, cos(s * 0.08) * 0.1);
      segment.rotation.z = -s * 0.03;
      group.add(segment);
    }

    final topY = segmentCount * 0.95 + 0.2;

    if (tier >= 2) {
      final dateMat = three.MeshPhongMaterial({
        "color": isGoldTier ? 0xFFEA00 : 0xE65100,
        "emissive": isGoldTier ? 0x775500 : 0x4E2700,
        "shininess": 60,
      });
      final bunchCount = tier == 2 ? 3 : (tier == 3 ? 5 : 7);
      for (int d = 0; d < bunchCount; d++) {
        final a = (d / bunchCount) * three.Math.pi * 2;
        for (int b = 0; b < (tier >= 4 ? 4 : 2); b++) {
          final date = three.Mesh(three.SphereGeometry(0.14, 6, 6), dateMat);
          date.position.set(0.65 * sin(a), topY - 0.4 - b * 0.2, 0.65 * cos(a));
          group.add(date);
        }
      }
    }

    final frondColorDark = isGoldTier ? 0xFFD700 : 0x1B5E20;
    final frondColorLight = isGoldTier ? 0xFFEB3B : 0x388E3C;
    final frondDark = three.MeshPhongMaterial({"color": frondColorDark, "shininess": 30, "side": three.DoubleSide, "flatShading": true});
    final frondLight = three.MeshPhongMaterial({"color": frondColorLight, "shininess": 35, "side": three.DoubleSide, "flatShading": true});

    final layers = tier == 1 ? 1 : 2;
    final frondLen = tier == 1 ? 3.0 : (tier == 2 ? 3.8 : (tier == 3 ? 4.5 : 5.4));
    final frondCount = tier == 1 ? 5 : (tier == 2 ? 7 : (tier == 3 ? 10 : 14));

    for (int l = 0; l < layers; l++) {
      final count = l == 0 ? frondCount : (frondCount * 0.6).toInt();
      final mat = l == 0 ? frondDark : frondLight;
      final yBase = topY + (l * 0.3);
      for (int i = 0; i < count; i++) {
        final angle = (i / count) * three.Math.pi * 2 + l * 0.3;
        final frond = three.Mesh(three.ConeGeometry(0.85, frondLen, 5), mat);
        frond.position.set((frondLen * 0.38) * sin(angle), yBase - 0.5, (frondLen * 0.38) * cos(angle));
        frond.rotation.z = 0.68;
        frond.rotation.y = -angle + three.Math.pi / 2;
        group.add(frond);
      }
    }

    final s = tier == 1 ? 0.6 : (tier == 2 ? 0.75 : (tier == 3 ? 0.9 : (tier == 4 ? 1.05 : 1.2)));
    group.scale.set(s, s, s);
    return group;
  }

  three.Object3D _buildProceduralTree({int tier = 1}) {
    final group = three.Group();
    final isGoldTier = tier >= 5;

    final trunkMat = three.MeshPhongMaterial({
      "color": isGoldTier ? 0xFFD700 : 0x4E342E,
      "emissive": isGoldTier ? 0x554400 : 0x000000,
      "shininess": isGoldTier ? 80 : 15,
      "flatShading": true,
    });
    final trunk = three.Mesh(three.CylinderGeometry(0.35, 0.6, 3.4, 10), trunkMat);
    trunk.position.y = 1.7;
    group.add(trunk);

    if (tier >= 2) {
      for (int r = 0; r < 4; r++) {
        final angle = (r / 4) * three.Math.pi * 2;
        final root = three.Mesh(three.CylinderGeometry(0.12, 0.3, 0.8, 6), trunkMat);
        root.position.set(sin(angle) * 0.5, 0.25, cos(angle) * 0.5);
        root.rotation.z = sin(angle) * 0.45;
        root.rotation.x = cos(angle) * 0.45;
        group.add(root);
      }
    }

    final leafColors = isGoldTier
        ? [0xFFD700, 0xFFEB3B, 0xFFF176, 0xFFD700, 0xFFC107]
        : (tier >= 4
            ? [0x2E7D32, 0x388E3C, 0x43A047, 0xF8BBD0, 0xF48FB1, 0x388E3C, 0x2E7D32]
            : [0x2E7D32, 0x388E3C, 0x43A047, 0x4CAF50, 0x2E7D32]);

    final clusterConfigs = [
      [0.0, 4.8, 0.0, 2.0],
      [1.2, 4.2, 0.7, 1.6],
      [-1.1, 4.3, -0.5, 1.6],
      [0.4, 5.6, -0.3, 1.4],
      [-0.6, 5.1, 0.7, 1.4],
      [0.8, 5.4, -0.6, 1.2],
      [-0.2, 6.1, 0.1, 1.0],
    ];

    final clustersCount = tier == 1 ? 2 : (tier == 2 ? 4 : (tier == 3 ? 5 : 7));

    for (int i = 0; i < clustersCount; i++) {
      final p = clusterConfigs[i % clusterConfigs.length];
      final mat = three.MeshPhongMaterial({
        "color": leafColors[i % leafColors.length],
        "emissive": isGoldTier ? 0x443300 : 0x000000,
        "shininess": isGoldTier ? 80 : 20,
        "flatShading": true,
      });
      final leaf = three.Mesh(three.IcosahedronGeometry(p[3], 1), mat);
      leaf.position.set(p[0], p[1], p[2]);
      leaf.scale.set(1.0, 0.75, 1.0);
      group.add(leaf);
    }

    final s = tier == 1 ? 0.6 : (tier == 2 ? 0.75 : (tier == 3 ? 0.9 : (tier == 4 ? 1.05 : 1.2)));
    group.scale.set(s, s, s);
    return group;
  }

  three.Object3D _buildProceduralChest({int tier = 1}) {
    final group = three.Group();
    final isGoldTier = tier >= 5;

    final woodMat = three.MeshPhongMaterial({"color": isGoldTier ? 0x8D6E63 : 0x5D4037, "shininess": 35});
    final goldMat = three.MeshPhongMaterial({"color": 0xFFA000, "emissive": 0x6B4B00, "shininess": 100});
    final innerMat = three.MeshPhongMaterial({"color": 0xFFF9C4, "emissive": 0xFFA000, "shininess": 60});

    final body = three.Mesh(three.BoxGeometry(1.8, 0.9, 1.2), woodMat);
    body.position.y = 0.45;
    group.add(body);

    final inner = three.Mesh(three.BoxGeometry(1.6, 0.3, 1.0), innerMat);
    inner.position.y = 0.75;
    group.add(inner);

    for (double sx in [-0.55, 0.0, 0.55]) {
      final strap = three.Mesh(three.BoxGeometry(0.08, 0.92, 1.22), goldMat);
      strap.position.set(sx, 0.45, 0);
      group.add(strap);
    }

    final lid = three.Mesh(three.BoxGeometry(1.8, 0.15, 1.2), woodMat);
    lid.position.set(0, 1.0, -0.4);
    lid.rotation.x = -0.5;
    group.add(lid);

    final coinCount = tier * 3;
    for (int c = 0; c < coinCount.clamp(3, 12); c++) {
      final coin = three.Mesh(three.CylinderGeometry(0.12, 0.12, 0.04, 8), goldMat);
      coin.position.set((_rng.nextDouble() - 0.5) * 1.0, 0.9 + _rng.nextDouble() * 0.2, (_rng.nextDouble() - 0.5) * 0.5);
      coin.rotation.x = _rng.nextDouble();
      coin.rotation.z = _rng.nextDouble();
      group.add(coin);
    }

    final diamond = three.Mesh(
      three.OctahedronGeometry(0.25 + tier * 0.04),
      three.MeshPhongMaterial({"color": isGoldTier ? 0xFFD700 : 0x00E5FF, "emissive": 0x0097A7, "shininess": 100}),
    );
    diamond.position.set(0, 1.2, 0);
    group.add(diamond);

    group.scale.set(0.65, 0.65, 0.65);
    return group;
  }

  three.Object3D _buildProceduralHouse({int tier = 1}) {
    final group = three.Group();
    final isGoldTier = tier >= 5;

    final wallMat = three.MeshPhongMaterial({"color": isGoldTier ? 0xFFF8E1 : 0xFFFFFF, "shininess": 20, "flatShading": true});
    final woodMat = three.MeshPhongMaterial({"color": 0x4E342E, "shininess": 20});
    final roofMat = three.MeshPhongMaterial({
      "color": isGoldTier ? 0xFFA000 : (tier >= 3 ? 0x00897B : 0xBF360C),
      "emissive": isGoldTier ? 0x442200 : 0x000000,
      "shininess": 35,
      "flatShading": true,
    });
    final goldMat = three.MeshPhongMaterial({"color": 0xFFA000, "shininess": 90});

    final foundation = three.Mesh(three.BoxGeometry(3.8, 0.3, 3.0), woodMat);
    foundation.position.y = 0.15;
    group.add(foundation);

    final walls = three.Mesh(three.BoxGeometry(3.4, 2.4, 2.6), wallMat);
    walls.position.y = 1.35;
    group.add(walls);

    final roof = three.Mesh(three.ConeGeometry(2.8, 1.6, 4), roofMat);
    roof.position.y = 3.35;
    roof.rotation.y = three.Math.pi / 4;
    group.add(roof);

    final finial = three.Mesh(three.SphereGeometry(0.2, 10, 10), goldMat);
    finial.position.y = 4.2;
    group.add(finial);

    final door = three.Mesh(three.BoxGeometry(0.7, 1.3, 0.08), woodMat);
    door.position.set(0, 0.8, 1.32);
    group.add(door);

    final windowMat = three.MeshBasicMaterial({"color": 0xFFE082});
    for (int side in [-1, 1]) {
      final window = three.Mesh(three.BoxGeometry(0.55, 0.55, 0.06), windowMat);
      window.position.set(side * 1.0, 1.5, 1.32);
      group.add(window);
    }

    final s = tier == 1 ? 0.75 : (tier == 2 ? 0.85 : (tier == 3 ? 0.95 : (tier == 4 ? 1.05 : 1.15)));
    group.scale.set(s, s, s);
    return group;
  }

  three.Object3D _buildProceduralMosque({int tier = 1}) {
    final group = three.Group();
    final isGoldTier = tier >= 5;

    final marbleMat = three.MeshPhongMaterial({
      "color": 0xFFFFFF,
      "emissive": 0x111111,
      "specular": 0xFFFFFF,
      "shininess": 80,
      "flatShading": true,
    });
    final goldMat = three.MeshPhongMaterial({
      "color": 0xFFA000,
      "emissive": 0x6A4400,
      "shininess": 100,
    });
    final domeColor = isGoldTier ? 0xFFA000 : (tier >= 3 ? 0x00897B : 0xFFA000);
    final domeMat = three.MeshPhongMaterial({
      "color": domeColor,
      "emissive": isGoldTier ? 0x553300 : 0x00332A,
      "shininess": 95,
    });
    final darkMarble = three.MeshPhongMaterial({"color": 0xE0E0E0, "shininess": 40, "flatShading": true});

    final platform = three.Mesh(three.BoxGeometry(6.6, 0.5, 5.0), darkMarble);
    platform.position.y = 0.25;
    group.add(platform);

    final hall = three.Mesh(three.BoxGeometry(5.0, 2.2, 3.8), marbleMat);
    hall.position.y = 1.35;
    group.add(hall);

    for (int c = -2; c <= 2; c++) {
      final col = three.Mesh(three.CylinderGeometry(0.16, 0.2, 2.2, 10), marbleMat);
      col.position.set(c * 1.0, 1.35, 1.95);
      group.add(col);
    }

    final dome = three.Mesh(three.SphereGeometry(1.6, 18, 16), domeMat);
    dome.position.y = 4.7;
    dome.scale.set(1.0, 0.85, 1.0);
    group.add(dome);

    final finial = three.Mesh(three.ConeGeometry(0.18, 0.9, 8), goldMat);
    finial.position.y = 5.9;
    group.add(finial);

    final crescent = three.Mesh(three.TorusGeometry(0.22, 0.05, 6, 12, three.Math.pi * 1.4), goldMat);
    crescent.position.set(0, 6.45, 0);
    group.add(crescent);

    final minaretCount = tier == 1 ? 2 : 4;
    final minaretCoords = minaretCount == 2
        ? [[-1, 1], [1, 1]]
        : [[-1, -1], [1, -1], [-1, 1], [1, 1]];

    for (final mc in minaretCoords) {
      final mx = mc[0];
      final mz = mc[1];
      final mGroup = three.Group();
      mGroup.position.set(mx * 2.9, 0, mz * 2.2);

      final shaft = three.Mesh(three.CylinderGeometry(0.26, 0.36, 5.4, 12), marbleMat);
      shaft.position.y = 3.0;
      mGroup.add(shaft);

      final balcony1 = three.Mesh(three.TorusGeometry(0.44, 0.06, 6, 14), goldMat);
      balcony1.position.y = 4.8;
      balcony1.rotation.x = three.Math.pi / 2;
      mGroup.add(balcony1);

      final mDome = three.Mesh(three.SphereGeometry(0.36, 12, 10), domeMat);
      mDome.position.y = 5.7;
      mDome.scale.set(1.0, 1.3, 1.0);
      mGroup.add(mDome);

      final spire = three.Mesh(three.ConeGeometry(0.1, 0.8, 8), goldMat);
      spire.position.y = 6.4;
      mGroup.add(spire);

      group.add(mGroup);
    }

    final s = tier == 1 ? 0.75 : (tier == 2 ? 0.88 : (tier == 3 ? 1.0 : (tier == 4 ? 1.15 : 1.3)));
    group.scale.set(s, s, s);
    return group;
  }

  three.Object3D _buildProceduralPalace({int tier = 1}) {
    final group = three.Group();
    final isGoldTier = tier >= 5;

    final marbleMat = three.MeshPhongMaterial({
      "color": isGoldTier ? 0xFFF8E1 : 0xFFFFFF,
      "emissive": isGoldTier ? 0x443300 : 0x111111,
      "specular": 0xFFFFFF,
      "shininess": 85,
      "flatShading": true,
    });
    final goldMat = three.MeshPhongMaterial({
      "color": 0xFFA000,
      "emissive": 0x6A4400,
      "shininess": 100,
    });
    final darkMarble = three.MeshPhongMaterial({"color": 0xE0E0E0, "shininess": 40, "flatShading": true});
    final emeraldMat = three.MeshPhongMaterial({"color": 0x00C853, "emissive": 0x004D1A, "shininess": 90});

    final platform = three.Mesh(three.BoxGeometry(7.2, 0.6, 5.6), darkMarble);
    platform.position.y = 0.3;
    group.add(platform);

    final tier1 = three.Mesh(three.BoxGeometry(5.6, 2.4, 4.2), marbleMat);
    tier1.position.y = 1.5;
    group.add(tier1);

    final tier2 = three.Mesh(three.BoxGeometry(4.0, 1.8, 3.0), marbleMat);
    tier2.position.y = 3.6;
    group.add(tier2);

    final centerDome = three.Mesh(three.SphereGeometry(1.5, 18, 16), goldMat);
    centerDome.position.y = 5.3;
    centerDome.scale.set(1.0, 0.85, 1.0);
    group.add(centerDome);

    final spire = three.Mesh(three.ConeGeometry(0.18, 0.9, 8), goldMat);
    spire.position.y = 6.4;
    group.add(spire);

    final gem = three.Mesh(three.SphereGeometry(0.16, 8, 8), emeraldMat);
    gem.position.y = 7.0;
    group.add(gem);

    for (int sx in [-1, 1]) {
      final sideDome = three.Mesh(three.SphereGeometry(0.8, 14, 12), goldMat);
      sideDome.position.set(sx * 2.1, 3.2, 0);
      group.add(sideDome);
    }

    for (int mx in [-1, 1]) {
      for (int mz in [-1, 1]) {
        final tGroup = three.Group();
        tGroup.position.set(mx * 3.1, 0, mz * 2.4);

        final tower = three.Mesh(three.BoxGeometry(0.9, 4.8, 0.9), marbleMat);
        tower.position.y = 2.4;
        tGroup.add(tower);

        final tRoof = three.Mesh(three.ConeGeometry(0.65, 1.2, 4), goldMat);
        tRoof.position.y = 5.4;
        tRoof.rotation.y = three.Math.pi / 4;
        tGroup.add(tRoof);

        group.add(tGroup);
      }
    }

    final stair = three.Mesh(three.BoxGeometry(2.0, 0.4, 1.0), darkMarble);
    stair.position.set(0, 0.4, 2.3);
    group.add(stair);

    final portal = three.Mesh(three.BoxGeometry(1.4, 2.0, 0.1), goldMat);
    portal.position.set(0, 1.4, 2.12);
    group.add(portal);

    final s = tier == 1 ? 0.75 : (tier == 2 ? 0.88 : (tier == 3 ? 1.0 : (tier == 4 ? 1.15 : 1.3)));
    group.scale.set(s, s, s);
    return group;
  }

  three.Object3D _fallbackForType(RewardType type, {int tier = 1}) {
    switch (type) {
      case RewardType.palmTree:
        return _buildProceduralPalm(tier: tier);
      case RewardType.tree:
        return _buildProceduralTree(tier: tier);
      case RewardType.treasure:
        return _buildProceduralChest(tier: tier);
      case RewardType.house:
        return _buildProceduralHouse(tier: tier);
      case RewardType.palace:
        return _buildProceduralPalace(tier: tier);
      case RewardType.mosque:
        return _buildProceduralMosque(tier: tier);
    }
  }

  bool _isFarEnough(double x, double z) {
    if (x.abs() < 24.0 || x.abs() > 70.0 || z.abs() > 50.0) return false;

    for (final e in _savedEntries) {
      final dx = x - e.x;
      final dz = z - e.z;
      if ((dx * dx + dz * dz) < (_kMinSpacing * _kMinSpacing)) return false;
    }
    return true;
  }

  three.Vector3 _nextSpawnPosForType(RewardType type) {
    double x = 0;
    double z = 0;
    double y = 0;
    int tries = 0;

    switch (type) {
      case RewardType.palmTree:
        do {
          x = 28.0 + _rng.nextDouble() * 40.0;
          z = (_rng.nextDouble() * 90.0) - 45.0;
          tries++;
        } while (!_isFarEnough(x, z) && tries < 90);
        break;

      case RewardType.tree:
        do {
          x = -28.0 - _rng.nextDouble() * 40.0;
          z = (_rng.nextDouble() * 90.0) - 45.0;
          tries++;
        } while (!_isFarEnough(x, z) && tries < 90);
        break;

      case RewardType.palace:
      case RewardType.mosque:
        do {
          x = 40.0 + _rng.nextDouble() * 22.0;
          z = -18.0 - _rng.nextDouble() * 22.0;
          tries++;
        } while (!_isFarEnough(x, z) && tries < 90);
        break;

      case RewardType.house:
        do {
          x = -32.0 - _rng.nextDouble() * 30.0;
          z = 15.0 + _rng.nextDouble() * 30.0;
          tries++;
        } while (!_isFarEnough(x, z) && tries < 90);
        break;

      case RewardType.treasure:
        do {
          final isEast = _rng.nextBool();
          x = isEast ? 28.0 + _rng.nextDouble() * 36.0 : -28.0 - _rng.nextDouble() * 36.0;
          z = (_rng.nextDouble() * 75.0) - 37.5;
          tries++;
        } while (!_isFarEnough(x, z) && tries < 90);
        break;
    }

    y = _calculateGroundElevation(x, z);
    return three.Vector3(x, y, z);
  }

  // ignore: unused_element
  void _normalizeScale(three.Object3D obj, double targetHeight) {
    try {
      final box = three.Box3().setFromObject(obj);
      final size = box.getSize(three.Vector3());
      final h = size.y.abs();
      if (h > 0.001) {
        final s = targetHeight / h;
        obj.scale.set(s, s, s);
      }
    } catch (_) {}
  }

  // ignore: unused_element
  Future<three.Object3D?> _loadGLB(String path, RewardType type, {int tier = 1}) async {
    if (_glbCache.containsKey(path)) return _glbCache[path]!.clone(true);

    try {
      debugPrint('📥 Loading GLB: $path');
      final loader = three_jsm.GLTFLoader();
      final gltf = await loader.loadAsync(path).timeout(const Duration(seconds: 5));

      if (gltf == null || gltf["scene"] == null) {
        debugPrint('⚠️ GLB scene is null for $path');
        return null;
      }

      final scene = gltf["scene"];

      scene.traverse((child) {
        if (child is three.Mesh) {
          final materials = child.material is List ? child.material as List : [child.material];
          for (final mat in materials) {
            if (mat != null) {
              mat.side = three.DoubleSide;
              if (mat.map != null) {
                mat.transparent = true;
                mat.alphaTest = 0.4;
              }
              if (tier == 5) {
                mat.color.setHex(0xFFD700);
                mat.roughness = 0.25;
                mat.metalness = 0.85;
              }
              mat.needsUpdate = true;
            }
          }
        }
      });

      double baseTargetHeight = 10.0;
      if (tier == 1) baseTargetHeight = 7.0;
      if (tier == 2) baseTargetHeight = 9.0;
      if (tier == 3) baseTargetHeight = 11.0;
      if (tier == 4) baseTargetHeight = 14.0;
      if (tier == 5) baseTargetHeight = 18.0;

      _normalizeScale(scene, baseTargetHeight);
      _glbCache[path] = scene;
      debugPrint('✅ GLB cached: $path (Tier: $tier)');
      return scene.clone(true);
    } catch (e) {
      debugPrint('⚠️ GLB failed for $path: $e');
      return null;
    }
  }

  // ignore: unused_element
  Future<void> _upgradeToGLB(three.Group group, three.Object3D oldChild, RewardType type, int tier) async {
    final path = assetForRewardTypeAndTier(type, tier);
    try {
      final glb = await _loadGLB(path, type, tier: tier);
      if (glb != null && !_disposed && group.parent != null) {
        group.remove(oldChild);
        group.add(glb);
        debugPrint('⬆️ Model active: $type (Tier $tier)');
      }
    } catch (_) {}
  }

  void addModelAt({
    RewardType type = RewardType.palmTree,
    int tier = 1,
    double? x,
    double? z,
    double? y,
    bool fromStorage = false,
  }) {
    if (_animatedModels.length >= _kMaxSceneModels && !fromStorage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🌟 بلغت جنتك أوج نضارتها وازدهارها!',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'Amiri', fontSize: 16),
          ),
          backgroundColor: Color(0xFF1B5E20),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final calculatedPos = (x == null || z == null) && !fromStorage
        ? _nextSpawnPosForType(type)
        : three.Vector3(x ?? 0.0, _calculateGroundElevation(x ?? 0.0, z ?? 0.0), z ?? 0.0);

    final group = three.Group();
    group.position.set(calculatedPos.x, calculatedPos.y, calculatedPos.z);
    group.rotation.y = three.Math.randFloat(0, three.Math.pi * 2);

    final procedural = _fallbackForType(type, tier: tier);
    group.add(procedural);

    // 1. Soft Dark Contact Shadow Decal on the ground
    final shadowRadius = (type == RewardType.palace || type == RewardType.mosque)
        ? 4.5
        : (type == RewardType.house ? 2.5 : (type == RewardType.treasure ? 1.4 : 1.8));
    final shadowMat = three.MeshBasicMaterial({
      "color": 0x061F12,
      "transparent": true,
      "opacity": 0.42,
      "side": three.DoubleSide,
    });
    final shadowDecal = three.Mesh(three.CircleGeometry(radius: shadowRadius, segments: 14), shadowMat);
    shadowDecal.rotation.x = -three.Math.pi / 2;
    shadowDecal.position.y = 0.02;
    group.add(shadowDecal);

    // 2. Earthen Root Mound for Trees and Palms
    if (type == RewardType.tree || type == RewardType.palmTree) {
      final soilMat = three.MeshPhongMaterial({
        "color": 0x3E2723,
        "shininess": 10,
        "flatShading": true,
      });
      final soilMound = three.Mesh(three.DodecahedronGeometry(0.65), soilMat);
      soilMound.scale.set(1.4, 0.22, 1.4);
      soilMound.position.y = 0.06;
      group.add(soilMound);
    }

    _scene.add(group);
    _animatedModels.add(_AnimatedModel(group, DateTime.now().millisecondsSinceEpoch, type, tier: tier));

    if (!fromStorage) {
      _savedEntries.add(_SavedEntry(type, calculatedPos.x, calculatedPos.y, calculatedPos.z, tier: tier));
      _storage.saveRewards3D(_savedEntries.map((e) => e.toJson()).toList());
    }
  }

  void _undoLast() {
    if (_animatedModels.isEmpty) return;
    final last = _animatedModels.removeLast();
    _scene.remove(last.mesh);
    if (_savedEntries.isNotEmpty) {
      _savedEntries.removeLast();
      _storage.saveRewards3D(_savedEntries.map((e) => e.toJson()).toList());
    }
    setState(() {});
  }

  void _resetCamera() {
    _camera.position.set(38, 44, 52);
    _camera.lookAt(three.Vector3(0, 2, 0));
    _controls.target.set(0, 2, 0);
    _controls.update();
  }

  void _showRewardInfoModal(RewardType type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final count = _storage.getTotalByType(type);
        final tier = _calculateTier(count);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2818).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
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
                      GardenAssets.getIconAsset(type),
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${type.displayName} في رياض الجنة',
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFD700),
                            ),
                          ),
                          Text(
                            'المستوى الحالي: مرتبة النماء (Tier $tier)',
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
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoStat('الإجمالي المغروس', NumberFormatter.toArabic(count)),
                      _buildInfoStat('في المشهد 3D', NumberFormatter.toArabic(_animatedModels.where((m) => m.type == type).length)),
                      _buildInfoStat('المرتبة', 'المستوى $tier'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoStat(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Amiri',
            fontSize: 18,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071B12),
      body: Builder(
        builder: (BuildContext context) {
          initSize(context);
          return _buildSceneWithOverlay(context);
        },
      ),
    );
  }

  Widget _buildSceneWithOverlay(BuildContext context) {
    if (!_three3dRender.isInitialized) {
      return Container(
        color: const Color(0xFF071B12),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFFFD700)),
              SizedBox(height: 16),
              Text(
                '🌿 جارٍ فتح أبواب جنتك النورانية...',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 18,
                  color: Color(0xFFFFD700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final currentW = constraints.maxWidth;
        final currentH = constraints.maxHeight;
        _onResize(currentW, currentH);

        return Stack(
          children: [
            // 3D Canvas
            SizedBox(
              width: currentW,
              height: currentH,
              child: three_jsm.DomLikeListenable(
                key: _globalKey,
                builder: (BuildContext context) {
                  return Container(
                    width: currentW,
                    height: currentH,
                    color: const Color(0xFF071B12),
                    child: Builder(builder: (BuildContext context) {
                      if (kIsWeb) {
                        return HtmlElementView(viewType: _three3dRender.textureId!.toString());
                      } else {
                        return Texture(textureId: _three3dRender.textureId!);
                      }
                    }),
                  );
                },
              ),
            ),

            // Top Glassmorphic HUD
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildTopGlassBar(),
                ),
              ),
            ),

            // Bottom Controls & Filter Pills
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _buildBottomGlassPanel(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopGlassBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.25),
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
                    'جنتي ثلاثية الأبعاد 🌊🌴✨',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                  Text(
                    '${NumberFormatter.toArabic(_animatedModels.length)} غرسة مزروعة في رياض الجنة',
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
              tooltip: _soundEnabled ? 'كتم الأجواء الروحانية' : 'تشغيل الأجواء الروحانية',
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
              tooltip: _autoRotate ? 'إيقاف الدوران' : 'تشغيل الدوران',
              icon: Icon(
                _autoRotate ? Icons.sync : Icons.sync_disabled,
                color: _autoRotate ? const Color(0xFFFFD700) : Colors.white54,
                size: 20,
              ),
              onPressed: () => setState(() => _autoRotate = !_autoRotate),
            ),
            IconButton(
              tooltip: 'إعادة ضبط المنظور الآيزومتري',
              icon: const Icon(Icons.center_focus_strong, color: Color(0xFFFFD700), size: 20),
              onPressed: _resetCamera,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomGlassPanel() {
    final counts = <RewardType, int>{};
    for (final m in _animatedModels) {
      counts[m.type] = (counts[m.type] ?? 0) + 1;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Category Pills
        SizedBox(
          height: 42,
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
                      if (isSelected) {
                        _showRewardInfoModal(type);
                      }
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

        // Action Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2818).withValues(alpha: 0.85),
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
                    addModelAt(type: targetType, tier: 1);
                    setState(() {});
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
                if (_animatedModels.isNotEmpty)
                  TextButton.icon(
                    onPressed: _undoLast,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text(
                      'تراجع عن آخر غرسة',
                      style: TextStyle(fontFamily: 'GESSTwo', fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade300,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void render() {
    final gl = _three3dRender.gl;
    final now = DateTime.now().millisecondsSinceEpoch;
    _frameCount++;

    // 1. Model Growth Animation
    for (final am in _animatedModels) {
      final elapsed = now - am.bornAt;
      final t = (elapsed / 450.0).clamp(0.0, 1.0);
      final s = 0.2 + t * 0.8;
      am.mesh.scale.set(s, s, s);
    }

    // 2. Dynamic River Wave & Flow Current
    if (_waterMesh != null) {
      _waterMesh!.position.y = 0.15 + 0.02 * sin(_frameCount * 0.04);
    }
    for (int r = 0; r < _riverRipples.length; r++) {
      final rip = _riverRipples[r];
      rip.position.z += 0.08; // Flows downstream
      if (rip.position.z > (_kGroundD / 2)) {
        rip.position.z = -(_kGroundD / 2);
      }
    }

    // 3. Clouds Drifting
    for (int i = 0; i < _clouds.length; i++) {
      final cloud = _clouds[i];
      cloud.position.x += 0.035 * (1 + (i % 2) * 0.4);
      if (cloud.position.x > 180) {
        cloud.position.x = -180;
      }
    }

    // 4. Fluttering Falling Leaves & Petals in the Wind
    for (int l = 0; l < _fallingLeavesGroup.children.length; l++) {
      if (l < _leafVelocities.length) {
        final leaf = _fallingLeavesGroup.children[l];
        final vel = _leafVelocities[l];
        leaf.position.x += vel.x;
        leaf.position.y += vel.y + 0.008 * sin(_frameCount * 0.06 + l);
        leaf.position.z += vel.z;

        leaf.rotation.x += 0.03;
        leaf.rotation.y += 0.02;
        leaf.rotation.z += 0.015;

        // Reset if it hits ground or bounds
        if (leaf.position.y < 0.2 || leaf.position.x > 80 || leaf.position.z > 60) {
          leaf.position.set(
            -70 + _rng.nextDouble() * 40.0,
            18.0 + _rng.nextDouble() * 12.0,
            -50 + _rng.nextDouble() * 40.0,
          );
        }
      }
    }

    // 5. Floating Light Particles
    for (int i = 0; i < _particlesGroup.children.length; i++) {
      if (i < _particleInitialY.length && i < _particleSpeeds.length) {
        final p = _particlesGroup.children[i];
        final initY = _particleInitialY[i];
        final speed = _particleSpeeds[i];
        p.position.y = initY + sin(_frameCount * speed + i) * 1.5;
        p.position.x += 0.01 * sin(_frameCount * 0.02 + i);
      }
    }

    // 6. White Doves Flapping
    for (int b = 0; b < _birdsGroup.children.length; b++) {
      final bird = _birdsGroup.children[b];
      bird.position.x += 0.07;
      bird.position.z += 0.03 * sin(_frameCount * 0.03 + b);
      if (bird.position.x > 140) bird.position.x = -140;

      if (bird.children.length >= 2) {
        final flap = sin(_frameCount * 0.25 + b) * 0.4;
        bird.children[0].rotation.z = flap;
        bird.children[1].rotation.z = -flap;
      }
    }

    _renderer!.render(_scene, _camera);
    gl.flush();
    if (!kIsWeb) {
      _three3dRender.updateTexture(_sourceTexture);
    }
  }

  void initRenderer() {
    Map<String, dynamic> options = {
      "width": _width,
      "height": _height,
      "gl": _three3dRender.gl,
      "antialias": true,
      "canvas": _three3dRender.element,
    };
    _renderer = three.WebGLRenderer(options);
    _renderer!.setPixelRatio(_dpr);
    _renderer!.setSize(_width, _height, false);
    _renderer!.shadowMap.enabled = false;

    if (!kIsWeb) {
      var pars = three.WebGLRenderTargetOptions({
        "minFilter": three.LinearFilter,
        "magFilter": three.LinearFilter,
        "format": three.RGBAFormat,
      });
      _renderTarget = three.WebGLRenderTarget(
        (_width * _dpr).toInt(),
        (_height * _dpr).toInt(),
        pars,
      );
      _renderTarget.samples = 4;
      _renderer!.setRenderTarget(_renderTarget);
      _sourceTexture = _renderer!.getRenderTargetGLTexture(_renderTarget);
    }
  }

  void initScene() {
    initRenderer();
    initPage();
  }

  void initPage() {
    _scene = three.Scene();
    _scene.background = three.Color(0x134C37);
    _scene.fog = three.Fog(0x134C37, 95, 270);

    _camera = three.PerspectiveCamera(44, _width / _height, 0.1, 1000);
    _camera.position.set(38, 44, 52);
    _camera.lookAt(three.Vector3(0, 2, 0));

    _controls = three_jsm.OrbitControls(_camera, _globalKey);
    _controls.enableDamping = true;
    _controls.dampingFactor = 0.05;
    _controls.minDistance = 20;
    _controls.maxDistance = 150;
    _controls.maxPolarAngle = three.Math.pi / 2.15;
    _controls.target.set(0, 2, 0);

    final ambientLight = three.AmbientLight(0x4A6B56, 0.55);
    _scene.add(ambientLight);

    final goldenSunLight = three.DirectionalLight(0xFFE082, 1.35);
    goldenSunLight.position.set(55, 90, 45);
    _scene.add(goldenSunLight);

    final fillLight = three.DirectionalLight(0x388E3C, 0.4);
    fillLight.position.set(-50, 30, -40);
    _scene.add(fillLight);

    _buildAtmosphere();
    _buildSculptedTerrain();
    _buildRiverAndFeatures();
    _buildLightParticlesAndWildlife();

    for (final e in _savedEntries) {
      addModelAt(
        type: e.type,
        tier: e.tier,
        x: e.x,
        z: e.z,
        y: e.y,
        fromStorage: true,
      );
    }

    _syncFromDhikrRewards();

    if (_savedEntries.isEmpty && _animatedModels.isEmpty) {
      addModelAt(type: RewardType.palmTree, tier: 1);
      addModelAt(type: RewardType.tree, tier: 1);
      addModelAt(type: RewardType.treasure, tier: 1);
    }

    _loaded = true;
    setState(() {});
    animate();
  }

  void animate() {
    if (!mounted || _disposed) return;

    if (_loaded) {
      if (_autoRotate) {
        _controls.autoRotate = true;
        _controls.autoRotateSpeed = 0.4;
      } else {
        _controls.autoRotate = false;
      }
      _controls.update();
      render();
    }

    Future.delayed(const Duration(milliseconds: 16), animate);
  }

  @override
  void dispose() {
    _disposed = true;
    _three3dRender.dispose();
    super.dispose();
  }
}
