import 'dart:async';
import 'dart:convert';

/// One Server-Sent Event: its name (`message` when none was given) and data.
class SseEvent {
  const SseEvent(this.event, this.data, {this.id});
  final String event;
  final String data;
  final String? id;

  /// The data as a JSON object, or null when it is not one.
  Map<String, dynamic>? get json {
    try {
      final decoded = jsonDecode(data);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}

/// Parses a `text/event-stream` body (WHATWG rules: `event`, `data` (joined
/// with newlines), `id`, comments starting with `:` ignored, a blank line ends
/// an event).
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  String? event;
  String? id;
  final data = <String>[];
  await for (final line in bytes.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty || event != null) {
        yield SseEvent(event ?? 'message', data.join('\n'), id: id);
      }
      event = null;
      data.clear();
      continue;
    }
    if (line.startsWith(':')) continue; // heartbeat / comment
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        event = value;
      case 'data':
        data.add(value);
      case 'id':
        id = value;
    }
  }
  if (data.isNotEmpty) yield SseEvent(event ?? 'message', data.join('\n'), id: id);
}
