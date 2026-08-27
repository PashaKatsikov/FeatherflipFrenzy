import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chicken_skin.dart';
import '../models/egg_type.dart';
import '../models/quest.dart';
import '../models/upgrade.dart';
import '../models/yard_challenge.dart';
import '../models/zone.dart';

const String _saveKey = 'ff_save_v1';

/// Single source of truth for every piece of persistent player progress:
/// currency, upgrades, unlocked content, quest/achievement tracking and
/// settings. Backed by [SharedPreferences] as one JSON blob.
class AppState extends ChangeNotifier {
  int coins = 300;
  int lifetimeCoinsEarned = 0;

  final Map<String, int> upgradeLevels = {
    for (final t in UpgradeType.values) t.name: 0,
  };

  String selectedSkinId = kChickenSkins.first.id;
  final Set<String> ownedSkinIds = {kChickenSkins.first.id};

  int unlockedZoneIndex = 0;
  final Map<String, int> zoneStars = {};

  int totalEggsDelivered = 0;
  int totalRescueDashUses = 0;
  int totalGoldenEggsDelivered = 0;
  int totalRoundsCompleted = 0;
  int bestStreakEver = 0;

  final Map<String, int> dailyProgress = {};
  final Set<String> dailyClaimed = {};
  String lastDailyResetDate = '';

  /// Date (yyyy-MM-dd) the free daily gift was last collected.
  String lastDailyGiftDate = '';

  String dailyChallengeZoneId = '';
  String dailyChallengeKind = '';
  String lastDailyChallengeDate = '';
  String lastDailyChallengeClaimDate = '';

  final Set<String> achievementClaimed = {};

  bool sfxOn = true;
  bool vibrationOn = true;
  bool highGraphics = true;
  bool hasSeenTutorial = false;

  /// Absolute path to the player's profile photo in the documents directory.
  String? profilePhotoPath;
  int profilePhotoNonce = 0;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Writes are coalesced: gameplay awards coins many times per round and a
  /// synchronous disk write per coin caused visible hitches.
  Timer? _saveDebounce;

  AppState() {
    _load();
  }

  // ---------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        coins = json['coins'] as int? ?? coins;
        lifetimeCoinsEarned = json['lifetimeCoinsEarned'] as int? ?? 0;
        (json['upgradeLevels'] as Map<String, dynamic>?)?.forEach((k, v) {
          upgradeLevels[k] = v as int;
        });
        selectedSkinId = json['selectedSkinId'] as String? ?? selectedSkinId;
        ownedSkinIds
          ..clear()
          ..addAll(((json['ownedSkinIds'] as List?) ?? []).map((e) => e as String));
        if (ownedSkinIds.isEmpty) ownedSkinIds.add(kChickenSkins.first.id);
        unlockedZoneIndex = json['unlockedZoneIndex'] as int? ?? 0;
        (json['zoneStars'] as Map<String, dynamic>?)?.forEach((k, v) {
          zoneStars[k] = v as int;
        });
        totalEggsDelivered = json['totalEggsDelivered'] as int? ?? 0;
        totalRescueDashUses = json['totalRescueDashUses'] as int? ?? 0;
        totalGoldenEggsDelivered = json['totalGoldenEggsDelivered'] as int? ?? 0;
        totalRoundsCompleted = json['totalRoundsCompleted'] as int? ?? 0;
        bestStreakEver = json['bestStreakEver'] as int? ?? 0;
        (json['dailyProgress'] as Map<String, dynamic>?)?.forEach((k, v) {
          dailyProgress[k] = v as int;
        });
        dailyClaimed
          ..clear()
          ..addAll(((json['dailyClaimed'] as List?) ?? []).map((e) => e as String));
        lastDailyResetDate = json['lastDailyResetDate'] as String? ?? '';
        lastDailyGiftDate = json['lastDailyGiftDate'] as String? ?? '';
        dailyChallengeZoneId = json['dailyChallengeZoneId'] as String? ?? '';
        dailyChallengeKind = json['dailyChallengeKind'] as String? ?? '';
        lastDailyChallengeDate = json['lastDailyChallengeDate'] as String? ?? '';
        lastDailyChallengeClaimDate = json['lastDailyChallengeClaimDate'] as String? ?? '';
        achievementClaimed
          ..clear()
          ..addAll(((json['achievementClaimed'] as List?) ?? []).map((e) => e as String));
        sfxOn = json['sfxOn'] as bool? ?? true;
        vibrationOn = json['vibrationOn'] as bool? ?? true;
        highGraphics = json['highGraphics'] as bool? ?? true;
        hasSeenTutorial = json['hasSeenTutorial'] as bool? ?? false;
        profilePhotoPath = json['profilePhotoPath'] as String?;
        profilePhotoNonce = json['profilePhotoNonce'] as int? ?? 0;
      }
    } catch (_) {
      // Corrupt save data should never crash the game; fall back to defaults.
    }
    await _reconcileProfilePhoto();
    _maybeResetDaily();
    _rollDailyChallengeIfNeeded();
    _loaded = true;
    notifyListeners();
  }

  /// Schedules a save shortly in the future, collapsing bursts of mutations
  /// (a streak of deliveries, quest claims) into a single disk write.
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    final prefs = await SharedPreferences.getInstance();
    final json = <String, dynamic>{
      'coins': coins,
      'lifetimeCoinsEarned': lifetimeCoinsEarned,
      'upgradeLevels': upgradeLevels,
      'selectedSkinId': selectedSkinId,
      'ownedSkinIds': ownedSkinIds.toList(),
      'unlockedZoneIndex': unlockedZoneIndex,
      'zoneStars': zoneStars,
      'totalEggsDelivered': totalEggsDelivered,
      'totalRescueDashUses': totalRescueDashUses,
      'totalGoldenEggsDelivered': totalGoldenEggsDelivered,
      'totalRoundsCompleted': totalRoundsCompleted,
      'bestStreakEver': bestStreakEver,
      'dailyProgress': dailyProgress,
      'dailyClaimed': dailyClaimed.toList(),
      'lastDailyResetDate': lastDailyResetDate,
      'lastDailyGiftDate': lastDailyGiftDate,
      'dailyChallengeZoneId': dailyChallengeZoneId,
      'dailyChallengeKind': dailyChallengeKind,
      'lastDailyChallengeDate': lastDailyChallengeDate,
      'lastDailyChallengeClaimDate': lastDailyChallengeClaimDate,
      'achievementClaimed': achievementClaimed.toList(),
      'sfxOn': sfxOn,
      'vibrationOn': vibrationOn,
      'highGraphics': highGraphics,
      'hasSeenTutorial': hasSeenTutorial,
      'profilePhotoPath': profilePhotoPath,
      'profilePhotoNonce': profilePhotoNonce,
    };
    await prefs.setString(_saveKey, jsonEncode(json));
  }

  static String get _today => DateTime.now().toIso8601String().substring(0, 10);

  bool _maybeResetDaily() {
    if (lastDailyResetDate == _today) return false;
    lastDailyResetDate = _today;
    dailyProgress.clear();
    dailyClaimed.clear();
    return true;
  }

  /// Re-checks the daily rollover. Called when the app comes back to the
  /// foreground so a session left open past midnight still refreshes quests.
  void refreshDailyState() {
    if (!_loaded) return;
    var changed = _maybeResetDaily();
    if (_rollDailyChallengeIfNeeded()) changed = true;
    if (changed) {
      notifyListeners();
      _scheduleSave();
    }
  }

  // ---------------------------------------------------------------------
  // Free daily gift
  // ---------------------------------------------------------------------

  static const int dailyGiftAmount = 150;

  bool get dailyGiftAvailable => lastDailyGiftDate != _today;

  bool claimDailyGift() {
    if (!dailyGiftAvailable) return false;
    lastDailyGiftDate = _today;
    addCoins(dailyGiftAmount);
    notifyListeners();
    _scheduleSave();
    return true;
  }

  // ---------------------------------------------------------------------
  // Daily Yard Challenge
  // ---------------------------------------------------------------------

  YardChallenge? get todaysChallenge {
    final kind = YardChallenge.kindFromName(dailyChallengeKind);
    if (kind == null || dailyChallengeZoneId.isEmpty) return null;
    return YardChallenge(kind: kind, zoneId: dailyChallengeZoneId);
  }

  YardChallenge? challengeFor(ZoneDef zone) {
    final challenge = todaysChallenge;
    if (challenge == null || challenge.zoneId != zone.id) return null;
    return challenge;
  }

  bool get dailyChallengeRewardAvailable => lastDailyChallengeClaimDate != _today;

  bool _rollDailyChallengeIfNeeded() {
    if (lastDailyChallengeDate == _today &&
        dailyChallengeZoneId.isNotEmpty &&
        YardChallenge.kindFromName(dailyChallengeKind) != null) {
      return false;
    }
    lastDailyChallengeDate = _today;
    final rng = math.Random(_today.hashCode);
    dailyChallengeZoneId = kZones[rng.nextInt(kZones.length)].id;
    dailyChallengeKind = YardChallengeKind.values[rng.nextInt(YardChallengeKind.values.length)].name;
    return true;
  }

  /// Grants the one-a-day Yard Challenge bonus. Returns false if it was
  /// already collected today.
  bool claimDailyChallengeReward() {
    if (!dailyChallengeRewardAvailable) return false;
    lastDailyChallengeClaimDate = _today;
    addCoins(YardChallengeRules.completionBonus);
    notifyListeners();
    _save();
    return true;
  }

  // ---------------------------------------------------------------------
  // Currency & upgrades
  // ---------------------------------------------------------------------

  void addCoins(int amount) {
    if (amount <= 0) return;
    coins += amount;
    lifetimeCoinsEarned += amount;
    _trackDaily(QuestMetric.coinsCollected, amount);
    notifyListeners();
    _scheduleSave();
  }

  bool spendCoins(int amount) {
    if (coins < amount) return false;
    coins -= amount;
    notifyListeners();
    _scheduleSave();
    return true;
  }

  int upgradeLevel(UpgradeType type) => upgradeLevels[type.name] ?? 0;

  bool canUpgrade(UpgradeType type) {
    final def = kUpgradeDefs[type]!;
    final level = upgradeLevel(type);
    if (level >= def.maxLevel) return false;
    return coins >= def.costForLevel(level);
  }

  bool purchaseUpgrade(UpgradeType type) {
    final def = kUpgradeDefs[type]!;
    final level = upgradeLevel(type);
    if (level >= def.maxLevel) return false;
    final cost = def.costForLevel(level);
    if (!spendCoins(cost)) return false;
    upgradeLevels[type.name] = level + 1;
    notifyListeners();
    _save();
    return true;
  }

  double dashSpeedMultiplier() => 1 + kUpgradeDefs[UpgradeType.dashSpeed]!.bonusAtLevel(upgradeLevel(UpgradeType.dashSpeed));
  double dashRangeMultiplier() => 1 + kUpgradeDefs[UpgradeType.dashRange]!.bonusAtLevel(upgradeLevel(UpgradeType.dashRange));
  double hitPowerMultiplier() => 1 + kUpgradeDefs[UpgradeType.hitPower]!.bonusAtLevel(upgradeLevel(UpgradeType.hitPower));
  double eggControlMultiplier() => 1 + kUpgradeDefs[UpgradeType.eggControl]!.bonusAtLevel(upgradeLevel(UpgradeType.eggControl));
  int rescueChargesForRound() => 2 + upgradeLevel(UpgradeType.rescueCharges);

  // ---------------------------------------------------------------------
  // Chicken skins
  // ---------------------------------------------------------------------

  bool ownsSkin(String id) => ownedSkinIds.contains(id);

  bool buySkin(ChickenSkin skin) {
    if (ownsSkin(skin.id)) return false;
    if (!spendCoins(skin.price)) return false;
    ownedSkinIds.add(skin.id);
    notifyListeners();
    _save();
    return true;
  }

  void selectSkin(String id) {
    if (!ownsSkin(id)) return;
    selectedSkinId = id;
    notifyListeners();
    _save();
  }

  ChickenSkin get selectedSkin => kChickenSkins.firstWhere((s) => s.id == selectedSkinId, orElse: () => kChickenSkins.first);

  // ---------------------------------------------------------------------
  // Zones & progression
  // ---------------------------------------------------------------------

  bool isZoneUnlocked(int index) => index <= unlockedZoneIndex;

  int starsFor(String zoneId) => zoneStars[zoneId] ?? 0;

  /// Returns true if this round result unlocked a brand-new zone.
  bool reportZoneResult(ZoneDef zone, int stars) {
    final prevStars = starsFor(zone.id);
    if (stars > prevStars) {
      zoneStars[zone.id] = stars;
    }
    var unlockedNew = false;
    if (stars >= 1 && zone.index == unlockedZoneIndex && zone.index + 1 < kZones.length) {
      unlockedZoneIndex = zone.index + 1;
      unlockedNew = true;
    }
    totalRoundsCompleted += 1;
    _trackDaily(QuestMetric.roundsCompleted, 1);
    notifyListeners();
    _save();
    return unlockedNew;
  }

  // ---------------------------------------------------------------------
  // Gameplay event tracking (feeds quests/achievements)
  // ---------------------------------------------------------------------

  void recordEggDelivered(EggType type) {
    totalEggsDelivered += 1;
    _trackDaily(QuestMetric.eggsDelivered, 1);
    if (type == EggType.gold) {
      totalGoldenEggsDelivered += 1;
      _trackDaily(QuestMetric.goldenEggsDelivered, 1);
    }
    notifyListeners();
  }

  void recordRescueDashUse() {
    totalRescueDashUses += 1;
    _trackDaily(QuestMetric.rescueDashUses, 1);
    notifyListeners();
  }

  void recordStreak(int streak) {
    if (streak > bestStreakEver) {
      bestStreakEver = streak;
      notifyListeners();
    }
  }

  void persistAfterRound() => _save();

  void _trackDaily(QuestMetric metric, int amount) {
    for (final quest in kDailyQuestPool) {
      if (quest.metric == metric) {
        dailyProgress[quest.id] = (dailyProgress[quest.id] ?? 0) + amount;
      }
    }
  }

  int dailyQuestProgress(QuestDef quest) => dailyProgress[quest.id] ?? 0;

  bool isDailyClaimable(QuestDef quest) =>
      !dailyClaimed.contains(quest.id) && dailyQuestProgress(quest) >= quest.target;

  bool claimDailyQuest(QuestDef quest) {
    if (!isDailyClaimable(quest)) return false;
    dailyClaimed.add(quest.id);
    addCoins(quest.reward);
    notifyListeners();
    _save();
    return true;
  }

  int lifetimeMetric(QuestMetric metric) => switch (metric) {
        QuestMetric.eggsDelivered => totalEggsDelivered,
        QuestMetric.coinsCollected => lifetimeCoinsEarned,
        QuestMetric.rescueDashUses => totalRescueDashUses,
        QuestMetric.goldenEggsDelivered => totalGoldenEggsDelivered,
        QuestMetric.roundsCompleted => totalRoundsCompleted,
        QuestMetric.bestStreakEver => bestStreakEver,
      };

  bool isAchievementClaimable(QuestDef quest) =>
      !achievementClaimed.contains(quest.id) && lifetimeMetric(quest.metric) >= quest.target;

  bool claimAchievement(QuestDef quest) {
    if (!isAchievementClaimable(quest)) return false;
    achievementClaimed.add(quest.id);
    addCoins(quest.reward);
    notifyListeners();
    _save();
    return true;
  }

  // ---------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------

  void setSfxOn(bool value) {
    sfxOn = value;
    notifyListeners();
    _save();
  }

  void setVibrationOn(bool value) {
    vibrationOn = value;
    notifyListeners();
    _save();
  }

  void setHighGraphics(bool value) {
    highGraphics = value;
    notifyListeners();
    _save();
  }

  void markTutorialSeen() {
    if (hasSeenTutorial) return;
    hasSeenTutorial = true;
    notifyListeners();
    _save();
  }

  // ---------------------------------------------------------------------
  // Profile photo
  // ---------------------------------------------------------------------

  static const _profileFileName = 'ff_profile.jpg';

  Future<File> _profileFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_profileFileName');
  }

  Future<void> _reconcileProfilePhoto() async {
    final path = profilePhotoPath;
    if (path == null || path.isEmpty) return;
    if (File(path).existsSync()) return;
    try {
      final fallback = await _profileFile();
      if (fallback.existsSync()) {
        profilePhotoPath = fallback.path;
        return;
      }
    } catch (_) {}
    profilePhotoPath = null;
  }

  Future<bool> setProfilePhotoFromPath(String sourcePath) async {
    try {
      final dest = await _profileFile();
      await File(sourcePath).copy(dest.path);
      profilePhotoPath = dest.path;
      profilePhotoNonce += 1;
      notifyListeners();
      await _save();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearProfilePhoto() async {
    try {
      final file = await _profileFile();
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
    profilePhotoPath = null;
    profilePhotoNonce += 1;
    notifyListeners();
    await _save();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }
}
