import 'dart:async';
import 'package:flutter/material.dart';
// ignore_for_file: unused_element
import 'package:flutter/scheduler.dart';
import '../models/reward.dart';
import '../models/reward_type.dart';
import '../data/adhkar_data.dart';
import '../services/storage_service.dart';
import '../utils/number_formatter.dart';
import '../utils/garden_assets.dart';
import '../utils/garden_world_manager.dart';
import 'jannati_3d_screen.dart';
import 'jannati_isometric_screen.dart';

const double _worldWidth = GardenWorldManager.worldWidth;
const double _worldHeight = GardenWorldManager.worldHeight;

class _PositionedReward {
  final Widget widget;
  final double y;
  _PositionedReward(this.widget, this.y);
}

class GardenScreen extends StatefulWidget {
  final VoidCallback? onNavigateToAdhkar;
  const GardenScreen({super.key, this.onNavigateToAdhkar});

  @override
  State<GardenScreen> createState() => GardenScreenState();
}

class GardenScreenState extends State<GardenScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final TransformationController _transformController =
      TransformationController();
  List<Reward> _rewards = [];
  Map<RewardType, int> _counts = {};
  late final AnimationController _cloudController;
  bool _isInitialized = false;
  Rect _visibleRect = Rect.zero;
  List<RewardPlacement> _placements = [];
  Timer? _viewportTimer;
  double _minScale = 1.0;

  @override
  void initState() {
    super.initState();
    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
    _transformController.addListener(_onViewportChanged);
    _transformController.addListener(_clampScale);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _centerOnGround();
    });
    _loadGarden();
  }

  void _centerOnGround() {
    final size = MediaQuery.of(context).size;
    final scale = size.height / _worldHeight;
    final tx = size.width / 2 - scale * _worldWidth / 2;
    final groundCenter = (GardenWorldManager.groundStart + GardenWorldManager.groundEnd) / 2;
    final ty = size.height / 2 - scale * groundCenter;
    _transformController.value = Matrix4(
      scale, 0, 0, 0,
      0, scale, 0, 0,
      0, 0, 1, 0,
      tx, ty, 0, 1,
    );
    _updateVisibleRect(size);
  }

  void _clampScale() {
    final matrix = _transformController.value;
    final currentScale = matrix.getMaxScaleOnAxis();
    if (currentScale < _minScale - 0.001) {
      final factor = _minScale / currentScale;
      _transformController.value = matrix.clone()..multiply(Matrix4.diagonal3Values(factor, factor, 1.0));
    }
  }

  void _onViewportChanged() {
    _viewportTimer?.cancel();
    _viewportTimer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      _updateVisibleRect(size);
      _clampViewport(size);
    });
  }

  void _clampViewport(Size size) {
    final matrix = _transformController.value;
    try {
      final tl = MatrixUtils.transformPoint(matrix, const Offset(0, 0));
      final br = MatrixUtils.transformPoint(matrix, Offset(_worldWidth, _worldHeight));

      double dx = 0, dy = 0;

      if (br.dx < size.width && tl.dx < 0) {
        dx = size.width - br.dx;
      }
      if (tl.dx > 0 && br.dx > size.width) {
        dx = -tl.dx;
      }

      if (br.dy < size.height && tl.dy < 0) {
        dy = size.height - br.dy;
      }
      if (tl.dy > 0 && br.dy > size.height) {
        dy = -tl.dy;
      }

      if (dx != 0 || dy != 0) {
        final newMatrix = matrix.clone();
        newMatrix.setTranslationRaw(
          newMatrix.storage[12] + dx,
          newMatrix.storage[13] + dy,
          newMatrix.storage[14],
        );
        _transformController.value = newMatrix;
      }
    } catch (_) {}
  }

  void _updateVisibleRect(Size size) {
    final matrix = _transformController.value;
    try {
      final inv = Matrix4.inverted(matrix);
      final tl = MatrixUtils.transformPoint(inv, Offset.zero);
      final br = MatrixUtils.transformPoint(inv, Offset(size.width, size.height));
      final newRect = Rect.fromPoints(tl, br).inflate(300);
      if (newRect != _visibleRect) {
        setState(() => _visibleRect = newRect);
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) _precacheImages();
  }

  Future<void> _precacheImages() async {
    final allPaths = <String>{
      GardenAssets.background,
      GardenAssets.sun,
      ...GardenAssets.clouds,
      for (final list in GardenAssets.variations.values)
        ...list,
    };
    try {
      await Future.wait(
        allPaths.map((p) =>
            precacheImage(AssetImage(p), context).catchError((_) {})),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {}
    if (mounted) setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _viewportTimer?.cancel();
    _cloudController.dispose();
    _transformController.removeListener(_onViewportChanged);
    _transformController.removeListener(_clampScale);
    _transformController.dispose();
    super.dispose();
  }

  void refreshGarden() => _loadGarden();

  void _loadGarden() {
    final rewards = _storage.getAllRewards();
    final map = <RewardType, int>{};
    for (final type in RewardType.values) { map[type] = 0; }
    for (final r in rewards) { map[r.type] = (map[r.type] ?? 0) + 1; }
    setState(() {
      _rewards = rewards;
      _placements = GardenWorldManager.placeRewards(rewards);
      _counts = map;
    });
  }

  void _showRewardSheet(Reward reward) {
    final dhikr = adhkarList.firstWhere(
      (d) => d.id == reward.dhikrId,
      orElse: () => adhkarList.first,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A3A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image(
                  image: ResizeImage(
                    AssetImage(GardenAssets.getRandomAsset(reward.type)),
                    width: 120,
                    height: 120,
                  ),
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${reward.type.arabicSingular} في جنتك',
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                dhikr.arabicText,
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 18,
                  color: Colors.white,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                NumberFormatter.formatTimeAgo(reward.earnedAt),
                style: const TextStyle(
                  fontFamily: 'GESSTwo',
                  fontSize: 13,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'أغلق',
                    style: TextStyle(
                      color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (!_isInitialized) return _buildLoading();
    if (_rewards.isEmpty) return _buildEmptyState(size);

    final minScaleX = size.width / _worldWidth;
    final minScaleY = size.height / _worldHeight;
    final minScale = minScaleX > minScaleY ? minScaleX : minScaleY;
    if (minScale != _minScale) _minScale = minScale;

    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 100,
        ),
        child: Stack(
          children: [
          Positioned.fill(
            child: Container(color: const Color(0xFF0D1F17)),
          ),
          InteractiveViewer(
            transformationController: _transformController,
            minScale: minScale,
            maxScale: (minScale * 8).clamp(2.5, 6.0),
            boundaryMargin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            constrained: false,
            onInteractionEnd: (details) {},
            child: SizedBox(
              width: _worldWidth,
              height: _worldHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildBackground(),
                  ..._buildVisibleRewards(),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.35,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0D1F17),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.3,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF0D1F17).withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildBottomPanel(size),
          _buildFab(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const JannatiIsometricScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      '2.5D 🌿',
                      style: TextStyle(
                        fontFamily: 'GESSTwo',
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const Jannati3DScreen()),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '3D',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  List<Widget> _buildVisibleRewards() {
    if (_placements.isEmpty) return [];
    if (_visibleRect == Rect.zero) return [];

    final visible = _placements.where((p) {
      final r = Rect.fromLTWH(
        p.x - p.size,
        p.y - p.size,
        p.size * 2 + 16,
        p.size * 2 + 16,
      );
      return r.overlaps(_visibleRect);
    }).toList();

    final entries = <_PositionedReward>[];
    for (final p in visible) {
      final cs = p.size + 20;
      final isLarge = p.priority >= 5;

      entries.add(_PositionedReward(
        Positioned(
          left: p.x - cs / 2,
          top: p.y - cs,
          child: GestureDetector(
            onTap: () => _showRewardSheet(p.reward),
            child: Opacity(
              opacity: p.depthOpacity,
              child: _buildRewardImage(p, isLarge),
            ),
          ),
        ),
        p.y,
      ));
    }

    entries.sort((a, b) => a.y.compareTo(b.y));
    return entries.map((e) => e.widget).toList();
  }

  Widget _buildRewardImage(RewardPlacement p, bool isLarge) {
    final size = p.size;
    final cs = size + 20;

    Widget image = Image(
      image: ResizeImage(
        AssetImage(p.assetPath),
        width: size.ceil(),
        height: size.ceil(),
      ),
      width: size,
      height: size,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
    );

    Widget imageContent = ClipRRect(
      borderRadius: BorderRadius.circular(isLarge ? 8 : 6),
      child: image,
    );

    if (isLarge) {
      imageContent = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            image,
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFF8E1).withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      radius: 0.7,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: cs,
      height: cs,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: cs * 0.15,
            right: cs * 0.15,
            child: Container(
              height: cs * 0.07,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: isLarge ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(cs * 0.035),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isLarge ? 0.12 : 0.06),
                    blurRadius: isLarge ? 10 : 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: (cs - size) / 2,
            right: (cs - size) / 2,
            child: imageContent,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(Size size) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 24,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.4, 0.85],
              ),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        '🌿 جنتي',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black54),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${NumberFormatter.toArabic(_rewards.length)} مكافأة',
                        style: const TextStyle(
                          fontFamily: 'GESSTwo',
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 6,
                      childAspectRatio: 3.8,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: RewardType.values.length,
                    itemBuilder: (context, index) {
                      final t = RewardType.values[index];
                      final count = _counts[t] ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: count > 0
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.emoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${t.arabicSingular} ${NumberFormatter.toArabic(count)}',
                                style: TextStyle(
                                  fontFamily: 'GESSTwo',
                                  fontSize: 11,
                                  color: count > 0
                                      ? Colors.white
                                      : Colors.white38,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Size size) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF87CEEB),
            Color(0xFFB0E2FF),
            Color(0xFFE0F4FF),
            Color(0xFF66BB6A),
            Color(0xFF43A047),
            Color(0xFF2E7D32),
          ],
          stops: [0.0, 0.15, 0.25, 0.45, 0.7, 1.0],
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                GardenAssets.variations[RewardType.palmTree]!.first,
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 20),
              const Text(
                'جنتك في انتظار ذكرك',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'ابدأ بقول سبحان الله لتزرع أول نخلة',
                style: TextStyle(
                  fontFamily: 'GESSTwo',
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: widget.onNavigateToAdhkar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'ابدأ الآن',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'GESSTwo',
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: const Color(0xFF0D1F17),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: Color(0xFFFFD700),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'جاري تحميل جنتك...',
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

  Widget _buildBackground() {
    return Positioned(
      left: 0,
      top: 0,
      width: _worldWidth,
      height: _worldHeight,
      child: Image.asset(
        GardenAssets.background,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildSun() {
    return Positioned(
      right: 30,
      top: 30,
      child: Image.asset(
        GardenAssets.sun,
        width: 80,
        height: 80,
      ),
    );
  }

  List<Widget> _buildClouds() {
    final speeds = [0.8, 1.2, 1.6];
    return List.generate(GardenAssets.clouds.length, (i) {
      final cloudWidth = 140.0 + i * 30.0;
      final top = 40.0 + i * 50.0;
      final speed = speeds[i];

      return Positioned(
        left: 0,
        top: top,
        child: AnimatedBuilder(
          animation: _cloudController,
          builder: (context, child) {
            final raw = _cloudController.value * speed;
            final wrapped = raw - raw.floorToDouble();
            final x = _worldWidth - wrapped * (_worldWidth + cloudWidth);
            return Transform.translate(
              offset: Offset(x, 0),
              child: child,
            );
          },
          child: Image.asset(
            GardenAssets.clouds[i],
            width: cloudWidth,
            height: cloudWidth * 0.4,
            fit: BoxFit.contain,
          ),
        ),
      );
    });
  }

  Widget _buildFab() {
    return Positioned(
      bottom: 110,
      left: 20,
      child: FloatingActionButton.extended(
        onPressed: widget.onNavigateToAdhkar,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: const Color(0xFFFFD700),
        icon: const Icon(Icons.menu_book),
        label: const Text('أذكار'),
      ),
    );
  }
}


