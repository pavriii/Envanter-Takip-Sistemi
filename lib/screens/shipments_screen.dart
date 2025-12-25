import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Veritabanı
import 'shipment_detail_screen.dart'; // Detay ekranı
import 'shipment_form_screen.dart'; // Ekleme formu

class ShipmentsScreen extends StatelessWidget {
  const ShipmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sevkiyatlar")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Firestore'dan Canlı Veri Çekme
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('shipments')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Yükleniyor durumu
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Veri yoksa
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("Henüz sevkiyat yok."));
                  }

                  final data = snapshot.data!.docs;

                  // Aktif sayısını hesapla (Sadece görsel bilgi için)
                  int activeCount = data
                      .where((doc) => doc['status'] != 'TAMAMLANDI')
                      .length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bugün: $activeCount Aktif Sevkiyat",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // Liste
                      Expanded(
                        child: ListView.builder(
                          itemCount: data.length,
                          itemBuilder: (context, index) {
                            final doc = data[index];
                            final item = doc.data() as Map<String, dynamic>;

                            // --- ÖNEMLİ: Belge ID'sini alıyoruz ---
                            final docId = doc.id;

                            return _buildShipmentCard(
                              context,
                              docId:
                                  docId, // <--- ID'yi fonksiyona gönderiyoruz
                              id: item['code'] ?? "#???",
                              type: item['type'] ?? "-",
                              from: item['origin'] ?? "-",
                              to: item['destination'] ?? "-",
                              status: item['status'] ?? "BEKLEYEN",
                              isActive: item['status'] == "YOLDA",
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // Yeni Ekleme Butonu
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ShipmentFormScreen()),
          );
        },
        backgroundColor: const Color(0xFF0055FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  // Kart Tasarımı Widget'ı
  Widget _buildShipmentCard(
    BuildContext context, {
    required String docId, // <--- YENİ PARAMETRE: Firestore Belge ID'si
    required String id, // Sevkiyat Kodu (#TR-123)
    required String type,
    required String from,
    required String to,
    required String status,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        // Tıklanınca Detay Ekranına ID ve Kodu gönderiyoruz
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShipmentDetailScreen(
              shipmentId: docId, // Veritabanı işlemleri için ID
              shipmentCode: id, // Başlıkta göstermek için Kod
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? const Border(left: BorderSide(color: Colors.blue, width: 4))
              : const Border(left: BorderSide(color: Colors.orange, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır (İkon, Kod, Durum)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_shipping, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      id,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.blue.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isActive ? Colors.blue : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(type, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),

            // Rota Bilgisi
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Çıkış",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      from,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Varış",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      to,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
