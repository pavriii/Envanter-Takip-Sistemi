import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  // Kullanıcı verilerini çek (İsim, Rol, Fotoğraf vb.)
  Future<void> _getUserData() async {
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        if (doc.exists) {
          if (mounted) {
            setState(() {
              userData = doc.data() as Map<String, dynamic>;
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        debugPrint("Hata: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Çıkış Yap
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    String role = userData?['role'] ?? 'personel';
    String email = user?.email ?? "";
    String name = userData?['name'] ?? "Kullanıcı";
    String? photoUrl = userData?['photoUrl']; // Firestore'dan gelen resim

    return Scaffold(
      appBar: AppBar(title: const Text("Hesabım")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- PROFİL FOTOĞRAFI ALANI ---
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0055FF),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                      image: DecorationImage(
                        fit: BoxFit.cover,
                        image: photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : const AssetImage('assets/default_avatar.png')
                                  as ImageProvider,
                        // Not: assets klasöründe resim yoksa NetworkImage hata verebilir,
                        // basitlik için Icon kullanalım:
                      ),
                    ),
                    // Eğer resim yoksa ikon göster
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0055FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // İsim ve Rol
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: role == 'admin'
                    ? Colors.red.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  color: role == 'admin' ? Colors.red : Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- MENÜLER ---
            _buildProfileOption(
              icon: Icons.person_outline,
              title: "Profili Düzenle",
              onTap: () async {
                // Düzenleme ekranına git ve dönünce sayfayı yenile
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                );
                _getUserData(); // Verileri güncelle
              },
            ),
            _buildProfileOption(
              icon: Icons.lock_outline,
              title: "Şifre Değiştir",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),
            _buildProfileOption(
              icon: Icons.notifications_outlined,
              title: "Bildirim Ayarları",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Yakında eklenecek...")),
                );
              },
            ),
            const Divider(),
            _buildProfileOption(
              icon: Icons.logout,
              title: "Çıkış Yap",
              textColor: Colors.red,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color textColor = Colors.black,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: textColor == Colors.red ? Colors.red : const Color(0xFF0055FF),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
    );
  }
}
