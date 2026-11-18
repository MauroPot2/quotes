class BusinessProfile {
  const BusinessProfile({
    this.name = '',
    this.vatNumber = '',
    this.address = '',
    this.email = '',
    this.phone = '',
    this.iban = '',
  });

  final String name;
  final String vatNumber;
  final String address;
  final String email;
  final String phone;
  final String iban;
}
