import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/eco_tip_service.dart';
import 'package:my_app/services/notification_inbox_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dedupes eco tips by normalized text across delivery keys', () async {
    SharedPreferences.setMockInitialValues({});
    final inbox = NotificationInboxService.instance;

    await inbox.addMissedEcoTip(
      deliveryKey: 'first-key',
      tip: const EcoTipSuggestion(
        tip: 'Choose rail for short regional trips.',
        category: 'travel',
      ),
    );
    await inbox.addMissedEcoTip(
      deliveryKey: 'second-key',
      tip: const EcoTipSuggestion(
        tip: '  choose   rail for short regional trips.  ',
        category: 'travel',
      ),
    );

    expect(
      inbox.notifications
          .where((notification) => notification.title == 'Eco Tip')
          .length,
      1,
    );
  });
}
