import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph/logic/physics_isolate.dart';
import 'package:graph/models/physics_node.dart';

void main() {
  test('Gravity pulls node to center', () async {
    final receivePort = ReceivePort();
    await Isolate.spawn(physicsIsolateEntry, receivePort.sendPort);

    final completer = Completer<SendPort>();
    final updateCompleter = Completer<Map<String, Offset>>();

    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is PhysicsMessage) {
        if (message.command == PhysicsCommand.updateNodes) {
          if (!updateCompleter.isCompleted) {
            if (message.data is Map &&
                (message.data as Map).containsKey('ids')) {
              final data = message.data as Map;
              final ids = data['ids'] as List<String>;
              final coords = data['coords'] as Float64List;
              final map = <String, Offset>{};
              for (int i = 0; i < ids.length; i++) {
                map[ids[i]] = Offset(coords[i * 2], coords[i * 2 + 1]);
              }
              updateCompleter.complete(map);
            } else {
              updateCompleter.complete(message.data as Map<String, Offset>);
            }
          }
        }
      }
    });

    final sendPort = await completer.future;

    // Init with one node at (100, 100)
    final node = PhysicsNode(
      id: "test",
      position: const Offset(100, 100),
      mass: 1.0,
      radius: 10.0,
    );

    sendPort.send(PhysicsMessage(PhysicsCommand.init, InitialData([node], [])));

    // Start simulation
    sendPort.send(PhysicsMessage(PhysicsCommand.start));

    // Wait for update
    final updates = await updateCompleter.future.timeout(
      const Duration(seconds: 2),
    );
    final newPos = updates["test"]!;

    print("Old Pos: (100, 100)");
    print("New Pos: $newPos");

    // Check if it moved closer to (0,0)
    // Distance should be less than start distance (approx 141.4)
    final oldDist = const Offset(100, 100).distance;
    final newDist = newPos.distance;

    expect(
      newDist,
      lessThan(oldDist),
      reason: "Node should move closer to center",
    );

    // Also check direction: x and y should both decrease (become less positive)
    expect(newPos.dx, lessThan(100.0));
    expect(newPos.dy, lessThan(100.0));

    sendPort.send(PhysicsMessage(PhysicsCommand.stop));
    receivePort.close();
  });
}
