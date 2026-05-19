abstract class IHistoryRepository {
  Future<void> loadHistory();
  Future<bool> isUploaded(String id);
  Future<void> addToHistory(String id);
  Future<void> saveHistory();
}
