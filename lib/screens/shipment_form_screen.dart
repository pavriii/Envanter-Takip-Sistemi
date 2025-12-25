import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShipmentFormScreen extends StatefulWidget {
  const ShipmentFormScreen({super.key});

  @override
  State<ShipmentFormScreen> createState() => _ShipmentFormScreenState();
}

class _ShipmentFormScreenState extends State<ShipmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Kontrolcüler
  final _codeCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();

  String _selectedStatus = "BEKLEYEN";
  bool _isCold = false;
  bool _isLoading = false;

  Future<void> _saveShipment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('shipments').add({
        "code": _codeCtrl.text.trim(),
        "type": _typeCtrl.text.trim(),
        "origin": _originCtrl.text.trim(),
        "destination": _destCtrl.text.trim(),
        "status": _selectedStatus,
        "date": _dateCtrl.text.trim(),
        "extra": _extraCtrl.text.trim(),
        "isCold": _isCold,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Sevkiyat oluşturuldu!")));
        Navigator.pop(context);
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
      appBar: AppBar(title: const Text("Yeni Sevkiyat")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                _codeCtrl,
                "Sevkiyat Kodu (Örn: #TR-123)",
                Icons.qr_code,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _typeCtrl,
                "Araç Tipi (Örn: Tır 20 Ton)",
                Icons.local_shipping,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _originCtrl,
                      "Çıkış",
                      Icons.my_location,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _destCtrl,
                      "Varış",
                      Icons.location_on,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _dateCtrl,
                "Tarih (Örn: 22 Ekim)",
                Icons.calendar_today,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _extraCtrl,
                "Ekstra (Örn: 40 Palet)",
                Icons.info_outline,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: "Durum",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.traffic),
                ),
                items: const [
                  DropdownMenuItem(value: "BEKLEYEN", child: Text("BEKLEYEN")),
                  DropdownMenuItem(value: "YOLDA", child: Text("YOLDA")),
                  DropdownMenuItem(
                    value: "TAMAMLANDI",
                    child: Text("TAMAMLANDI"),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedStatus = val!),
              ),
              SwitchListTile(
                title: const Text("Soğuk Zincir mi?"),
                secondary: const Icon(Icons.ac_unit, color: Colors.blue),
                value: _isCold,
                onChanged: (val) => setState(() => _isCold = val),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0055FF),
                  ),
                  onPressed: _isLoading ? null : _saveShipment,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "OLUŞTUR",
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

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (val) => val!.isEmpty ? "Gerekli" : null,
    );
  }
}
