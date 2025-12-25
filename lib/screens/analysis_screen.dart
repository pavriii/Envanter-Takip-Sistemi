import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  // Para formatı yardımcısı
  String _formatMoney(double amount) {
    return "₺${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text(
          "Yönetim Paneli",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      // 1. STREAM: Envanter Verisi
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('inventory').snapshots(),
        builder: (context, inventorySnap) {
          // 2. STREAM: Hareket Verisi
          return StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('inventory_movements').snapshots(),
            builder: (context, movementSnap) {
              // 3. STREAM: Sevkiyat Verisi
              return StreamBuilder<QuerySnapshot>(
                stream: firestore.collection('shipments').snapshots(),
                builder: (context, shipmentSnap) {
                  // --- YÜKLENİYOR KONTROLÜ ---
                  if (!inventorySnap.hasData ||
                      !movementSnap.hasData ||
                      !shipmentSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // --- HESAPLAMALAR (HER VERİ GELDİĞİNDE YENİDEN YAPILIR) ---

                  // A. Envanter Analizi
                  double totalValue = 0.0;
                  int totalStock = 0;
                  int criticalStock = 0;
                  int totalProducts = inventorySnap.data!.docs.length;

                  for (var doc in inventorySnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    int stock = int.tryParse(data['stock'].toString()) ?? 0;
                    double price =
                        double.tryParse(data['price'].toString()) ?? 0.0;

                    totalValue += (stock * price);
                    totalStock += stock;
                    if (stock < 10) criticalStock++;
                  }

                  // B. Hareket Analizi
                  int totalIn = 0;
                  int totalOut = 0;

                  for (var doc in movementSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    String type = data['type'] ?? "";
                    int qty = int.tryParse(data['quantity'].toString()) ?? 0;

                    if (type == "Giriş") totalIn += qty;
                    if (type == "Çıkış") totalOut += qty;
                  }

                  // C. Sevkiyat Analizi
                  int activeShipments = 0;
                  int completedShipments = 0;

                  for (var doc in shipmentSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    String status = data['status'] ?? "";
                    if (status == "Teslim Edildi") {
                      completedShipments++;
                    } else if (status != "İptal") {
                      activeShipments++;
                    }
                  }

                  // --- ARAYÜZ ---
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mavi Finans Kartı
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0055FF), Color(0xFF0033AA)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Toplam Stok Değeri",
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _formatMoney(totalValue),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  _miniBadge(
                                    Icons.layers,
                                    "$totalProducts Çeşit Ürün",
                                  ),
                                  const SizedBox(width: 10),
                                  _miniBadge(
                                    Icons.warning,
                                    "$criticalStock Kritik",
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          "Operasyon Özeti",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // İstatistik Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 1.4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          children: [
                            _statCard(
                              "Toplam Stok",
                              "$totalStock",
                              Icons.inventory_2,
                              Colors.blue,
                            ),
                            _statCard(
                              "Aktif Sevkiyat",
                              "$activeShipments",
                              Icons.local_shipping,
                              Colors.orange,
                            ),
                            _statCard(
                              "Toplam Giriş",
                              "+$totalIn",
                              Icons.arrow_downward,
                              Colors.green,
                            ),
                            _statCard(
                              "Toplam Çıkış",
                              "-$totalOut",
                              Icons.arrow_upward,
                              Colors.red,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Sevkiyat Başarı Kartı
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              CircularProgressIndicator(
                                value:
                                    (activeShipments + completedShipments) == 0
                                    ? 0
                                    : completedShipments /
                                          (activeShipments +
                                              completedShipments),
                                strokeWidth: 8,
                                color: Colors.green,
                                backgroundColor: Colors.grey[200],
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Tamamlanan Sevkiyatlar",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "$completedShipments araç başarıyla teslim edildi.",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- YARDIMCI WIDGET'LAR ---

  Widget _miniBadge(
    IconData icon,
    String text, {
    Color color = Colors.white24,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
