import 'package:hive/hive.dart';
import '../../domain/repositories/history_repository.dart';
import '../../core/security/obfuscator.dart';

class HistoryRepositoryImpl implements IHistoryRepository {
  late Box _box;

  HistoryRepositoryImpl() {
    _box = Hive.box(Obfuscator.deobfuscate(Obfuscator.historyBoxBytes));
  }

  @override
  Future<void> loadHistory() async {
    // Hive box is already opened in service locator
  }

  @override
  Future<bool> isUploaded(String id) async {
    return _box.containsKey(id);
  }

  @override
  Future<void> addToHistory(String id) async {
    // We use the ID as the key and true as the value
    await _box.put(id, true);
  }

  @override
  Future<void> saveHistory() async {
    // Hive automatically handles persistence
    await _box.flush();
  }
}
