import 'package:logger/logger.dart';

abstract class LoggingService {
  void logNodeSelection(String nodeId);
  void logNodeDeselection(String nodeId);
  void logNodeDragStart(String nodeId);
  void logNodeDragEnd(String nodeId);
  void logLinkCreation(String sourceId, String targetId);
  void logNodeCreation(String nodeId);
  void logNodeDeletion(String nodeId);
}

class ConsoleLoggingService implements LoggingService {
  final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  @override
  void logNodeSelection(String nodeId) {
    _logger.i('Selected node: $nodeId');
  }

  @override
  void logNodeDeselection(String nodeId) {
    _logger.i('Deselected node: $nodeId');
  }

  @override
  void logNodeDragStart(String nodeId) {
    _logger.i('Drag START on node: $nodeId');
  }

  @override
  void logNodeDragEnd(String nodeId) {
    _logger.i('Drag END on node: $nodeId');
  }

  @override
  void logLinkCreation(String sourceId, String targetId) {
    _logger.i('Created link: $sourceId -> $targetId');
  }

  @override
  void logNodeCreation(String nodeId) {
    _logger.i('Created node: $nodeId');
  }

  @override
  void logNodeDeletion(String nodeId) {
    _logger.i('Deleted node: $nodeId');
  }
}
