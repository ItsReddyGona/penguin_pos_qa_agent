/// Declarative scenario defining inputs for cash register testing.
class RegisterScenario {
  const RegisterScenario({
    this.id = 'open_register',
    this.name = 'Open Register Flow',
    this.openingFloatAmount = 0.0,
    this.closeTotalAmount = 1000.0,
    this.closeNotesMap = const <int, int>{},
    this.closeCoinsMap = const <int, int>{},
    this.notes = '',
  });

  final String id;
  final String name;
  final double openingFloatAmount;
  final double closeTotalAmount;
  final Map<int, int> closeNotesMap;
  final Map<int, int> closeCoinsMap;
  final String notes;

  static const double minFloat = 0.0;
  static const double maxFloat = 5000.0;

  int get effectiveFloatAmount =>
      openingFloatAmount.clamp(minFloat, maxFloat).toInt();

  int get effectiveCloseTotalAmount => closeTotalAmount.toInt();

  RegisterScenario copyWith({
    String? id,
    String? name,
    double? openingFloatAmount,
    double? closeTotalAmount,
    Map<int, int>? closeNotesMap,
    Map<int, int>? closeCoinsMap,
    String? notes,
  }) {
    return RegisterScenario(
      id: id ?? this.id,
      name: name ?? this.name,
      openingFloatAmount: openingFloatAmount ?? this.openingFloatAmount,
      closeTotalAmount: closeTotalAmount ?? this.closeTotalAmount,
      closeNotesMap: closeNotesMap ?? this.closeNotesMap,
      closeCoinsMap: closeCoinsMap ?? this.closeCoinsMap,
      notes: notes ?? this.notes,
    );
  }
}
