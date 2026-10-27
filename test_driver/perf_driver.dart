import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Turns the timelines recorded by integration_test/perf_test.dart into
/// `build/<key>.timeline_summary.json` (frame build/raster percentiles, jank).
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    for (final key in ['catalog_scroll', 'navigation']) {
      final raw = data[key];
      if (raw is! Map<String, dynamic>) continue;
      final summary = driver.TimelineSummary.summarize(driver.Timeline.fromJson(raw));
      await summary.writeTimelineToFile(key, pretty: true, includeSummary: true);
    }
  },
);
