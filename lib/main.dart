import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'domain/providers/room_provider.dart';
import 'presentation/screens/root_screen.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(_supabaseUrl.isNotEmpty, 'SUPABASE_URL이 설정되지 않았습니다. --dart-define으로 주입하세요.');
  assert(_supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY가 설정되지 않았습니다. --dart-define으로 주입하세요.');

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(const ProviderScope(child: OnlineSudokuApp()));
}

class OnlineSudokuApp extends ConsumerStatefulWidget {
  const OnlineSudokuApp({super.key});

  @override
  ConsumerState<OnlineSudokuApp> createState() => _OnlineSudokuAppState();
}

class _OnlineSudokuAppState extends ConsumerState<OnlineSudokuApp>
    with WidgetsBindingObserver {
  Timer? _disconnectTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disconnectTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _disconnectTimer ??=
            Timer(const Duration(minutes: 1), _disconnectCurrentPlayer);
      case AppLifecycleState.resumed:
        _disconnectTimer?.cancel();
        _disconnectTimer = null;
        _reconnectCurrentPlayer();
      case AppLifecycleState.detached:
        _disconnectTimer?.cancel();
        _disconnectCurrentPlayer();
      default:
        break;
    }
  }

  void _disconnectCurrentPlayer() {
    final player = ref.read(currentPlayerProvider);
    if (player == null) return;
    unawaited(ref.read(roomRepositoryProvider).disconnectPlayer(player.id));
  }

  void _reconnectCurrentPlayer() {
    final player = ref.read(currentPlayerProvider);
    if (player == null) return;
    unawaited(ref.read(roomRepositoryProvider).reconnectPlayer(player.id));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku Clash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const RootScreen(),
    );
  }
}
