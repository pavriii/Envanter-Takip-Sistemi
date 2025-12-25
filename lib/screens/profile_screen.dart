import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart'; // Profil düzenleme ekranı
import 'change_password_screen.dart'; // Şifre değiştirme ekranı

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Ayarların Durumları (Varsayılan değerler)
  bool _notificationsEnabled = true;
  String _selectedLanguage = "Türkçe";

  // Dil Seçim Menüsünü Açan Fonksiyon
  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Dil Seçimi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Text("🇹🇷", style: TextStyle(fontSize: 24)),
                title: const Text("Türkçe"),
                trailing: _selectedLanguage == "Türkçe"
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _selectedLanguage = "Türkçe");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Text("🇬🇧", style: TextStyle(fontSize: 24)),
                title: const Text("English"),
                subtitle: const Text("(Yakında)"),
                enabled: false, // Şimdilik pasif
                trailing: _selectedLanguage == "English"
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Center(child: Text("Hesap Ayarları"))),
      body: StreamBuilder<DocumentSnapshot>(
        // Firestore'daki 'users' koleksiyonunu dinliyoruz
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // Varsayılan Veriler
          String displayName = user?.displayName ?? "Kullanıcı";
          String jobTitle = "Sevkiyat Sorumlusu";

          // Firestore'da veri varsa onları al
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            displayName = data['name'] ?? displayName;
            jobTitle = data['job'] ?? jobTitle;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Profil Resmi
                const CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(
                    'https://i.pravatar.cc/150?img=12',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(jobTitle, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),

                // --- HESAP BÖLÜMÜ ---
                _buildSection("HESAP", [
                  ListTile(
                    leading: const Icon(Icons.person, color: Colors.blue),
                    title: const Text("Kişisel Bilgiler"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock, color: Colors.blue),
                    title: const Text("Şifre ve Güvenlik"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                ]),

                // --- TERCİHLER BÖLÜMÜ (GÜNCELLENDİ) ---
                _buildSection("TERCİHLER", [
                  // 1. Bildirimler (Switch Eklendi)
                  ListTile(
                    leading: const Icon(
                      Icons.notifications,
                      color: Colors.orange,
                    ),
                    title: const Text("Bildirimler"),
                    trailing: Switch(
                      value: _notificationsEnabled,
                      activeColor: const Color(0xFF0055FF),
                      onChanged: (bool value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                        // İpucu: Burada ileride bu ayarı kaydedebilirsiniz.
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? "Bildirimler Açıldı"
                                  : "Bildirimler Kapatıldı",
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),

                  // 2. Dil Seçimi (Tıklanabilir Eklendi)
                  ListTile(
                    leading: const Icon(Icons.language, color: Colors.purple),
                    title: const Text("Dil"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedLanguage,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    onTap: _showLanguageSelector, // Menüyü aç
                  ),
                ]),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    child: const Text(
                      "Çıkış Yap",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: children),
      ),
    ],
  );
}
