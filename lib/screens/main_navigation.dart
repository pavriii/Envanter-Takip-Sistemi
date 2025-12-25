import 'package:flutter/material.dart';

// Diğer ekranları içeri aktarıyoruz
import 'inventory_screen.dart';
import 'shipments_screen.dart';
import 'analysis_screen.dart';
import 'profile_screen.dart';

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _selectedIndex = 0; // Varsayılan olarak ilk sayfa (Envanter) açık

  // Sayfaların Listesi
  final List<Widget> _pages = [
    InventoryScreen(), // 0: Envanter
    ShipmentsScreen(), // 1: Sevkiyat
    AnalysisScreen(), // 2: Analiz (Dashboard)
    ProfileScreen(), // 3: Profil/Ayarlar
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Seçili sayfayı gövdeye yerleştir
      body: _pages[_selectedIndex],

      // Alt Menü Tasarımı
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType
              .fixed, // 4 buton olduğu için 'fixed' olmalı
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0055FF), // Senin temanın ana rengi
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Envanter',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_outlined),
              activeIcon: Icon(Icons.local_shipping),
              label: 'Sevkiyat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'Analiz',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Hesabım',
            ),
          ],
        ),
      ),
    );
  }
}
