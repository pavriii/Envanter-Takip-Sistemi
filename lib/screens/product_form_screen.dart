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

  final List<String> _categories = [
    "Genel",
    "Elektronik",
    "Gıda",
    "Giyim",
    "Kırtasiye",
    "Yapı Market",
    "Kozmetik",
    "Diğer",
  ];
  String? _selectedCategory;

  // YENİ: TEDARİKÇİ SEÇİMİ İÇİN
  String? _selectedSupplierName;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      _nameCtrl.text = widget.existingProduct!['name']?.toString() ?? '';
      _skuCtrl.text = widget.existingProduct!['sku']?.toString() ?? '';
      _stockCtrl.text = widget.existingProduct!['stock']?.toString() ?? '0';
      _priceCtrl.text = widget.existingProduct!['price']?.toString() ?? '0.0';

      String savedCategory =
          widget.existingProduct!['category']?.toString() ?? "Genel";
      if (_categories.contains(savedCategory)) {
        _selectedCategory = savedCategory;
      } else {
        _selectedCategory = "Genel";
      }
    } else {
      _selectedCategory = "Genel";
      if (widget.scannedSku != null) {
        _skuCtrl.text = widget.scannedSku!;
      }
    }
  }

  // --- HAREKET KAYDI (GELİŞMİŞ) ---
  Future<void> _logMovement(
    String type,
    int qty,
    String name, {
    String? supplier,
  }) async {
    try {
      // Eğer tedarikçi seçildiyse ismini loga ekle
      String descName = name;
      if (supplier != null && supplier.isNotEmpty) {
        descName = "$name ($supplier'dan)";
      }

      await FirebaseFirestore.instance.collection('inventory_movements').add({
        "type": type,
        "productName": descName,
        "sku": _skuCtrl.text,
        "quantity": qty,
        "date": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Loglama hatası: $e");
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
      "category": _selectedCategory ?? "Genel",
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

        if (diff > 0) {
          // Stok arttıysa Giriş (Tedarikçi bilgisiyle)
          await _logMovement(
            "Giriş",
            diff,
            _nameCtrl.text,
            supplier: _selectedSupplierName,
          );
        } else if (diff < 0) {
          await _logMovement("Çıkış", diff.abs(), _nameCtrl.text);
        }

        await collection.doc(widget.docId).update(data);
      } else {
        // --- YENİ EKLEME ---
        data["createdAt"] = FieldValue.serverTimestamp();
        await collection.add(data);

        if (newStock > 0) {
          // İlk giriş (Tedarikçi bilgisiyle)
          await _logMovement(
            "Giriş",
            newStock,
            _nameCtrl.text,
            supplier: _selectedSupplierName,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Kayıt Başarılı")));
        Navigator.pop(context);
      }
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
      appBar: AppBar(
        title: Text(widget.docId != null ? "Ürün Düzenle" : "Ürün Kaydet"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Ürün Adı",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Kategori",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories
                    .map(
                      (val) => DropdownMenuItem(value: val, child: Text(val)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
              ),
              const SizedBox(height: 12),

              // --- YENİ TEDARİKÇİ SEÇİMİ ---
              // Sadece stoğun arttığı durumlarda veya yeni üründe tedarikçi sormak mantıklıdır
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Tedarikçi (Stok Girişi İçin)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 5),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('contacts')
                          .where('type', isEqualTo: 'Tedarikçi')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const LinearProgressIndicator();
                        var docs = snapshot.data!.docs;

                        return DropdownButtonFormField<String>(
                          value:
                              null, // Her girişte sıfırlansın, zorunlu olmasın
                          hint: const Text("Tedarikçi Seç (Opsiyonel)"),
                          isExpanded: true,
                          items: docs.map((doc) {
                            return DropdownMenuItem(
                              value: doc['name'].toString(),
                              child: Text(doc['name']),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedSupplierName = val);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skuCtrl,
                      decoration: const InputDecoration(
                        labelText: "SKU / Barkod",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () async {
                      final code = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScannerScreen(),
                        ),
                      );
                      if (code != null) setState(() => _skuCtrl.text = code);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0055FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _stockCtrl,
                decoration: const InputDecoration(
                  labelText: "Stok Adedi",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(
                  labelText: "Fiyat (₺)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0055FF),
                  ),
                  onPressed: _isLoading ? null : _saveProduct,
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
      ),
    );
  }
}
