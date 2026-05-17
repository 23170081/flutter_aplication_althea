import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:flutter_application_althea/core/providers/notification_provider.dart';
import 'package:flutter_application_althea/core/router/app_router.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX', null);

  // Inicializar Supabase
  await Supabase.initialize(
    url: 'https://purcoywiktkmgovsaspk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB1cmNveXdpa3RrbWdvdnNhc3BrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2Mjc0MjIsImV4cCI6MjA5NDIwMzQyMn0.54r-nfnMubEszMab3r2BMASD9odv0Dpu25O_9aEDJDQ',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const AltheaApp(),
    ),
  );
}

class AltheaApp extends StatefulWidget {
  const AltheaApp({super.key});

  @override
  State<AltheaApp> createState() => _AltheaAppState();
}

class _AltheaAppState extends State<AltheaApp> {
  late final _router = createRouter(context);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ALTHEA Consultorios',
      debugShowCheckedModeBanner: false,
      theme: AltheaTheme.theme.copyWith(
        textTheme: GoogleFonts.interTextTheme(AltheaTheme.theme.textTheme),
      ),
      routerConfig: _router,
    );
  }
}
