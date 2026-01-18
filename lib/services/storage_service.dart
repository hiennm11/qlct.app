import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling local storage operations
class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  /// Save a list of items to storage
  Future<void> saveList(String key, List<Map<String, dynamic>> items) async {
    final jsonString = jsonEncode(items);
    await _prefs.setString(key, jsonString);
  }

  /// Load a list of items from storage
  List<Map<String, dynamic>> loadList(String key) {
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Save a single value to storage
  Future<void> saveValue(String key, dynamic value) async {
    if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    }
  }

  /// Load a value from storage
  T? loadValue<T>(String key) {
    return _prefs.get(key) as T?;
  }

  /// Clear all data
  Future<void> clearAll() async {
    await _prefs.clear();
  }

  /// Remove a specific key
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  /// Check if a key exists
  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }
}
