import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'shipment_detail_screen.dart';

class ShipmentFormScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const ShipmentFormScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<ShipmentFormScreen> createState() => _ShipmentFormScreenState();
}

class _ShipmentFormScreenState extends State<ShipmentFormScreen> {
  // --- GİRİŞ YAPILACAK ALANLAR ---
  final _driverCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _isLoading = false;

  Future<void> _saveShipment() async {
    // İsteğe bağlı: Şoför veya Plaka boşsa uyarı verilebilir
    if (_driverCtrl.text.isEmpty || _plateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen Şoför ve Plaka bilgilerini giriniz."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Otomatik Kod Üret (SVK-...)
    final code =
        "SVK-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";

    try {
      // VERİTABANINA KAYIT (Tüm bilgilerle beraber)
      final ref = await FirebaseFirestore.instance.collection('shipments').add({
        "code": code,
        "status": "Hazırlanıyor",
        "customerId": widget.customerId, // Seçilen Müşteri ID
        "customerName": widget.customerName, // Seçilen Müşteri Adı
        "driverName": _driverCtrl.text.trim(), // Girilen Şoför
        "plateNumber": _plateCtrl.text.trim().toUpperCase(), // Girilen Plaka
        "notes": _noteCtrl.text.trim(), // Girilen Not
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        // Kayıt bitince direkt Ürün Ekleme (Detay) Sayfasına git
        // (Geri tuşuna basınca tekrar forma dönmemesi için pushReplacement kullanıyoruz)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ShipmentDetailScreen(shipmentId: ref.id, shipmentCode: code),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sevkiyat Bilgileri")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SEÇİLEN MÜŞTERİ KARTI
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SEÇİLEN MÜŞTERİ",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.business, color: Color(0xFF0055FF)),
                      const SizedBox(width: 10),
                      Text(
                        widget.customerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),
            const Text(
              "Taşıma Bilgileri",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 15),

            // ŞOFÖR ADI GİRİŞİ
            TextField(
              controller: _driverCtrl,
              decoration: const InputDecoration(
                labelText: "Şoför Adı Soyadı",
                hintText: "Örn: Ahmet Yılmaz",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_pin),
              ),
            ),
            const SizedBox(height: 15),

            // PLAKA GİRİŞİ
            TextField(
              controller: _plateCtrl,
              decoration: const InputDecoration(
                labelText: "Araç Plakası",
                hintText: "Örn: 34 ABC 123",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
            ),
            const SizedBox(height: 15),

            // NOT GİRİŞİ
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Sevkiyat Notu / Açıklama",
                hintText: "Örn: Kırılacak eşya var, dikkat edilsin.",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),

            const SizedBox(height: 30),

            // KAYDET BUTONU
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
                        "KAYDET VE ÜRÜN EKLE",
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
}
