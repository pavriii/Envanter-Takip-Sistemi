import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // E-posta genelde salt okunurdur

  bool _isLoading = false;
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- 1. VERİLERİ ÇEKME FONKSİYONU ---
  Future<void> _loadUserData() async {
    if (user == null) return;

    setState(() => _isLoading = true);

    // E-posta ve Adı Auth'tan al (Varsayılan)
    _emailCtrl.text = user!.email ?? "";
    _nameCtrl.text = user!.displayName ?? "";

    try {
      // Diğer detayları Firestore'dan al ('users' koleksiyonundan)
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _nameCtrl.text = data['name'] ?? _nameCtrl.text;
        _phoneCtrl.text = data['phone'] ?? "";
        _jobCtrl.text = data['job'] ?? "";
      }
    } catch (e) {
      debugPrint("Kullanıcı verisi çekilemedi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. VERİLERİ KAYDETME FONKSİYONU ---
  Future<void> _saveProfile() async {
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      // A. Firebase Auth Profilini Güncelle (Görünen İsim)
      await user!.updateDisplayName(_nameCtrl.text.trim());

      // B. Firestore'a Detayları Yaz (Telefon, İş vb.)
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'job': _jobCtrl.text.trim(),
        'email': user!.email, // Bilgi amaçlı veritabanında da dursun
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Varsa güncelle, yoksa oluştur

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil başarıyla güncellendi!")),
        );
        Navigator.pop(context); // Geri dön
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kişisel Bilgiler")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profil Resmi (Şimdilik Sabit)
                  const CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(
                      'https://i.pravatar.cc/150?img=12',
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildTextField("Ad Soyad", _nameCtrl, Icons.person),
                  const SizedBox(height: 16),
                  _buildTextField(
                    "E-posta",
                    _emailCtrl,
                    Icons.email,
                    isReadOnly: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    "Telefon",
                    _phoneCtrl,
                    Icons.phone,
                    inputType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField("Ünvan / Görev", _jobCtrl, Icons.work),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0055FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saveProfile,
                      child: const Text(
                        "DEĞİŞİKLİKLERİ KAYDET",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isReadOnly = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      readOnly: isReadOnly,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isReadOnly ? Colors.grey[200] : Colors.white,
      ),
    );
  }
}
