import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reward.dart';
import '../models/reward_type.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  static StorageService get instance => _instance;

  factory StorageService() => _instance;

  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      debugPrint('💾 SharedPreferences ready');
    } catch (e) {
      debugPrint('⚠️ StorageService.init() failed: $e');
    }
  }

  SharedPreferences get _p {
    if (_prefs == null) {
      debugPrint('⚠️ StorageService used before init()!');
      throw StateError('StorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // --- ⚡ In-Memory Buffer & Fast Batching System ---
  final Map<String, int> _pendingDhikrCounts = {};
  final List<Reward> _pendingRewards = [];
  List<Reward>? _cachedRewardsList;
  DateTime _lastFlushTime = DateTime.now();
  bool _isFlushing = false;

  /// Flushes all pending in-memory dhikr counts and rewards to persistent storage.
  Future<void> flushBuffer() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      // 1. Flush pending dhikr counts
      if (_pendingDhikrCounts.isNotEmpty) {
        final entries = Map<String, int>.from(_pendingDhikrCounts);
        _pendingDhikrCounts.clear();
        for (final entry in entries.entries) {
          await _p.setInt('dhikr_count_${entry.key}', entry.value);
        }
      }

      // 2. Flush pending rewards in a single serialized write
      if (_pendingRewards.isNotEmpty) {
        final currentRewards = getAllRewards();
        currentRewards.addAll(_pendingRewards);
        _pendingRewards.clear();
        _cachedRewardsList = currentRewards;
        final jsonList = currentRewards.map((r) => r.toJson()).toList();
        await _p.setString('rewards_list', jsonEncode(jsonList));
        debugPrint('💾 Buffer flushed: ${currentRewards.length} total rewards');
      }
      _lastFlushTime = DateTime.now();
    } catch (e) {
      debugPrint('⚠️ flushBuffer() failed: $e');
    } finally {
      _isFlushing = false;
    }
  }

  /// High-performance buffered increment for dhikr counter.
  /// Holds writes in memory and flushes periodically or on threshold to prevent I/O blocking.
  void recordDhikrBuffered(String dhikrId, int newTotalCount, Reward reward) {
    _pendingDhikrCounts[dhikrId] = newTotalCount;
    _pendingRewards.add(reward);

    // Keep memory cache up to date
    _cachedRewardsList?.add(reward);

    final now = DateTime.now();
    if (_pendingRewards.length >= 15 ||
        now.difference(_lastFlushTime).inSeconds >= 4) {
      unawaited(flushBuffer());
    }
  }

  Future<void> saveDhikrCount(String dhikrId, int count) async {
    final key = 'dhikr_count_$dhikrId';
    _pendingDhikrCounts.remove(dhikrId);
    try {
      await _p.setInt(key, count);
      debugPrint('💾 Saved: $key = $count');
    } catch (e) {
      debugPrint('⚠️ saveDhikrCount() failed for $key: $e');
      rethrow;
    }
  }

  int getDhikrCount(String dhikrId) {
    if (_pendingDhikrCounts.containsKey(dhikrId)) {
      return _pendingDhikrCounts[dhikrId]!;
    }
    final key = 'dhikr_count_$dhikrId';
    try {
      final value = _p.getInt(key) ?? 0;
      debugPrint('📂 Loaded: $key = $value');
      return value;
    } catch (e) {
      // قراءة آمنة: شاشة 2D المجمّدة تناديها بدون try/catch، فلا يجوز أن ترمي.
      debugPrint('⚠️ getDhikrCount() failed for $key: $e');
      return 0;
    }
  }

  Map<String, int> getAllDhikrCounts() {
    try {
      final keys = _p.getKeys();
      final counts = <String, int>{};
      for (final key in keys) {
        if (key.startsWith('dhikr_count_')) {
          final dhikrId = key.substring('dhikr_count_'.length);
          counts[dhikrId] = _p.getInt(key) ?? 0;
        }
      }
      // Overlay any pending in-memory counts
      counts.addAll(_pendingDhikrCounts);
      return counts;
    } catch (e) {
      debugPrint('⚠️ getAllDhikrCounts() failed: $e');
      return <String, int>{};
    }
  }

  Future<void> addReward(Reward reward) async {
    try {
      final rewards = getAllRewards();
      rewards.add(reward);
      _cachedRewardsList = rewards;
      final jsonList = rewards.map((r) => r.toJson()).toList();
      await _p.setString('rewards_list', jsonEncode(jsonList));
      debugPrint('💾 Saved: rewards_list (${rewards.length} items)');
    } catch (e) {
      debugPrint('⚠️ addReward() failed: $e');
      rethrow;
    }
  }

  /// Replaces the whole reward list in one write.
  ///
  /// Used by the temporary debug injector and by the permanent undo action;
  /// writing once avoids N sequential `setString` calls for large test counts.
  Future<void> saveRewards(List<Reward> rewards) async {
    try {
      _cachedRewardsList = List.from(rewards);
      _pendingRewards.clear();
      final jsonList = rewards.map((r) => r.toJson()).toList();
      await _p.setString('rewards_list', jsonEncode(jsonList));
      debugPrint('💾 Saved: rewards_list (${rewards.length} items)');
    } catch (e) {
      debugPrint('⚠️ saveRewards() failed: $e');
      rethrow;
    }
  }

  /// Removes and returns the newest reward, or null when the list is empty.
  Future<Reward?> removeLastReward() async {
    final rewards = getAllRewards();
    if (rewards.isEmpty) return null;
    final removed = rewards.removeLast();
    await saveRewards(rewards);
    return removed;
  }

  List<Reward> getAllRewards() {
    if (_cachedRewardsList != null) {
      final combined = List<Reward>.from(_cachedRewardsList!);
      if (_pendingRewards.isNotEmpty) {
        combined.addAll(_pendingRewards);
      }
      return combined;
    }

    try {
      final jsonString = _p.getString('rewards_list');
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('📂 Loaded: rewards_list = empty');
        _cachedRewardsList = [];
        return List<Reward>.from(_pendingRewards);
      }
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final rewards = jsonList
          .map((e) => Reward.fromJson(e as Map<String, dynamic>))
          .toList();
      _cachedRewardsList = List.from(rewards);
      debugPrint('📂 Loaded: rewards_list (${rewards.length} items)');
      if (_pendingRewards.isNotEmpty) {
        rewards.addAll(_pendingRewards);
      }
      return rewards;
    } catch (e) {
      // قراءة آمنة: بيانات مزرعة تالفة يجب ألا تُسقط التطبيق.
      debugPrint('⚠️ getAllRewards() failed — data may be corrupted: $e');
      return <Reward>[];
    }
  }

  int getTotalByType(RewardType type) {
    return getAllRewards().where((r) => r.type == type).length;
  }

  int getTotalRewards() {
    return getAllRewards().length;
  }

  Future<void> saveRewards3D(List<Map<String, dynamic>> items) async {
    try {
      await _p.setString('rewards_3d', jsonEncode(items));
      debugPrint('💾 Saved: rewards_3d (${items.length} items)');
    } catch (e) {
      debugPrint('⚠️ saveRewards3D() failed: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> getRewards3D() {
    try {
      final json = _p.getString('rewards_3d');
      if (json == null || json.isEmpty) return [];
      final list = jsonDecode(json) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      // قراءة آمنة: شاشة 3D تناديها مباشرة في initState.
      debugPrint('⚠️ getRewards3D() failed — data may be corrupted: $e');
      return <Map<String, dynamic>>[];
    }
  }

  bool hasSeenOnboarding() {
    return _p.getBool('has_seen_onboarding') ?? false;
  }

  Future<void> setOnboardingSeen([bool seen = true]) async {
    await _p.setBool('has_seen_onboarding', seen);
  }

  /// 🌙 فهرس صيغة الصلاة على النبي ﷺ المعروضة (يدور يوم الجمعة عند كل فتح).
  int getSalahNabiIndex() => _p.getInt('salah_nabi_rotation_index') ?? 0;

  Future<void> setSalahNabiIndex(int index) =>
      _p.setInt('salah_nabi_rotation_index', index);

  /// 🌅 وضع إضاءة عالم الجنة ثلاثي الأبعاد.
  /// 0 = تلقائي حسب ساعة الجهاز (الافتراضي)، 1 = فجر، 2 = ظهيرة، 3 = ليل.
  int getDayLightMode() => _p.getInt('day_light_mode') ?? 0;

  Future<void> setDayLightMode(int mode) => _p.setInt('day_light_mode', mode);

  /// 🎚️ جهارة أصوات التطبيق (0.0 – 1.0). الافتراضي: النصف، ويستطيع
  /// المستخدم رفعها أو خفضها بحرية.
  double getAudioVolume() => _p.getDouble('audio_volume') ?? 0.5;

  Future<void> setAudioVolume(double volume) =>
      _p.setDouble('audio_volume', volume.clamp(0.0, 1.0));

  /// 🌿 معرّفات طبقات الطبيعة المختارة للمزج (مثل `river_pure`).
  List<String> getMixLayers() =>
      _p.getStringList('mix_layers') ?? const <String>[];

  Future<void> setMixLayers(List<String> ids) =>
      _p.setStringList('mix_layers', ids);

  Future<void> clearAll() async {
    await _p.clear();
  }
}
