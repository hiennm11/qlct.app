import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/services/analytics_service.dart';

void main() {
  late AnalyticsService analytics;

  setUp(() {
    analytics = AnalyticsService();
    analytics.clear();
  });

  group('AnalyticsService', () {
    test('track increments counter', () {
      analytics.track('app_open');
      analytics.track('app_open');
      analytics.track('transaction_added');
      
      expect(analytics.counters['app_open'], 2);
      expect(analytics.counters['transaction_added'], 1);
      expect(analytics.counters['unknown_event'], isNull);
    });

    test('track with props', () {
      analytics.track('error_caught', {'type': 'FormatException'});
      
      // Just verify it doesn't throw - the event is in the buffer
      final json = analytics.exportJson();
      expect(json, contains('error_caught'));
      expect(json, contains('FormatException'));
    });

    test('track unknown event initializes counter to 1', () {
      analytics.track('new_event');
      expect(analytics.counters['new_event'], 1);
    });

    test('singleton returns same instance', () {
      final a = AnalyticsService();
      final b = AnalyticsService();
      expect(identical(a, b), isTrue);
    });

    test('exportJson returns valid JSON with counters and events', () {
      analytics.track('app_open');
      analytics.track('app_open');
      analytics.track('transaction_added');
      
      final json = analytics.exportJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      
      expect(decoded['exportedAt'], isNotNull);
      expect(decoded['counters'], isA<Map>());
      expect(decoded['counters']['app_open'], 2);
      expect(decoded['recentEvents'], isA<List>());
      expect(decoded['recentEvents'].length, 3);
    });

    test('ring buffer respects max 500 events', () {
      // Add 600 events
      for (int i = 0; i < 600; i++) {
        analytics.track('event_$i');
      }
      
      final json = analytics.exportJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final events = decoded['recentEvents'] as List;
      
      expect(events.length, 500); // capped at 500
      // First event should be event_100 (oldest 100 removed)
      expect((events.first as Map)['event'], 'event_100');
      // Last event should be event_599
      expect((events.last as Map)['event'], 'event_599');
    });

    test('clear resets all data', () {
      analytics.track('app_open');
      analytics.track('app_open');
      
      analytics.clear();
      
      expect(analytics.counters.isEmpty, isTrue);
      final json = analytics.exportJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['recentEvents'], isEmpty);
    });
  });
}