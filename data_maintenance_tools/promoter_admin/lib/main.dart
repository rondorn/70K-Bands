import 'package:flutter/material.dart';
import 'package:promoter_admin/api/workspace_client.dart';
import 'package:promoter_admin/screens/bands_screen.dart';
import 'package:promoter_admin/screens/create_festival_screen.dart';
import 'package:promoter_admin/screens/home_screen.dart';
import 'package:promoter_admin/screens/promote_screen.dart';
import 'package:promoter_admin/screens/schedule_screen.dart';

void main() {
  runApp(const PromoterAdminApp());
}

class PromoterAdminApp extends StatelessWidget {
  const PromoterAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = WorkspaceClient();
    return MaterialApp(
      title: 'Festival Promoter Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4D3E)),
        useMaterial3: true,
      ),
      home: HomeScreen(client: client),
      routes: {
        '/bands': (_) => BandsScreen(client: client),
        '/schedule': (_) => ScheduleScreen(client: client),
        '/promote': (_) => PromoteScreen(client: client),
        '/create': (_) => CreateFestivalScreen(client: client),
      },
    );
  }
}
