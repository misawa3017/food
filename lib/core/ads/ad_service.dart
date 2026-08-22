import 'ad_service_contract.dart';
import 'ad_service_stub.dart'
    if (dart.library.io) 'ad_service_mobile.dart'
    as implementation;

export 'ad_service_contract.dart';

AdService createAdService() => implementation.createAdService();
