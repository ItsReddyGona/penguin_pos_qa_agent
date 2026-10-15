import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

typedef RegisterInputLoader =
    Future<QaRegisterInput> Function(String profileId);
typedef RegisterInputSaver =
    Future<void> Function(String profileId, QaRegisterInput input);

/// Profile-scoped register setup inputs (e.g. opening float cash amount).
class QaRegisterInput {
  const QaRegisterInput({
    this.openingFloatAmount = 0.0,
    this.closeTotalAmount = 1000.0,
    this.closeNotesMap = const <int, int>{},
    this.closeCoinsMap = const <int, int>{},
    this.notes = '',
    this.closeNotes = '',
  });

  static const double minAmount = 0.0;
  static const double maxAmount = 5000.0;
  static const double minCloseAmount = 0.0;
  static const double maxCloseAmount = 100000.0;

  static const List<int> supportedDenominations = <int>[
    500,
    200,
    100,
    50,
    20,
    10,
    5,
    2,
    1,
  ];

  static bool hasNotes(int denom) => denom >= 5;
  static bool hasCoins(int denom) => denom <= 20;

  static int computeTotalFromBreakdown(
    Map<int, int> notesMap,
    Map<int, int> coinsMap,
  ) {
    var total = 0;
    for (final d in supportedDenominations) {
      if (hasNotes(d)) {
        total += d * (notesMap[d] ?? 0);
      }
      if (hasCoins(d)) {
        total += d * (coinsMap[d] ?? 0);
      }
    }
    return total;
  }

  final double openingFloatAmount;
  final double closeTotalAmount;
  final Map<int, int> closeNotesMap;
  final Map<int, int> closeCoinsMap;
  final String notes;
  final String closeNotes;

  bool get isValid =>
      openingFloatAmount >= minAmount &&
      openingFloatAmount <= maxAmount &&
      closeTotalAmount >= minCloseAmount &&
      closeTotalAmount <= maxCloseAmount;

  QaRegisterInput copyWith({
    double? openingFloatAmount,
    double? closeTotalAmount,
    Map<int, int>? closeNotesMap,
    Map<int, int>? closeCoinsMap,
    String? notes,
    String? closeNotes,
  }) {
    return QaRegisterInput(
      openingFloatAmount: openingFloatAmount ?? this.openingFloatAmount,
      closeTotalAmount: closeTotalAmount ?? this.closeTotalAmount,
      closeNotesMap: closeNotesMap ?? this.closeNotesMap,
      closeCoinsMap: closeCoinsMap ?? this.closeCoinsMap,
      notes: notes ?? this.notes,
      closeNotes: closeNotes ?? this.closeNotes,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'openingFloatAmount': openingFloatAmount,
    'closeTotalAmount': closeTotalAmount,
    'closeNotesMap': closeNotesMap.map(
      (k, v) => MapEntry<String, int>(k.toString(), v),
    ),
    'closeCoinsMap': closeCoinsMap.map(
      (k, v) => MapEntry<String, int>(k.toString(), v),
    ),
    'notes': notes,
    'closeNotes': closeNotes,
  };

  factory QaRegisterInput.fromJson(Map<String, Object?> json) {
    final rawAmount = json['openingFloatAmount'];
    final amount = (rawAmount as num?)?.toDouble() ?? 0.0;

    final rawNotesMap = json['closeNotesMap'];
    final notesMap = <int, int>{};
    if (rawNotesMap is Map) {
      for (final entry in rawNotesMap.entries) {
        final key = int.tryParse(entry.key.toString());
        final val = (entry.value as num?)?.toInt();
        if (key != null &&
            val != null &&
            val >= 0 &&
            supportedDenominations.contains(key) &&
            hasNotes(key)) {
          notesMap[key] = val;
        }
      }
    }

    final rawCoinsMap = json['closeCoinsMap'];
    final coinsMap = <int, int>{};
    if (rawCoinsMap is Map) {
      for (final entry in rawCoinsMap.entries) {
        final key = int.tryParse(entry.key.toString());
        final val = (entry.value as num?)?.toInt();
        if (key != null &&
            val != null &&
            val >= 0 &&
            supportedDenominations.contains(key) &&
            hasCoins(key)) {
          coinsMap[key] = val;
        }
      }
    }

    final computedTotal = computeTotalFromBreakdown(notesMap, coinsMap);
    final rawClose = json['closeTotalAmount'];
    final fallbackClose = (rawClose as num?)?.toDouble() ?? 1000.0;
    final closeAmount = (notesMap.isNotEmpty || coinsMap.isNotEmpty)
        ? computedTotal.toDouble()
        : fallbackClose;

    return QaRegisterInput(
      openingFloatAmount: amount.clamp(minAmount, maxAmount),
      closeTotalAmount: closeAmount.clamp(minCloseAmount, maxCloseAmount),
      closeNotesMap: notesMap,
      closeCoinsMap: coinsMap,
      notes: (json['notes'] as String?) ?? '',
      closeNotes: (json['closeNotes'] as String?) ?? '',
    );
  }
}

abstract interface class QaRegisterInputRepository {
  Future<QaRegisterInput> read(String profileId);
  Future<void> write(String profileId, QaRegisterInput input);
  Future<void> clear(String profileId);
}

class SharedPreferencesQaRegisterInputRepository
    implements QaRegisterInputRepository {
  SharedPreferencesQaRegisterInputRepository({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesProvider;
  static final Map<String, QaRegisterInput> _memoryCache =
      <String, QaRegisterInput>{};

  static String _key(String profileId) =>
      'qa.profile.$profileId.suite.register.input.v1';

  @override
  Future<QaRegisterInput> read(String profileId) async {
    try {
      final prefs = await _preferencesProvider();
      final raw = prefs.getString(_key(profileId));
      if (raw == null || raw.trim().isEmpty) {
        return _memoryCache[profileId] ?? const QaRegisterInput();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const QaRegisterInput();
      final result = QaRegisterInput.fromJson(decoded.cast<String, Object?>());
      _memoryCache[profileId] = result;
      return result;
    } catch (_) {
      return _memoryCache[profileId] ?? const QaRegisterInput();
    }
  }

  @override
  Future<void> write(String profileId, QaRegisterInput input) async {
    _memoryCache[profileId] = input;
    try {
      final prefs = await _preferencesProvider();
      await prefs.setString(_key(profileId), jsonEncode(input.toJson()));
    } catch (_) {
      // In-memory cache ensures tests and non-persisted platforms continue to work.
    }
  }

  @override
  Future<void> clear(String profileId) async {
    _memoryCache.remove(profileId);
    try {
      final prefs = await _preferencesProvider();
      await prefs.remove(_key(profileId));
    } catch (_) {}
  }
}
