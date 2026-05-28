import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_sense/app.dart';
import 'package:smart_sense/core/constants/app_text.dart';
import 'package:smart_sense/injection.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.test');
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies();
  });

  tearDownAll(() async {
    await getIt.reset();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();

    expect(find.text(AppText.appName), findsOneWidget);
    expect(find.text('SYSTEM INITIALIZING'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Sign in to access your dashboard'), findsOneWidget);
  });
}
