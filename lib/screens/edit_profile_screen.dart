import 'dart:io'; // Dosya işlemleri için
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; // Resim seçmek için
import 'package:firebase_storage/firebase_storage.dart'; // Buluta yüklemek için

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Senin alanların
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final User? user = FirebaseAuth.instance.currentUser;

  // Resim yükleme değişkenleri
  File? _imageFile;
  String? _currentPhotoUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- 1. VERİLERİ ÇEKME ---
  Future<void> _loadUserData() async {
    if (user == null) return;
    setState(() => _isLoading = true);

    _emailCtrl.text = user!.email ?? "";
    _nameCtrl.text = user!.displayName ?? "";

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameCtrl.text = data['name'] ?? _nameCtrl.text;
          _phoneCtrl.text = data['phone'] ?? "";
          _jobCtrl.text = data['job'] ?? "";
          _currentPhotoUrl = data['photoUrl']; // Mevcut resmi çek
        });
      }
    } catch (e) {
      debugPrint("Hata: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. GALERİDEN RESİM SEÇME ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // --- 3. KAYDETME İŞLEMİ ---
  Future<void> _saveProfile() async {
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      String? photoUrl = _currentPhotoUrl;

      // A. Yeni resim seçildiyse Firebase Storage'a yükle
      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child('${user!.uid}.jpg');

        await storageRef.putFile(_imageFile!);
        photoUrl = await storageRef.getDownloadURL();
      }

      // B. Auth Profilini Güncelle
      await user!.updateDisplayName(_nameCtrl.text.trim());
      // Auth profil fotosunu da güncelle (isteğe bağlı ama iyidir)
      if (photoUrl != null) {
        await user!.updatePhotoURL(photoUrl);
      }

      // C. Firestore'a Detayları Yaz
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'job': _jobCtrl.text.trim(),
        'email': user!.email,
        'photoUrl': photoUrl, // Resim linkini kaydet
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profil başarıyla güncellendi!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
      appBar: AppBar(title: const Text("Profili Düzenle")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // --- FOTOĞRAF ALANI (Tıklanabilir) ---
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0055FF),
                              width: 3,
                            ),
                            color: Colors.grey[200],
                            image: _imageFile != null
                                ? DecorationImage(
                                    image: FileImage(_imageFile!),
                                    fit: BoxFit.cover,
                                  )
                                : (_currentPhotoUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            _currentPhotoUrl!,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null),
                          ),
                          child:
                              (_imageFile == null && _currentPhotoUrl == null)
                              ? const Icon(
                                  Icons.add_a_photo,
                                  size: 40,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                        // Kamera İkonu (Küçük)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0055FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Fotoğrafı değiştirmek için dokunun",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
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
                      ),
                      onPressed: _isLoading ? null : _saveProfile,
                      child: const Text(
                        "KAYDET",
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
