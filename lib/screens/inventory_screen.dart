import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_form_screen.dart';
import 'inventory_movements_screen.dart';
import 'scanner_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = "";
  final CollectionReference _inventoryRef = FirebaseFirestore.instance
      .collection('inventory');

  // --- Ekleme/Düzenleme Sayfasına Git ---
  void _addOrEdit({Map<String, dynamic>? product, String? docId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProductFormScreen(existingProduct: product, docId: docId),
      ),
    );
  }

  // --- Barkod ile Ekle ---
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

  // --- Silme ve Hareket Kaydı ---
  void _deleteProduct(String docId, Map<String, dynamic> item) async {
    // Silinen stok miktarını al
    int stock = int.tryParse(item['stock'].toString()) ?? 0;

    // Eğer stok varsa "Çıkış" olarak kaydet
    if (stock > 0) {
      await FirebaseFirestore.instance.collection('inventory_movements').add({
        "type": "Çıkış",
        "productName": "${item['name']} (Silindi)",
        "sku": item['sku'] ?? "-",
        "quantity": stock,
        "date": FieldValue.serverTimestamp(),
      });
    }

    // Ürünü sil
    _inventoryRef.doc(docId).delete();
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
          // 1. Geçmiş Hareketler Butonu
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "Hareket Kayıtları",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InventoryMovementsScreen(),
              ),
            ),
          ),
          // 2. Barkod Tarama Butonu
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: "Barkod ile Ekle",
            onPressed: _scanAndAddProduct,
          ),
          // 3. MANUEL EKLEME BUTONU (ESKİ YERİNE GELDİ)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Manuel Ürün Ekle",
            onPressed: () => _addOrEdit(),
          ),
        ],
      ),

      // FloatingActionButton KALDIRILDI
      body: Column(
        children: [
          // Arama Çubuğu
          Padding(
            padding: const EdgeInsets.all(16),
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

          // Ürün Listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _inventoryRef
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                if (!snapshot.hasData)
                  return const Center(child: Text("Veri yok"));

                final allDocs = snapshot.data!.docs;

                // İstatistikler
                int totalProduct = allDocs.length;
                int lowStock = 0;

                // Filtreleme
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? "").toString().toLowerCase();
                  final sku = (data['sku'] ?? "").toString().toLowerCase();

                  // Kritik stok hesabı
                  int stock = int.tryParse(data['stock'].toString()) ?? 0;
                  if (stock < 10) lowStock++;

                  return name.contains(_searchQuery) ||
                      sku.contains(_searchQuery);
                }).toList();

                return Column(
                  children: [
                    // Bilgi Kartları
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              "Toplam",
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
                    const SizedBox(height: 10),

                    // Liste
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? const Center(child: Text("Ürün bulunamadı."))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                final item = doc.data() as Map<String, dynamic>;

                                // Verileri güvenli çek
                                final String title =
                                    item['name']?.toString() ?? "İsimsiz";
                                final String sku =
                                    item['sku']?.toString() ?? "-";
                                final String stock =
                                    item['stock']?.toString() ?? "0";
                                final String price =
                                    item['price']?.toString() ?? "0";

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
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.inventory_2_outlined,
                                        ),
                                        title: Text(
                                          title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(sku),
                                        trailing: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "$stock Adet",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            Text("$price ₺"),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
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
    );
  }

  Widget _buildInfoCard(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title),
          Text(
            val,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
