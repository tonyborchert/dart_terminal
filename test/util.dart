import 'dart:async';
import 'package:dart_terminal/core.dart';
import 'package:test/test.dart';
export 'package:dart_terminal/core.dart';

const zero = Position.topLeft;

/// Returns a StreamMatcher that expects [expected] events
/// within [duration]. Works even if the stream never closes.
Future<void> expectEmitsExactlyWithin(
  Stream<dynamic> stream,
  List<dynamic> matchers, {
  Duration duration = const Duration(milliseconds: 50),
}) async {
  final values = <dynamic>[];
  final sub = stream.listen(values.add);
  await Future<void>.delayed(duration);
  await sub.cancel();
  expect(values, matchers);
}
