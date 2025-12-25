import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isLoginMode = true; // Giriş modu mu Kayıt modu mu?
  String _selectedRole = "personel"; // Varsayılan rol

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      if (_isLoginMode) {
        // --- GİRİŞ YAPMA ---
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
        // MainNavigationWrapper zaten Auth değişikliğini dinliyor, otomatik geçecek.
      } else {
        // --- KAYIT OLMA ---
        UserCredential userCred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailCtrl.text.trim(),
              password: _passCtrl.text.trim(),
            );

        // Kullanıcıyı 'users' koleksiyonuna rolüyle birlikte kaydet
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .set({
              'email': _emailCtrl.text.trim(),
              'role': _selectedRole, // 'admin' veya 'personel'
              'createdAt': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kayıt başarılı! Giriş yapılıyor...")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person, size: 80, color: const Color(0xFF0055FF)),
              const SizedBox(height: 20),
              Text(
                _isLoginMode ? "Personel Girişi" : "Yeni Hesap Oluştur",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: "E-Posta",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Şifre",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),

              // Sadece Kayıt Modunda Rol Seçimi Göster
              if (!_isLoginMode) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedRole,
                      items: const [
                        DropdownMenuItem(
                          value: "personel",
                          child: Text("Personel (Kısıtlı Yetki)"),
                        ),
                        DropdownMenuItem(
                          value: "admin",
                          child: Text("Yönetici (Tam Yetki)"),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedRole = val!),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0055FF),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLoginMode ? "GİRİŞ YAP" : "KAYIT OL",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              TextButton(
                onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                child: Text(
                  _isLoginMode
                      ? "Hesabın yok mu? Kayıt Ol"
                      : "Zaten hesabın var mı? Giriş Yap",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
