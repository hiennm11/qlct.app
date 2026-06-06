import 'dart:convert';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  AnalyticsService._();

  final Map<String, int> _counters = {};
  final List<Map<String, dynamic>> _events = []; // ring buffer max 500
  static const int _maxEvents = 500;

  /// Track an event with optional properties
  void track(String event, [Map<String, String>? props]) {
    _counters[event] = (_counters[event] ?? 0) + 1;
    
    final entry = <String, dynamic>{
      'event': event,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    if (props != null && props.isNotEmpty) {
      entry['props'] = props;
    }
    
    _events.add(entry);
    // Ring buffer: remove oldest when exceeding max
    while (_events.length > _maxEvents) {
      _events.removeAt(0);
    }
  }

  /// Get read-only view of counters
  Map<String, int> get counters => Map.unmodifiable(_counters);

  /// Export analytics to JSON string
  String exportJson() {
    final data = {
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'counters': _counters,
      'recentEvents': _events,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Clear all analytics data
  void clear() {
    _counters.clear();
    _events.clear();
  }
}