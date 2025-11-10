import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torrid/services/storage/prefs_service.dart';

part 'status_provider.g.dart';

@riverpod
SharedPreferences prefs(PrefsRef ref){
  return PrefsService().prefs;
}
