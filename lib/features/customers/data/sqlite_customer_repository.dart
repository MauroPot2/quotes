import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

class SqliteCustomerRepository implements CustomerRepository {
  const SqliteCustomerRepository(this.database);
  final LocalDatabase database;

  @override
  Future<List<Customer>> getAll() async {
    final db = await database.instance;
    final rows = await db.query(
      'customers',
      orderBy: 'name COLLATE NOCASE, id',
    );
    return List<Customer>.unmodifiable(rows.map(_fromRow));
  }

  @override
  Future<Customer> save(Customer customer) async {
    if (customer.name.trim().isEmpty) {
      throw const FormatException('Il nome del cliente è obbligatorio.');
    }
    final db = await database.instance;
    final now = DateTime.now();
    final saved = Customer(
      id: customer.id.isEmpty ? const Uuid().v4() : customer.id,
      name: customer.name.trim(),
      email: customer.email.trim(),
      phone: customer.phone.trim(),
      address: customer.address.trim(),
      vatNumber: customer.vatNumber.trim(),
      notes: customer.notes.trim(),
      createdAt: customer.id.isEmpty ? now : customer.createdAt,
      updatedAt: now,
    );
    await db.insert('customers', {
      'id': saved.id,
      'name': saved.name,
      'email': saved.email,
      'phone': saved.phone,
      'address': saved.address,
      'vat_number': saved.vatNumber,
      'notes': saved.notes,
      'created_at': saved.createdAt.toIso8601String(),
      'updated_at': saved.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    final db = await database.instance;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    // Le FK dei preventivi vengono impostate a NULL, non si perdono snapshot.
  }

  Customer _fromRow(Map<String, Object?> row) => Customer(
    id: row['id']! as String,
    name: row['name']! as String,
    email: row['email']! as String,
    phone: row['phone']! as String,
    address: row['address']! as String,
    vatNumber: row['vat_number']! as String,
    notes: row['notes']! as String,
    createdAt: DateTime.parse(row['created_at']! as String),
    updatedAt: DateTime.parse(row['updated_at']! as String),
  );
}
