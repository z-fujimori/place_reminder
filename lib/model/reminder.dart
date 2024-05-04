import 'package:isar/isar.dart';
part 'reminder.g.dart';

@collection
class Reminder {
  Id id = Isar.autoIncrement; // id = nullでも自動インクリメントする

  String? title;
  String? memo;
  double? lat;
  double? long;
  bool? isVib;
}