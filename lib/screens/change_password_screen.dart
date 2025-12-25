import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final email = user.email;

      // 1. ADIM: Kullanıcıyı Yeniden Doğrula (Re-authenticate)
      // Şifre değişimi hassas işlem olduğu için Firebase bunu ister.
      AuthCredential credential = EmailAuthProvider.credential(
        email: email!,
        password: _currentPassCtrl.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);

      // 2. ADIM: Şifreyi Güncelle
      await user.updatePassword(_newPassCtrl.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Şifreniz başarıyla değiştirildi!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Ayarlar sayfasına dön
      }
    } on FirebaseAuthException catch (e) {
      String message = "Bir hata oluştu.";
      if (e.code == 'wrong-password') {
        message = "Mevcut şifrenizi yanlış girdiniz.";
      } else if (e.code == 'weak-password') {
        message = "Yeni şifre çok zayıf. En az 6 karakter olmalı.";
      } else if (e.code == 'requires-recent-login') {
        message = "Güvenlik gereği oturumu kapatıp tekrar açmalısınız.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Şifre ve Güvenlik")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Güvenliğiniz için şifrenizi değiştirmeden önce mevcut şifrenizi girmeniz gerekmektedir.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // MEVCUT ŞİFRE
              TextFormField(
                controller: _currentPassCtrl,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: "Mevcut Şifre",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: (val) =>
                    val!.isEmpty ? "Mevcut şifre gerekli" : null,
              ),
              const SizedBox(height: 16),

              // YENİ ŞİFRE
              TextFormField(
                controller: _newPassCtrl,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: "Yeni Şifre",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.vpn_key),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (val) {
                  if (val!.isEmpty) return "Yeni şifre gerekli";
                  if (val.length < 6) return "En az 6 karakter olmalı";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // YENİ ŞİFRE TEKRAR
              TextFormField(
                controller: _confirmPassCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: "Yeni Şifre (Tekrar)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.vpn_key),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (val) {
                  if (val != _newPassCtrl.text) return "Şifreler eşleşmiyor";
                  return null;
                },
              ),

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
                  onPressed: _isLoading ? null : _changePassword,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "ŞİFREYİ GÜNCELLE",
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
      ),
    );
  }
}
