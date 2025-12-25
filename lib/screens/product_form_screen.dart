import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'scanner_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existingProduct;
  final String? docId;
  final String? scannedSku;

  const ProductFormScreen({
    super.key,
    this.existingProduct,
    this.docId,
    this.scannedSku,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      _nameCtrl.text = widget.existingProduct!['name']?.toString() ?? '';
      _skuCtrl.text = widget.existingProduct!['sku']?.toString() ?? '';
      _stockCtrl.text = widget.existingProduct!['stock']?.toString() ?? '0';
      _priceCtrl.text = widget.existingProduct!['price']?.toString() ?? '0.0';
    } else if (widget.scannedSku != null) {
      _skuCtrl.text = widget.scannedSku!;
    }
  }

  // --- HAREKET KAYDETME (LOGLAMA) ---
  Future<void> _logMovement(String type, int qty, String name) async {
    try {
      await FirebaseFirestore.instance.collection('inventory_movements').add({
        "type": type,
        "productName": name,
        "sku": _skuCtrl.text,
        "quantity": qty,
        "date": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Loglama hatası: $e");
    }
  }

  Future<void> _saveProduct() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    final collection = FirebaseFirestore.instance.collection('inventory');
    int newStock = int.tryParse(_stockCtrl.text) ?? 0;
    double newPrice = double.tryParse(_priceCtrl.text) ?? 0.0;

    final data = {
      "name": _nameCtrl.text.trim(),
      "sku": _skuCtrl.text.trim(),
      "stock": newStock,
      "price": newPrice,
      "updatedAt": FieldValue.serverTimestamp(),
    };

    try {
      if (widget.docId != null) {
        // --- GÜNCELLEME ---
        int oldStock =
            int.tryParse(widget.existingProduct!['stock'].toString()) ?? 0;
        int diff = newStock - oldStock;

        // Fark varsa kaydet
        if (diff > 0) {
          await _logMovement("Giriş", diff, _nameCtrl.text);
        } else if (diff < 0) {
          await _logMovement("Çıkış", diff.abs(), _nameCtrl.text);
        }

        await collection.doc(widget.docId).update(data);
      } else {
        // --- YENİ EKLEME ---
        data["createdAt"] = FieldValue.serverTimestamp();
        await collection.add(data);

        // Yeni ürün giriş olarak kaydedilir
        if (newStock > 0) {
          await _logMovement("Giriş", newStock, _nameCtrl.text);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.docId != null ? "Düzenle" : "Ekle")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Ürün Adı",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skuCtrl,
                      decoration: const InputDecoration(
                        labelText: "SKU",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.qr_code),
                    onPressed: () async {
                      final code = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScannerScreen(),
                        ),
                      );
                      if (code != null) setState(() => _skuCtrl.text = code);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _stockCtrl,
                decoration: const InputDecoration(
                  labelText: "Stok",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(
                  labelText: "Fiyat",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                child: const Text("KAYDET"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
