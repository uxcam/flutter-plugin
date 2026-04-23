import 'dart:js_interop';

@JS('window.uxc')
external JSObject? get uxc;

@JS('console.log')
external void consoleLog(JSString message);

@JS('window.uxc.event')
external void uxcEvent(JSString name, JSAny? properties);

@JS('window.uxc.setUserIdentity')
external void uxcSetUserIdentity(JSString name);

@JS('window.uxc.setUserProperty')
external void uxcSetUserProperty(JSString key, JSString value);

@JS('window.uxc.setUserProperties')
external void uxcSetUserProperties(JSAny? properties);

@JS('eval')
external void evalJs(JSString code);

@JS('window.uxc.injectOcclusionRects')
external void uxcInjectOcclusionRects(JSArray rects);

@JS('JSON.parse')
external JSAny jsonParse(JSString json);

@JS('window.uxc.appendGestureContent')
external void uxcAppendGestureContent(double x, double y, JSAny? data);

@JS('window.uxc.abort')
external void uxcAbort();