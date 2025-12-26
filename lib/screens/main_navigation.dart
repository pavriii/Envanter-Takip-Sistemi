import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'inventory_screen.dart';
import 'shipments_screen.dart';
import 'analysis_screen.dart';
import 'profile_screen.dart';
import 'contacts_screen.dart'; // YENİ EKLENDİ

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _selectedIndex = 0;
  String _userRole = "loading";

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          setState(() {
            _userRole = doc['role'] ?? 'personel';
          });
        } else {
          setState(() => _userRole = 'personel');
        }
      } catch (e) {
        setState(() => _userRole = 'personel');
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == "loading") {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    List<Widget> pages = [
      InventoryScreen(userRole: _userRole),
      const ShipmentsScreen(),
      const ContactsScreen(), // YENİ: 2. Sırada Cari Hesaplar
    ];

    // Analiz sadece admine
    if (_userRole == 'admin') {
      pages.add(const AnalysisScreen());
    }

    pages.add(const ProfileScreen());

    // Menü İkonları
    List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.inventory_2_outlined),
        activeIcon: Icon(Icons.inventory_2),
        label: 'Envanter',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.local_shipping_outlined),
        activeIcon: Icon(Icons.local_shipping),
        label: 'Sevkiyat',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.people_outline),
        activeIcon: Icon(Icons.people),
        label: 'Cari',
      ), // YENİ
    ];

    if (_userRole == 'admin') {
      navItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          activeIcon: Icon(Icons.analytics),
          label: 'Analiz',
        ),
      );
    }

    navItems.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Hesabım',
      ),
    );

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0055FF),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: navItems,
      ),
    );
  }
}
