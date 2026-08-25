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

  Future<void> saveDhikrCount(String dhikrId, int count) async {
    final key = 'dhikr_count_$dhikrId';
    await _p.setInt(key, count);
    debugPrint('💾 Saved: $key = $count');
  }

  int getDhikrCount(String dhikrId) {
    final key = 'dhikr_count_$dhikrId';
    final value = _p.getInt(key) ?? 0;
    debugPrint('📂 Loaded: $key = $value');
    return value;
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
      return counts;
    } catch (e) {
      debugPrint('⚠️ getAllDhikrCounts() failed: $e');
      return {};
    }
  }

  Future<void> addReward(Reward reward) async {
    try {
      final rewards = getAllRewards();
      rewards.add(reward);
      final jsonList = rewards.map((r) => r.toJson()).toList();
      await _p.setString('rewards_list', jsonEncode(jsonList));
      debugPrint('💾 Saved: rewards_list (${rewards.length} items)');
    } catch (e) {
      debugPrint('⚠️ addReward() failed: $e');
    }
  }

  List<Reward> getAllRewards() {
    try {
      final jsonString = _p.getString('rewards_list');
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('📂 Loaded: rewards_list = empty');
        return [];
      }
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final rewards = jsonList
          .map((e) => Reward.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('📂 Loaded: rewards_list (${rewards.length} items)');
      return rewards;
    } catch (e) {
      debugPrint('⚠️ getAllRewards() failed: $e');
      return [];
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
    }
  }

  List<Map<String, dynamic>> getRewards3D() {
    try {
      final json = _p.getString('rewards_3d');
      if (json == null || json.isEmpty) return [];
      final list = jsonDecode(json) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('⚠️ getRewards3D() failed: $e');
      return [];
    }
  }

  bool hasSeenOnboarding() {
    return _p.getBool('has_seen_onboarding') ?? false;
  }

  Future<void> setOnboardingSeen([bool seen = true]) async {
    await _p.setBool('has_seen_onboarding', seen);
  }

  Future<void> clearAll() async {
    await _p.clear();
  }
}
