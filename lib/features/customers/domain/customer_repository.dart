import 'customer.dart';

abstract interface class CustomerRepository {
  Future<List<Customer>> getAll();
  Future<Customer> save(Customer customer);
  Future<void> delete(String id);
}
