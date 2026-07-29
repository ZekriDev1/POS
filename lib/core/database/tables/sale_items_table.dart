import 'package:drift/drift.dart';

class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text()();
  TextColumn get productId => text()();
  IntColumn get quantity => integer()();
  RealColumn get price => real()();

  @override
  Set<Column> get primaryKey => {id};
}
