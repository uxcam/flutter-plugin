import 'package:flutter/services.dart';
import 'package:flutter_uxcam/src/smart_events/uxcam_smart_events.dart';

class Uxcam {
  
    static void registerWith() {                                                                                                                                                               
      const channel = MethodChannel('uxcam_smart_events');                                                                                                                                        
      channel.setMethodCallHandler((call) async {
        if (call.method == 'initSmartEvents') {                                                                                                                                                   
          UXCamSmartEvents().initialize(enableGestureTracking: true);                                                                                                                             
        }                                                                                                                                                                                         
      });         
    }  
}
