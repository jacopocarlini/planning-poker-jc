import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesService {
  static const _keyUsername = 'username';
  static const _keyId = 'id';

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  Future<bool> hasUsername() async {
    final username = await getUsername();
    return username != null && username.isNotEmpty;
  }

  Future<void> clearUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsername);
  }

  Future<void> saveId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyId, id);
  }

  Future<String?> getId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyId);
  }

  Future<bool> hasId() async {
    final id = await getId();
    return id != null && id.isNotEmpty;
  }

  Future<void> clearId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyId);
  }
}