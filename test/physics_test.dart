import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph/logic/physics_isolate.dart';
import 'package:graph/models/physics_node.dart';

void main() {
  group('Physics Isolate Tests', () {
    late ReceivePort receivePort;
    late Isolate isolate;
    late Stream<dynamic> broadcastStream;
    late Completer<SendPort> sendPortCompleter;

    setUp(() async {
      receivePort = ReceivePort();
      broadcastStream = receivePort.asBroadcastStream();
      isolate = await Isolate.spawn(physicsIsolateEntry, receivePort.sendPort);
      sendPortCompleter = Completer<SendPort>();

      broadcastStream.listen((message) {
        if (message is SendPort && !sendPortCompleter.isCompleted) {
          sendPortCompleter.complete(message);
        }
      });
    });

    tearDown(() {
      receivePort.close();
      isolate.kill();
    });

    Future<Map<String, Offset>> waitForUpdates(
      Stream<dynamic> stream, {
      int count = 1,
    }) async {
      final completer = Completer<Map<String, Offset>>();
      int updatesReceived = 0;

      final subscription = stream.listen((message) {
        if (message is PhysicsMessage &&
            message.command == PhysicsCommand.updateNodes) {
          updatesReceived++;
          if (updatesReceived >= count) {
            if (message.data is Map &&
                (message.data as Map).containsKey('ids')) {
              final data = message.data as Map;
              final ids = data['ids'] as List<String>;
              final coords = data['coords'] as Float64List;
              final map = <String, Offset>{};
              for (int i = 0; i < ids.length; i++) {
                map[ids[i]] = Offset(coords[i * 2], coords[i * 2 + 1]);
              }
              if (!completer.isCompleted) completer.complete(map);
            }
          }
        }
      });

      final result = await completer.future.timeout(const Duration(seconds: 5));
      await subscription.cancel();
      return result;
    }

    test('Repulsion pushes nodes apart', () async {
      final sendPort = await sendPortCompleter.future;

      // Two nodes very close to each other
      final node1 = PhysicsNode(
        id: '1',
        position: const Offset(0, 0),
        mass: 1.0,
        radius: 10.0,
      );
      final node2 = PhysicsNode(
        id: '2',
        position: const Offset(1, 1),
        mass: 1.0,
        radius: 10.0,
      );

      // We need to disable gravity/centering for pure repulsion test,
      // or set it very weak. Or just assume repulsion is stronger at close range.
      final config = PhysicsConfig(
        gravityStrength: 0.0, // Disable gravity to isolate repulsion
      );

      sendPort.send(
        PhysicsMessage(
          PhysicsCommand.init,
          InitialData([node1, node2], [], config),
        ),
      );

      sendPort.send(PhysicsMessage(PhysicsCommand.start));

      // Wait for a few frames
      final updates = await waitForUpdates(broadcastStream, count: 5);

      final p1 = updates['1']!;
      final p2 = updates['2']!;

      final initialDist = sqrt(1 * 1 + 1 * 1); // approx 1.414
      final newDist = (p1 - p2).distance;

      expect(
        newDist,
        greaterThan(initialDist),
        reason: "Nodes should repel each other",
      );
    });

    test('Springs pull nodes together', () async {
      final sendPort = await sendPortCompleter.future;

      // Two nodes far apart connected by a link
      final node1 = PhysicsNode(
        id: '1',
        position: const Offset(0, 0),
        mass: 1.0,
        radius: 10.0,
      );
      final node2 = PhysicsNode(
        id: '2',
        position: const Offset(200, 0),
        mass: 1.0,
        radius: 10.0,
      );

      final link = PhysicsLinkData('1', '2');

      final config = PhysicsConfig(
        gravityStrength: 0.0, // Disable gravity
        linkStrength: 1.0, // Strong links
        linkDistance: 50.0, // Target distance
      );

      sendPort.send(
        PhysicsMessage(
          PhysicsCommand.init,
          InitialData([node1, node2], [link], config),
        ),
      );

      sendPort.send(PhysicsMessage(PhysicsCommand.start));

      final updates = await waitForUpdates(broadcastStream, count: 10);

      final p1 = updates['1']!;
      final p2 = updates['2']!;
      final newDist = (p1 - p2).distance;

      // Initial dist 200. Target 50. Should be closer.
      expect(
        newDist,
        lessThan(200.0),
        reason: "Spring should pull nodes together",
      );
      // Should definitely be greater than 0
      expect(newDist, greaterThan(0.0));
    });
  });
}
