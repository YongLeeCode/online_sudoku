import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'item_guide_screen.dart';
import 'profile_screen.dart';

/// 앱 루트 — 하단 탭(메인 / 아이템 설명 / 나)으로 화면을 전환한다.
///
/// 각 탭은 [IndexedStack]으로 유지되어 전환해도 상태(스크롤·입력 등)가 보존된다.
/// 로비/게임 화면은 각 탭에서 기존처럼 `Navigator.push`로 위에 쌓인다.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  static const _tabs = <Widget>[
    HomeScreen(),
    ItemGuideScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '메인',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: '아이템 설명',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '나',
          ),
        ],
      ),
    );
  }
}
