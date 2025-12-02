import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // CHANGE THIS IP ADDRESS TO YOUR MACHINE'S LOCAL IP
  static const String _mobileIp = '172.16.253.246'; 
  
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else {
      return 'http://$_mobileIp:5000';
    }
  }
}