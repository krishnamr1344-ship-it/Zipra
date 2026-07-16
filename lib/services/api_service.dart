library;

export 'api_service_base.dart';
export 'api_service_base.dart' show ApiException;

/// Barrel file: re-exports the split ApiService modules.
/// All existing `import 'api_service.dart'` statements continue to work.
///
/// ApiService mixes in all feature modules:
/// - AuthApi: login, logout, social auth
/// - ProductApi: categories, products
/// - CartApi: server-side cart (reserved)
/// - OrderApi: create/get orders
/// - PaymentApi: delivery fee
/// - AddressApi: addresses, place search
/// - OfferApi: offers, combo packs
/// - UploadApi: image uploads (reserved)

import 'api_service_base.dart';

class ApiService extends ApiServiceBase
    with
        AuthApi,
        ProductApi,
        CartApi,
        OrderApi,
        PaymentApi,
        AddressApi,
        OfferApi,
        UploadApi {
  // Constants are top-level in api_service_base.dart
}
