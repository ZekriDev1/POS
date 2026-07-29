import 'package:drift/drift.dart';

class InventoryHistory extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  IntColumn get quantity => integer()();
  TextColumn get type => text()();
  DateTimeColumn get date => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
