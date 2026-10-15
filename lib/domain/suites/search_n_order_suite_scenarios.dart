abstract final class SearchNOrderSuiteScenarios {
  static const session = 'SNO-01: Session & Authentication Verification';
  static const startSale = 'SNO-02: Start Sale & Customer Handling';
  static const searchItems = 'SNO-03: Search Items Modal & Product Catalog';
  static const addProductToCart =
      'SNO-04: Add Search Result to Cart & Weight Handling';
  static const cartReview = 'SNO-05: Cart Sync & Proceed to Pay';
  static const cashCheckout = 'SNO-06: Cash Payment Round-Off & Finalize';

  static const all = <String>[
    session,
    startSale,
    searchItems,
    addProductToCart,
    cartReview,
    cashCheckout,
  ];
}
