import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import '../domain/business_profile.dart';
import '../domain/business_repository.dart';
import 'business_profile_row.dart';

class SqliteBusinessRepository implements BusinessRepository {
  const SqliteBusinessRepository(this.database);
  final LocalDatabase database;

  @override
  Future<BusinessProfile> load() async {
    final db = await database.instance;
    final row = await db.transaction(readBusinessProfileRow);
    if (row == null) return const BusinessProfile();
    return BusinessProfile(
      name: row['name']! as String,
      vatNumber: row['vat_number']! as String,
      address: row['address']! as String,
      email: row['email']! as String,
      phone: row['phone']! as String,
      iban: row['iban']! as String,
      logo: row['logo']! as String,
      signature: row['signature']! as String,
    );
  }

  @override
  Future<void> save(BusinessProfile profile) async {
    final db = await database.instance;
    await db.insert('business_profile', {
      'id': 1,
      'name': profile.name.trim(),
      'vat_number': profile.vatNumber.trim(),
      'address': profile.address.trim(),
      'email': profile.email.trim(),
      'phone': profile.phone.trim(),
      'iban': profile.iban.trim(),
      'logo': profile.logo,
      'signature': profile.signature,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
