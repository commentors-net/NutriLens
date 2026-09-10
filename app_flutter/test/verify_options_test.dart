import 'package:flutter_test/flutter_test.dart';
import 'package:foodvision/firebase_options.dart';

void main() {
  test('Verify Firebase Options evaluated correctly', () {
    final iosOptions = DefaultFirebaseOptions.ios;
    final androidOptions = DefaultFirebaseOptions.android;
    
    expect(iosOptions.apiKey, equals('AIzaSyDpAmYmO2Uo-C-mnSk_PwxsVgFdrYwEoGg'));
    expect(iosOptions.apiKey.length, equals(39));
    expect(iosOptions.appId, equals('1:427212681311:ios:0b4771b19134f10e0e6bea'));
    expect(iosOptions.iosClientId, equals('427212681311-r4fp73b627365lbmtlnue8712i74ioe7.apps.googleusercontent.com'));
    expect(iosOptions.projectId, equals('leave-tracker-2025'));

    expect(androidOptions.apiKey, equals('AIzaSyDpAmYmO2Uo-C-mnSk_PwxsVgFdrYwEoGg'));
    expect(androidOptions.apiKey.length, equals(39));
    expect(androidOptions.appId, equals('1:427212681311:android:0b4771b19134f10e0e6bea'));
    expect(androidOptions.projectId, equals('leave-tracker-2025'));
  });
}
