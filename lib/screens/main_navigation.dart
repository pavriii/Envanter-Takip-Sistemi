import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Sayfalar
import 'inventory_screen.dart';
import 'shipments_screen.dart';
import 'analysis_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart'; // Çıkış yapınca dönmek için

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _selectedIndex = 0;
  String _userRole = "loading"; // Başlangıçta yükleniyor

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  // Kullanıcının rolünü veritabanından çek
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
            _userRole =
                doc['role'] ??
                'personel'; // Eğer rol yazmıyorsa güvenli olarak 'personel' varsay
          });
        } else {
          // Eski kullanıcılarda rol yoksa varsayılan personel yap
          setState(() => _userRole = 'personel');
        }
      } catch (e) {
        print("Rol çekme hatası: $e");
        setState(() => _userRole = 'personel');
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Rol yüklenene kadar bekle
    if (_userRole == "loading") {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // --- SAYFA LİSTESİ (Role Göre Değişir) ---
    List<Widget> pages = [];
    List<BottomNavigationBarItem> navItems = [];

    // 1. Envanter (Herkes görür ama içine rolü gönderiyoruz)
    pages.add(InventoryScreen(userRole: _userRole));
    navItems.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.inventory_2_outlined),
        activeIcon: Icon(Icons.inventory_2),
        label: 'Envanter',
      ),
    );

    // 2. Sevkiyat (Herkes görür)
    pages.add(const ShipmentsScreen());
    navItems.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.local_shipping_outlined),
        activeIcon: Icon(Icons.local_shipping),
        label: 'Sevkiyat',
      ),
    );

    // 3. Analiz (SADECE ADMIN GÖRÜR)
    if (_userRole == 'admin') {
      pages.add(const AnalysisScreen());
      navItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          activeIcon: Icon(Icons.analytics),
          label: 'Analiz',
        ),
      );
    }

    // 4. Profil (Herkes görür)
    pages.add(const ProfileScreen());
    navItems.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Hesabım',
      ),
    );

    return Scaffold(
      body: pages[_selectedIndex],
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
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0055FF),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: navItems,
        ),
      ),
    );
  }
}
