import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:girinori/screens/dashboard_screen.dart';
import 'package:girinori/providers/route_master_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => RouteMasterProvider(),
      child: const MyTransitApp(),
    ),
    // const MyTransitApp()
  );
}

class MyTransitApp extends StatelessWidget {
  const MyTransitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SokuKita',
      debugShowCheckedModeBanner: false, // 右上のデバッグ帯を非表示に
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121214),
        cardColor: const Color(0xFF1E1E24),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676), // ネオングリーン
          secondary: Color(0xFF00B0FF), // ネオンブルー
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
