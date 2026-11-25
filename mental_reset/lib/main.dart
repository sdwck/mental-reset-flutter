import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/api_client.dart';
import 'data/http_session_repository.dart';
import 'data/session_repository.dart';
import 'data/token_store.dart';
import 'router.dart';
import 'state/auth_model.dart';
import 'state/debug_settings.dart';
import 'state/sessions_model.dart';

/// Корень композиции. Единственное место, где выбирается реализация репозитория.
/// L4: MockSessionRepository; L5: HttpSessionRepository на собственном backend-е.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final debug = DebugSettings();
  final tokens = TokenStore();
  late final AuthModel auth;
  final api = ApiClient(tokens, onUnauthorized: () => auth.expired());
  auth = AuthModel(api, tokens);
  await auth.restore(); // запуск → getString

  final SessionRepository repository = HttpSessionRepository(api);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DebugSettings>.value(value: debug),
        ChangeNotifierProvider<AuthModel>.value(value: auth),
        // Фабрика в create: модель создаётся один раз и сразу начинает загрузку.
        ChangeNotifierProvider(create: (_) => SessionsModel(repository)..load()),
      ],
      child: MentalResetApp(router: createRouter(auth)),
    ),
  );
}

class MentalResetApp extends StatelessWidget {
  const MentalResetApp({super.key, required this.router});

  final RouterConfig<Object> router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mental Reset',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B2A4A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
