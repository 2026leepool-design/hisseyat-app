import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const kSavedEmail = 'saved_email';
  const kTestEmail = 'test@example.com';

  group('Migration Logic Test', () {
    test('Simulate migration logic', () async {
      SharedPreferences.setMockInitialValues({
        kSavedEmail: kTestEmail,
      });
      final prefs = await SharedPreferences.getInstance();

      // Verify it's in SharedPreferences
      expect(prefs.getString(kSavedEmail), kTestEmail);

      // Simulate loadSavedCredentials migration
      String? secureEmailValue; // Mocking FlutterSecureStorage
      String? email = secureEmailValue;

      if (email == null) {
        email = prefs.getString(kSavedEmail);
        if (email != null) {
          secureEmailValue = email; // Simulating secure storage write
          await prefs.remove(kSavedEmail);
        }
      }

      // Verify migration
      expect(secureEmailValue, kTestEmail);
      expect(prefs.containsKey(kSavedEmail), false);
    });

    test('Simulate saveCredentials logic - Remember Me ON', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      String? secureEmailValue;
      bool rememberMe = true;
      String emailToSave = kTestEmail;

      // Logic from _saveCredentials
      if (rememberMe) {
        await prefs.setBool('remember_me', true);
        secureEmailValue = emailToSave;
        await prefs.remove(kSavedEmail);
      }

      expect(prefs.getBool('remember_me'), true);
      expect(secureEmailValue, kTestEmail);
      expect(prefs.containsKey(kSavedEmail), false);
    });

    test('Simulate saveCredentials logic - Remember Me OFF', () async {
      SharedPreferences.setMockInitialValues({
        kSavedEmail: 'old@example.com',
      });
      final prefs = await SharedPreferences.getInstance();

      String? secureEmailValue = 'some_email';
      bool rememberMe = false;

      // Logic from _saveCredentials
      if (!rememberMe) {
        await prefs.setBool('remember_me', false);
        secureEmailValue = null; // delete from secure storage
        await prefs.remove(kSavedEmail);
      }

      expect(prefs.getBool('remember_me'), false);
      expect(secureEmailValue, null);
      expect(prefs.containsKey(kSavedEmail), false);
    });
  });
}
