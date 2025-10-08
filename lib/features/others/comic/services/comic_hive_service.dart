
import 'package:hive_flutter/adapters.dart';
import 'package:torrid/features/others/comic/models/comic_progress.dart';

class ComicHiveService {
  static const String progressBoxName = "comicProgress";

  static Future<void>init()async{
    Hive.registerAdapter(ComicProgressAdapter());
    await Hive.openBox<ComicProgress>(progressBoxName);
  }
}