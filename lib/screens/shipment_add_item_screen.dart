import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShipmentAddItemScreen extends StatefulWidget {
  final String shipmentId; // Hangi araca eklenecek

  const ShipmentAddItemScreen({super.key, required this.shipmentId});

  @override
  State<ShipmentAddItemScreen> createState() => _ShipmentAddItemScreenState();
}

class _ShipmentAddItemScreenState extends State<ShipmentAddItemScreen> {
  final _qtyCtrl = TextEditingController();

  // Seçilen ürünün bilgileri
  String? _selectedProductId;
  String? _selectedProductName;
  String? _selectedProductSku;
  int _currentStock = 0;

  bool _isLoading = false;

  // --- KRİTİK İŞLEM: SEVKİYATA EKLE VE STOKTAN DÜŞ ---
  Future<void> _addItemAndDeductStock() async {
    if (_selectedProductId == null || _qtyCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen ürün ve adet seçiniz.")),
      );
      return;
    }

    int quantity = int.tryParse(_qtyCtrl.text) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Geçersiz miktar.")));
      return;
    }

    if (quantity > _currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Yetersiz Stok! Envanterde bu kadar ürün yok."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final firestore = FirebaseFirestore.instance;

    try {
      // TRANSACTION: Tüm işlemler ya hep yapılır ya hiç yapılmaz (Güvenlik için)
      await firestore.runTransaction((transaction) async {
        // 1. Ürünün en güncel halini referans al
        DocumentReference productRef = firestore
            .collection('inventory')
            .doc(_selectedProductId);
        DocumentSnapshot productSnapshot = await transaction.get(productRef);

        if (!productSnapshot.exists) throw Exception("Ürün bulunamadı!");

        int latestStock =
            int.tryParse(productSnapshot.get('stock').toString()) ?? 0;

        // Son bir kez daha stok kontrolü
        if (quantity > latestStock) {
          throw Exception("Stok yetersiz! Güncel stok: $latestStock");
        }

        // 2. Stoğu Düş
        transaction.update(productRef, {'stock': latestStock - quantity});

        // 3. Sevkiyatın içine ürünü ekle
        DocumentReference shipmentItemRef = firestore
            .collection('shipments')
            .doc(widget.shipmentId)
            .collection('items')
            .doc(); // Yeni ID oluştur

        transaction.set(shipmentItemRef, {
          "productId": _selectedProductId,
          "name": _selectedProductName,
          "sku": _selectedProductSku,
          "qty": quantity,
          "addedAt": FieldValue.serverTimestamp(),
          "isLoaded": true, // Yüklendi olarak işaretle
        });

        // 4. Hareket Kayıtlarına "Çıkış" (Sevkiyat) olarak işle
        DocumentReference movementRef = firestore
            .collection('inventory_movements')
            .doc();
        transaction.set(movementRef, {
          "type": "Çıkış",
          "productName": "$_selectedProductName (Sevkiyat)",
          "sku": _selectedProductSku,
          "quantity": quantity,
          "date": FieldValue.serverTimestamp(),
          "shipmentId": widget.shipmentId, // Hangi sevkiyata gittiği
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ürün araca yüklendi ve stoktan düşüldü."),
          ),
        );
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
      appBar: AppBar(title: const Text("Sevkiyata Ürün Yükle")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Envanterden Ürün Seç:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // --- ENVANTER LİSTESİ (DROPDOWN) ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('inventory')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                List<DropdownMenuItem<String>> items = [];
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  int stock = int.tryParse(data['stock'].toString()) ?? 0;

                  // Sadece stoğu olan ürünleri listele
                  if (stock > 0) {
                    items.add(
                      DropdownMenuItem(
                        value: doc.id,
                        child: Text("${data['name']} (Stok: $stock)"),
                        onTap: () {
                          // Seçilen ürünün detaylarını hafızaya al
                          setState(() {
                            _selectedProductName = data['name'];
                            _selectedProductSku = data['sku'];
                            _currentStock = stock;
                          });
                        },
                      ),
                    );
                  }
                }

                if (items.isEmpty)
                  return const Text("Stokta yüklenecek ürün yok.");

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text("Ürün Seçiniz"),
                      value: _selectedProductId,
                      items: items,
                      onChanged: (value) {
                        setState(() {
                          _selectedProductId = value;
                        });
                      },
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(
                labelText: "Yüklenecek Adet",
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0055FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _addItemAndDeductStock,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.archive, color: Colors.white),
                label: const Text(
                  "ARACA YÜKLE & STOKTAN DÜŞ",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
            const Center(
              child: Text(
                "Dikkat: Bu işlem envanterden ürün düşer.",
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
