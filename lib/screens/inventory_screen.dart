import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_form_screen.dart';
import 'inventory_movements_screen.dart';
import 'scanner_screen.dart';

class InventoryScreen extends StatefulWidget {
  // Rol bilgisini dışarıdan alıyoruz
  final String userRole;

  // Varsayılan olarak 'personel' kabul et ki hata çıkmasın
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

  // --- SİLME VE LOGLAMA ---
  void _deleteProduct(String docId, Map<String, dynamic> item) async {
    // EKSTRA GÜVENLİK: Admin değilse fonksiyonu durdur.
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

    // Rol Kontrolü (Debug için)
    // print("Aktif Rol: ${widget.userRole}");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Envanter"),
        actions: [
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

                // İstatistik
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

                                // ÜRÜN KARTI
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

                                // YETKİ KONTROLÜ: Sadece ADMIN ise Dismissible (Kaydır-Sil) çalışır
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
                                  // Personel ise sadece tıklayıp detay görebilir/düzenleyebilir (veya düzenlemeyi de kapatabilirsin) ama SİLEMEZ.
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
