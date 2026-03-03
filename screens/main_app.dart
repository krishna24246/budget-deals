import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'wishlist_screen.dart';
import 'profile_screen.dart';
import 'admin_panel_screen.dart';
import '../services/cross_platform_auth_service.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
  }

  List<Widget> _buildScreens() {
    final screens = [
      const HomeScreen(),
      const SavedScreen(),
      const ProfileScreen(),
    ];

    final currentUser = CrossPlatformAuthService().currentUser;
    print(
      'MainApp _buildScreens: currentUser=$currentUser, isAdmin=${currentUser?.isAdmin}',
    );
    if (currentUser?.isAdmin == true) {
      screens.add(const AdminPanelScreen());
      print('MainApp: added AdminPanelScreen');
    } else {
      print('MainApp: not adding AdminPanelScreen');
    }

    return screens;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = CrossPlatformAuthService().currentUser;
    final isAdmin = currentUser?.isAdmin == true;

    List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.favorite),
        activeIcon: Icon(Icons.favorite),
        label: 'Saved',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        activeIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    if (isAdmin) {
      navItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          activeIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _buildScreens()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.brightness == Brightness.dark
            ? Colors.black
            : theme.colorScheme.surface,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        items: navItems,
      ),
    );
  }
}

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WishlistScreen();
  }
}
