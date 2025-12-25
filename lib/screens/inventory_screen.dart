import 'dart:io'; // Dosya işlemleri için gerekli
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart'; // Dosya seçmek için
import 'package:excel/excel.dart'; // Excel okumak için
import 'product_form_screen.dart';
import 'inventory_movements_screen.dart';
import 'scanner_screen.dart';

class InventoryScreen extends StatefulWidget {
  final String userRole;

  const InventoryScreen({super.key, this.userRole = 'personel'});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = "";
  String _selectedCategoryFilter = "Tümü";
  final List<String> _filterCategories = [
    "Tümü",
    "Genel",
    "Elektronik",
    "Gıda",
    "Giyim",
    "Kırtasiye",
    "Yapı Market",
    "Kozmetik",
    "Diğer",
  ];

  final CollectionReference _inventoryRef = FirebaseFirestore.instance
      .collection('inventory');
  bool _isImporting = false; // Yükleme sırasında loading göstermek için

  void _addOrEdit({Map<String, dynamic>? product, String? docId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProductFormScreen(existingProduct: product, docId: docId),
      ),
    );
  }

  void _scanAndAddProduct() async {
    final scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    if (scannedCode != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductFormScreen(scannedSku: scannedCode),
        ),
      );
    }
  }

  // --- EXCEL'DEN TOPLU VERİ ALMA (IMPORT) ---
  Future<void> _importFromExcel() async {
    // 1. Yetki Kontrolü
    if (widget.userRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bu işlem için Admin yetkisi gereklidir."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Kullanıcıya Bilgi Ver
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excel Formatı Nasıl Olmalı?"),
        content: const Text(
          "Excel dosyanızda sütunlar sırasıyla şöyle olmalıdır:\n\n1. Ürün Adı\n2. SKU (Barkod)\n3. Kategori\n4. Stok Adedi\n5. Fiyat\n\nBaşlık satırı (ilk satır) okunmaz, veriler 2. satırdan başlamalıdır.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tamam, Dosya Seç"),
          ),
        ],
      ),
    );

    // 3. Dosya Seçimi
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'], // Sadece yeni Excel formatı
    );

    if (result != null) {
      setState(() => _isImporting = true);

      try {
        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        // İlk sayfayı al
        var table = excel.tables[excel.tables.keys.first];

        int count = 0;
        final firestore = FirebaseFirestore.instance;
        WriteBatch batch = firestore.batch(); // Toplu yazma işlemi için Batch

        // Satırları Dön (İlk satır başlık olduğu için atlıyoruz, i=1 diyoruz ama kütüphane yapısına göre değişebilir, genellikle row loop kullanırız)
        // Excel kütüphanesinde rows bir listedir.
        for (var i = 1; i < table!.rows.length; i++) {
          var row = table.rows[i];

          // Boş satır koruması
          if (row.isEmpty || row[0] == null) continue;

          // Verileri Hücrelerden Al (Güvenli Dönüşüm)
          // row[0] -> Ad, row[1] -> SKU, row[2] -> Kategori, row[3] -> Stok, row[4] -> Fiyat
          String name = row[0]?.value?.toString() ?? "İsimsiz Ürün";
          String sku = row[1]?.value?.toString() ?? "";
          String category = row[2]?.value?.toString() ?? "Genel";
          int stock = int.tryParse(row[3]?.value?.toString() ?? "0") ?? 0;
          double price =
              double.tryParse(row[4]?.value?.toString() ?? "0") ?? 0.0;

          // Yeni Doküman Referansı
          DocumentReference newDocRef = _inventoryRef.doc();

          // Batch'e Ekle (Envanter Kaydı)
          batch.set(newDocRef, {
            "name": name,
            "sku": sku,
            "category": category,
            "stock": stock,
            "price": price,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
          });

          // Batch'e Ekle (Hareket Kaydı - Giriş Logu)
          if (stock > 0) {
            DocumentReference movRef = firestore
                .collection('inventory_movements')
                .doc();
            batch.set(movRef, {
              "type": "Giriş",
              "productName": "$name (Excel)",
              "sku": sku,
              "quantity": stock,
              "date": FieldValue.serverTimestamp(),
            });
          }

          count++;

          // Firestore Batch limiti 500'dür. Eğer 400'e ulaşırsak commit yapıp sıfırlayalım.
          if (count % 400 == 0) {
            await batch.commit();
            batch = firestore.batch();
          }
        }

        // Kalanları yaz
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$count adet ürün başarıyla yüklendi!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Hata oluştu: $e"),
              backgroundColor: Colors.red,
            ),
          );
        debugPrint("Excel Import Hatası: $e");
      } finally {
        if (mounted) setState(() => _isImporting = false);
      }
    }
  }

  // --- SİLME FONKSİYONU ---
  void _deleteProduct(String docId, Map<String, dynamic> item) async {
    if (widget.userRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Yetkiniz yok! Sadece yöneticiler ürün silebilir."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int stock = int.tryParse(item['stock'].toString()) ?? 0;
    if (stock > 0) {
      await FirebaseFirestore.instance.collection('inventory_movements').add({
        "type": "Çıkış",
        "productName": "${item['name']} (Silindi)",
        "sku": item['sku'] ?? "-",
        "quantity": stock,
        "date": FieldValue.serverTimestamp(),
      });
    }
    _inventoryRef.doc(docId).delete();
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ürün silindi.")));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Envanter"),
        actions: [
          // 1. Excel Import Butonu (SADECE ADMIN)
          if (widget.userRole == 'admin')
            IconButton(
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.green,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.upload_file, color: Colors.green),
              tooltip: "Excel'den Yükle",
              onPressed: _isImporting ? null : _importFromExcel,
            ),

          // 2. Diğer Butonlar
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InventoryMovementsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanAndAddProduct,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addOrEdit(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Ürün Ara...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Kategori Filtresi
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filterCategories.length,
              itemBuilder: (context, index) {
                final category = _filterCategories[index];
                final isSelected = _selectedCategoryFilter == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0055FF),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                    backgroundColor: Colors.white,
                    onSelected: (bool selected) =>
                        setState(() => _selectedCategoryFilter = category),
                  ),
                );
              },
            ),
          ),

          const Divider(),

          // Liste
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _inventoryRef
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final allDocs = snapshot.data!.docs;

                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? "").toString().toLowerCase();
                  final sku = (data['sku'] ?? "").toString().toLowerCase();
                  final category = (data['category'] ?? "Genel").toString();

                  bool textMatch =
                      name.contains(_searchQuery) || sku.contains(_searchQuery);
                  bool categoryMatch =
                      _selectedCategoryFilter == "Tümü" ||
                      category == _selectedCategoryFilter;
                  return textMatch && categoryMatch;
                }).toList();

                int totalProduct = filteredDocs.length;
                int lowStock = 0;
                for (var doc in filteredDocs) {
                  final d = doc.data() as Map<String, dynamic>;
                  int s = int.tryParse(d['stock'].toString()) ?? 0;
                  if (s < 10) lowStock++;
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              "Gösterilen",
                              "$totalProduct",
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              "Kritik",
                              "$lowStock",
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: filteredDocs.isEmpty
                          ? const Center(child: Text("Ürün bulunamadı."))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                final item = doc.data() as Map<String, dynamic>;
                                final category = item['category'] ?? "Genel";

                                Widget cardContent = Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.withOpacity(
                                        0.1,
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2_outlined,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    title: Text(
                                      item['name'] ?? "İsimsiz",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item['sku'] ?? "-"),
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            category,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${item['stock']} Adet",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        Text("${item['price']} ₺"),
                                      ],
                                    ),
                                  ),
                                );

                                if (widget.userRole == 'admin') {
                                  return Dismissible(
                                    key: Key(doc.id),
                                    background: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onDismissed: (_) =>
                                        _deleteProduct(doc.id, item),
                                    child: GestureDetector(
                                      onTap: () => _addOrEdit(
                                        product: item,
                                        docId: doc.id,
                                      ),
                                      child: cardContent,
                                    ),
                                  );
                                } else {
                                  return GestureDetector(
                                    onTap: () => _addOrEdit(
                                      product: item,
                                      docId: doc.id,
                                    ),
                                    child: cardContent,
                                  );
                                }
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
    );
  }

  Widget _buildInfoCard(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12)),
          Text(
            val,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
