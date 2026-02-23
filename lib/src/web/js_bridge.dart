import 'dart:js_interop';

@JS('window.uxc')
external JSObject? get uxc;

@JS('console.log')
external void consoleLog(JSString message);

@JS('window.uxc.event')
external void uxcEvent(JSString name, JSAny? properties);

@JS('eval')
external void evalJs(JSString code);

@JS('window.uxc.injectSnapshot')
external void uxcInjectSnapshot(JSArray nodes);

@JS('JSON.parse')
external JSAny jsonParse(JSString json); 