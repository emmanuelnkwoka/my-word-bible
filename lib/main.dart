import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_providers.dart';
import 'core/storage/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Preferences are loaded before the first frame so theme and onboarding
  // state are applied without a flash of default content.
  final store = await SharedPreferencesStore.create();

  runApp(ProviderScope(overrides: [keyValueStoreProvider.overrideWithValue(store)], child: const MwbApp()));
}
