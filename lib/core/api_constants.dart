import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // CHANGE THIS IP ADDRESS TO YOUR MACHINE'S LOCAL IP
  static const String _mobileIp = '10.209.177.132'; 
  
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else {
      return 'http://$_mobileIp:5000';
    }
  }
}