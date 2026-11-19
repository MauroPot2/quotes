class BusinessProfile {
  const BusinessProfile({
    this.name = '',
    this.vatNumber = '',
    this.address = '',
    this.email = '',
    this.phone = '',
    this.iban = '',
    this.logo = '',
    this.signature = '',
  });

  final String name;
  final String vatNumber;
  final String address;
  final String email;
  final String phone;
  final String iban;
  /// Base64-encoded PNG or JPEG, included in backups.
  final String logo;
  final String signature;
}
