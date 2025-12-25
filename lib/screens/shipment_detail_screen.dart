import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'shipment_add_item_screen.dart';

class ShipmentDetailScreen extends StatefulWidget {
  final String shipmentId;
  final String shipmentCode;

  const ShipmentDetailScreen({
    super.key,
    required this.shipmentId,
    required this.shipmentCode,
  });

  @override
  State<ShipmentDetailScreen> createState() => _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends State<ShipmentDetailScreen> {
  // --- SEVKİYAT DURUMUNU GÜNCELLE ---
  void _updateStatus() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Sevkiyat Durumunu Güncelle",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 20),
              _statusOption("Hazırlanıyor", Colors.orange),
              _statusOption("Yola Çıktı", Colors.blue),
              _statusOption("Teslim Edildi", Colors.green),
              _statusOption("İptal", Colors.red),
            ],
          ),
        );
      },
    );
  }

  Widget _statusOption(String status, Color color) {
    return ListTile(
      leading: Icon(Icons.circle, color: color),
      title: Text(status),
      onTap: () {
        FirebaseFirestore.instance
            .collection('shipments')
            .doc(widget.shipmentId)
            .update({'status': status});
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Durum güncellendi: $status")));
      },
    );
  }

  // --- ÜRÜNÜ İPTAL ET VE STOĞA GERİ YÜKLE ---
  void _deleteItemAndRestoreStock(
    String itemId,
    String productId,
    int qty,
    String productName,
  ) async {
    final firestore = FirebaseFirestore.instance;

    try {
      await firestore.runTransaction((transaction) async {
        // 1. Sevkiyattan sil
        DocumentReference itemRef = firestore
            .collection('shipments')
            .doc(widget.shipmentId)
            .collection('items')
            .doc(itemId);
        transaction.delete(itemRef);

        // 2. Stoğa geri ekle (Eğer ürün hala inventory'de varsa)
        if (productId.isNotEmpty) {
          DocumentReference productRef = firestore
              .collection('inventory')
              .doc(productId);
          DocumentSnapshot productSnap = await transaction.get(productRef);

          if (productSnap.exists) {
            int currentStock =
                int.tryParse(productSnap.get('stock').toString()) ?? 0;
            transaction.update(productRef, {'stock': currentStock + qty});
          }
        }

        // 3. Hareketi "Giriş (İade)" olarak kaydet
        DocumentReference movementRef = firestore
            .collection('inventory_movements')
            .doc();
        transaction.set(movementRef, {
          "type": "Giriş",
          "productName": "$productName (Sevkiyat İptal)",
          "quantity": qty,
          "date": FieldValue.serverTimestamp(),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ürün sevkiyattan çıkarıldı ve stoğa iade edildi."),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shipmentCode),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: "Durumu Değiştir",
            onPressed: _updateStatus,
          ),
        ],
      ),
      // Ekleme Butonu
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ShipmentAddItemScreen(shipmentId: widget.shipmentId),
            ),
          );
        },
        backgroundColor: const Color(0xFF0055FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "ÜRÜN YÜKLE",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Durum Göstergesi (Canlı)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('shipments')
                .doc(widget.shipmentId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              var data = snapshot.data!.data() as Map<String, dynamic>;
              String status = data['status'] ?? "Bilinmiyor";

              Color statusColor = Colors.orange;
              if (status == "Yola Çıktı") statusColor = Colors.blue;
              if (status == "Teslim Edildi") statusColor = Colors.green;
              if (status == "İptal") statusColor = Colors.red;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: statusColor.withOpacity(0.1),
                child: Center(
                  child: Text(
                    "GÜNCEL DURUM: $status",
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),

          const Divider(height: 1),

          // Yüklü Ürünler Listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shipments')
                  .doc(widget.shipmentId)
                  .collection('items')
                  .orderBy('addedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 10),
                        Text("Bu araç boş. Lütfen ürün yükleyin."),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var item = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(
                          Icons.check_box,
                          color: Colors.green,
                        ),
                        title: Text(
                          item['name'] ?? "Bilinmeyen Ürün",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("SKU: ${item['sku']}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${item['qty']} Adet",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                // Silme onayı ve işlemi
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Ürünü İndir"),
                                    content: const Text(
                                      "Bu ürün sevkiyattan çıkarılıp tekrar envantere eklenecek. Onaylıyor musunuz?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text("İptal"),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _deleteItemAndRestoreStock(
                                            doc.id,
                                            item['productId'] ?? "",
                                            int.tryParse(
                                                  item['qty'].toString(),
                                                ) ??
                                                0,
                                            item['name'] ?? "",
                                          );
                                        },
                                        child: const Text("Onayla"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
