import 'business_profile.dart';

abstract interface class BusinessRepository {
  Future<BusinessProfile> load();
  Future<void> save(BusinessProfile profile);
}
