import 'dart:convert';

/// Immutable order automation state returned by the PenguinPOS target.
class OrderStateSnapshot {
  const OrderStateSnapshot({
    required this.phase,
    required this.cartRevision,
    required this.mutationId,
    required this.entryReady,
    required this.weightRequired,
    required this.cartReady,
    required this.cartItemCount,
    this.scanStatus = 'unknown',
    this.resolvedSku,
    this.lastMutationSku,
    this.lastMutationStatus,
    this.lastMutationType,
    this.lastMutationQuantity,
    this.error,
  });

  final String phase;
  final int cartRevision;
  final int mutationId;
  final bool entryReady;
  final bool weightRequired;
  final bool cartReady;
  final int cartItemCount;
  final String scanStatus;
  final String? resolvedSku;
  final String? lastMutationSku;
  final String? lastMutationStatus;
  final String? lastMutationType;
  final double? lastMutationQuantity;
  final String? error;

  /// The scan API may resolve a short entered code to a canonical SKU.
  bool mutationAcceptedForScan(String enteredSku) {
    final entered = enteredSku.trim();
    final resolved = resolvedSku?.trim();
    final mutation = lastMutationSku?.trim();
    if (lastMutationStatus != 'accepted' || mutation == null) return false;
    final resolvedMatch =
        scanStatus == 'success' && resolved != null && mutation == resolved;
    return mutation == entered || resolvedMatch;
  }

  /// Whether the latest target mutation belongs to the entered or resolved
  /// SKU, regardless of whether it is accepted or awaiting weight.
  bool mutationMatchesScan(String enteredSku) {
    final entered = enteredSku.trim();
    final resolved = resolvedSku?.trim();
    final mutation = lastMutationSku?.trim();
    if (mutation == null) return false;
    return mutation == entered ||
        (scanStatus == 'success' && resolved != null && mutation == resolved);
  }

  bool skuAccepted(String sku) => mutationAcceptedForScan(sku);

  factory OrderStateSnapshot.fromJson(Map<String, dynamic> json) {
    int intValue(String key) {
      final value = json[key];
      return value is num ? value.toInt() : 0;
    }

    bool boolValue(String key) => json[key] == true;

    return OrderStateSnapshot(
      phase: json['phase'] as String? ?? 'unavailable',
      cartRevision: intValue('cartRevision'),
      mutationId: intValue('mutationId'),
      entryReady: boolValue('entryReady'),
      weightRequired: boolValue('weightRequired'),
      cartReady: boolValue('cartReady'),
      cartItemCount: intValue('cartItemCount'),
      scanStatus: json['scanStatus'] as String? ?? 'unknown',
      resolvedSku: json['resolvedSku'] as String?,
      lastMutationSku: json['lastMutationSku'] as String?,
      lastMutationStatus: json['lastMutationStatus'] as String?,
      lastMutationType: json['lastMutationType'] as String?,
      lastMutationQuantity: (json['lastMutationQuantity'] as num?)?.toDouble(),
      error: json['error'] as String?,
    );
  }

  /// Parses either the full order snapshot or the compact operation snapshot.
  static OrderStateSnapshot? fromResponse(String? response) {
    if (response == null ||
        response.isEmpty ||
        response.contains('No requestData')) {
      return null;
    }
    try {
      final decoded = jsonDecode(response);
      if (decoded is! Map) return null;
      final snapshot = OrderStateSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return snapshot.phase == 'unavailable' ? null : snapshot;
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() =>
      'OrderStateSnapshot(phase=$phase, '
      'revision=$cartRevision, mutation=$mutationId, '
      'scan=$scanStatus/$resolvedSku, '
      'sku=$lastMutationSku, status=$lastMutationStatus)';
}
