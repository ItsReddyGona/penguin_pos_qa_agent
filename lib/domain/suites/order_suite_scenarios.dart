abstract final class OrderSuiteScenarios {
  static const session = 'ORD-01: Session & Authentication Verification';
  static const startSale = 'ORD-02: Start Sale & Customer Handling';
  static const standardSku = 'ORD-03: Barcode & Standard SKU Scanning';
  static const weighedItem = 'ORD-04: Weighed Item Entry & Scale Input';
  static const cartReview = 'ORD-05: Cart Sync & Proceed to Pay';
  static const cashCheckout = 'ORD-06: Cash Payment Round-Off & Finalize';

  static const all = <String>[
    session,
    startSale,
    standardSku,
    weighedItem,
    cartReview,
    cashCheckout,
  ];
}
