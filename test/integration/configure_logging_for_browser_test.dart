@TestOn('browser')
import 'dart:async';
import 'dart:html' as html;
import 'dart:html_common' as html_common;

import 'package:logging/logging.dart' as log;
import 'package:logging_service/configure_logging_for_browser.dart';
import 'package:logging_service/logging_service.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

void main() {
  var testStack = r'''
stackTrace: Exception
    at Object.wrapException (http://localhost:8080/integration/configure_logging_for_browser_test.dart.js:2776:17)
    at StaticClosure.dart.main (http://localhost:8080/integration/configure_logging_for_browser_test.dart.js:9973:15)
    at _IsolateContext.eval$1 (http://localhost:8080/integration/configure_logging_for_browser_test.dart.js:1905:25)
    at Object.startRootIsolate (http://localhost:8080/integration/configure_logging_for_browser_test.dart.js:1618:21)
    at http://localhost:8080/integration/configure_logging_for_browser_test.dart.js:10729:11
    at http://localhost:8080/integration/configure_logging_for_browser_test.dart.js:10730:9
    at http://localhost:8080/integration/configure_logging_for_browser_test.dart.js:10710:7
    at http://localhost:8080/integration/configure_logging_for_browser_test.dart.js:10721:5
    at http://localhost:8080/integration/configure_logging_for_browser_test.dart.js:10733:3
  ''';

  group('listenJsErrors should', () {
    LoggingServiceMock loggingServiceMock;
    StreamController<dynamic> onErrorStreamController;
    WindowMock windowMock;

    setUp(() {
      loggingServiceMock = new LoggingServiceMock();
      onErrorStreamController = new StreamController<dynamic>.broadcast(sync: true);

      windowMock = new WindowMock();
      when(windowMock.onError).thenReturn(onErrorStreamController.stream);
      ConfigureLoggingForBrowser.listenJsErrors(loggingServiceMock, window: windowMock);
    });

    test('get the message from the error-event if it has the message field', () {
      var errorMock = new html.ErrorEvent('testType', <dynamic, dynamic>{'message': 'testMsg'});

      onErrorStreamController.add(errorMock);

      // ignore: argument_type_not_assignable
      var rec = verify(loggingServiceMock.handleLogRecord(captureAny)).captured.first as log.LogRecord;
      expect(rec.message, 'testMsg');
    });

    test('asseble error-data from the error event', () {
      var errorMock = new html.ErrorEvent('testType', <dynamic, dynamic>{
        'message': 'testMsg',
        'filename': 'test/file/name',
        'lineno': 23,
        'type': 'SomeTestType',
        'timeStamp': 1231,
      });

      onErrorStreamController.add(errorMock);

      // ignore: argument_type_not_assignable
      var rec = verify(loggingServiceMock.handleLogRecord(captureAny)).captured.first as log.LogRecord;
      expect(rec.error, new isInstanceOf<Map>());
      expect((rec.error as Map).isNotEmpty, true);
    });

    test('get the stack-trace from the nested error object if it exists', () {
      var errorMock = new html.ErrorEvent(
        'testType',
        <dynamic, dynamic>{
          'message': 'testMsg',
          'error': html_common.convertDartToNative_Dictionary(<dynamic, dynamic>{
            'stack': testStack,
          }),
        },
      );

      onErrorStreamController.add(errorMock);

      // ignore: argument_type_not_assignable
      var rec = verify(loggingServiceMock.handleLogRecord(captureAny)).captured.first as log.LogRecord;
      expect(rec.stackTrace.toString(), testStack);
    });

    test('get the message from the the nested error object if there is no message at the first level', () {
      var errorMock = new html.ErrorEvent(
        'testType',
        <dynamic, dynamic>{
          'error': html_common.convertDartToNative_Dictionary(<dynamic, dynamic>{
            'stack': testStack,
            'message': 'nestedTestMsg',
          }),
        },
      );

      onErrorStreamController.add(errorMock);

      // ignore: argument_type_not_assignable
      var rec = verify(loggingServiceMock.handleLogRecord(captureAny)).captured.first as log.LogRecord;
      expect(rec.message, 'nestedTestMsg');
    });

    test('log message even if an error-event has an incorrect type', () {
      onErrorStreamController.add(null);

      // ignore: argument_type_not_assignable
      verify(loggingServiceMock.handleLogRecord(captureAny)).called(1);
    });
  });
}

class LoggingServiceMock extends Mock implements LoggingService {}

class WindowMock extends Mock implements html.Window {}
