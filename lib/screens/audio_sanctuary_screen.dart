import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/spiritual_audio_service.dart';
import '../widgets/islamic_pattern_overlay.dart';

class AudioSanctuaryScreen extends StatefulWidget {
  const AudioSanctuaryScreen({super.key});

  @override
  State<AudioSanctuaryScreen> createState() => _AudioSanctuaryScreenState();
}

class _AudioSanctuaryScreenState extends State<AudioSanctuaryScreen>
    with SingleTickerProviderStateMixin {
  final SpiritualAudioService _audioService = SpiritualAudioService();

  int _selectedTab = 0; // 0 = Nature, 1 = Quran
  AudioItem? _activeItem;
  bool _isPlaying = false;
  int _sleepTimerMinutes = 0;
  Timer? _sleepTimer;

  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _isPlaying = _audioService.isPlaying;
    _activeItem = SpiritualAudioService.natureTracks.first;

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _rippleController.dispose();
    super.dispose();
  }

  void _togglePlay(AudioItem item) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _activeItem = item;
    });

    await _audioService.toggle(item);
    if (mounted) {
      setState(() {
        _isPlaying = _audioService.isPlaying;
      });
    }
  }

  void _setSleepTimer(int minutes) {
    HapticFeedback.selectionClick();
    _sleepTimer?.cancel();

    setState(() {
      _sleepTimerMinutes = minutes;
    });

    if (minutes > 0) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _sleepTimerMinutes = 0;
          });
          _audioService.stop();
          _showSpiritualSnackbar('انتهى مؤقت السكون، نوم هنيء وذكر مبارك 🌙');
        }
      });

      _showSpiritualSnackbar('تم ضبط مؤقت السكون على $minutes دقيقة ⏱️');
    }
  }

  void _showSpiritualSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'GESSTwo',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0D2818),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFFD700), width: 1.4),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentList = _selectedTab == 0
        ? SpiritualAudioService.natureTracks
        : SpiritualAudioService.quranTracks;
    final displayItem = _activeItem ?? currentList.first;

    return Scaffold(
      backgroundColor: const Color(0xFF03140C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2818).withValues(alpha: 0.95),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'إذاعة السكينة ورياض الجنة 🎵✨',
          style: TextStyle(
            fontFamily: 'Amiri',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // 1. Hero Player Card with Ripple Wave
            _buildVisualizerCard(displayItem),

            const SizedBox(height: 16),

            // 2. Sleep Timer Strip
            _buildSleepTimerStrip(),

            const SizedBox(height: 18),

            // 3. Tab Selector (أصوات الجنة vs التلاوات القرآنية)
            _buildCategoryTabs(),

            const SizedBox(height: 14),

            // 4. Tracks List
            ...currentList.map((item) {
              final isCurrent = _activeItem?.id == item.id;
              final isThisPlaying = isCurrent && _isPlaying;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => _togglePlay(item),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFF0D2818)
                          : Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFFFFD700)
                            : Colors.white.withValues(alpha: 0.15),
                        width: isCurrent ? 1.8 : 1.0,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent
                                ? const Color(0xFF1B5E20)
                                : Colors.white.withValues(alpha: 0.1),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFFFFD700)
                                  : Colors.white24,
                            ),
                          ),
                          child: Center(
                            child: Text(item.icon, style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? const Color(0xFFFFD700) : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'GESSTwo',
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isThisPlaying
                                ? const Color(0xFFFFD700)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            isThisPlaying ? Icons.pause : Icons.play_arrow,
                            color: isThisPlaying ? Colors.black : Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(0, '🌿 أصوات رياض الجنة'),
          ),
          Expanded(
            child: _buildTabButton(1, '📖 تلاوات القرآن الكريم'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTab == index;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedTab = index;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'GESSTwo',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildVisualizerCard(AudioItem item) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white, // 🤍 Pure White Ceramic Player Card
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFFFD700), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          IslamicPatternOverlay(opacity: 0.08),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
            child: Column(
              children: [
          // Animated Ripple Disc
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isPlaying)
                  AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, _) {
                      final wave = _rippleController.value;
                      return Container(
                        width: 90 + wave * 50,
                        height: 90 + wave * 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF2E7D32).withValues(alpha: 1.0 - wave),
                            width: 2.0,
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1B5E20),
                        Color(0xFF0C301A),
                      ],
                    ),
                    border: Border.all(color: const Color(0xFFFFD700), width: 2.0),
                  ),
                  child: Center(
                    child: Text(item.icon, style: const TextStyle(fontSize: 38)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A2E18),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'GESSTwo',
              fontSize: 11,
              color: Color(0xFF2E7D32),
            ),
          ),

          const SizedBox(height: 18),

          // Main Play / Pause Button
          GestureDetector(
            onTap: () => _togglePlay(item),
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1B5E20),
                    Color(0xFF2E7D32),
                  ],
                ),
                border: Border.all(color: const Color(0xFFFFD700), width: 2.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: const Color(0xFFFFD700),
                size: 36,
              ),
            ),
          ),
        ],
      ),
          ), // Padding
        ], // Stack
      ),
    );
  }

  Widget _buildSleepTimerStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.bedtime_outlined, color: Color(0xFFFFD700), size: 18),
              SizedBox(width: 6),
              Text(
                'مؤقت السكون:',
                style: TextStyle(
                  fontFamily: 'GESSTwo',
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [0, 15, 30, 60].map((mins) {
              final isSel = _sleepTimerMinutes == mins;
              final label = mins == 0 ? 'إيقاف' : '$mins د';

              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: InkWell(
                  onTap: () => _setSleepTimer(mins),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF1B5E34).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'GESSTwo',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
