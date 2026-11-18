/// Anagrafica indipendente dai preventivi: i documenti conservano una copia
/// dei dati del cliente al momento del salvataggio.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.address = '',
    this.vatNumber = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String vatNumber;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}
