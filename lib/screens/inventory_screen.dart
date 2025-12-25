import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
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

  // --- ARAMA & KATEGORİ ---
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

  // --- YENİ EKLENEN: GELİŞMİŞ FİLTRE DEĞİŞKENLERİ ---
  String _sortType = 'tarih'; // 'tarih', 'fiyat', 'stok'
  bool _sortAscending = false; // Artan mı Azalan mı?
  String _stockStatusFilter = 'hepsi'; // 'hepsi', 'kritik', 'tukenen'
  RangeValues _priceRange = const RangeValues(0, 50000); // Fiyat Aralığı

  final CollectionReference _inventoryRef = FirebaseFirestore.instance
      .collection('inventory');
  bool _isImporting = false;

  // --- SAYFA YÖNLENDİRMELERİ ---
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

  // --- FİLTRE MENÜSÜNÜ AÇ (BOTTOM SHEET) ---
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Tam ekran boyu için
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // BottomSheet içinde State değiştirmek için StatefulBuilder şart
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 1. SIRALAMA
                  const Text(
                    "Sıralama",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      _buildSortChip("En Yeni", 'tarih', false, setModalState),
                      _buildSortChip(
                        "Fiyat (Artan)",
                        'fiyat',
                        true,
                        setModalState,
                      ),
                      _buildSortChip(
                        "Fiyat (Azalan)",
                        'fiyat',
                        false,
                        setModalState,
                      ),
                      _buildSortChip(
                        "Stok (Azalan)",
                        'stok',
                        false,
                        setModalState,
                      ),
                      _buildSortChip(
                        "Stok (Artan)",
                        'stok',
                        true,
                        setModalState,
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  // 2. STOK DURUMU
                  const Text(
                    "Stok Durumu",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildFilterChip(
                        "Hepsi",
                        'hepsi',
                        _stockStatusFilter,
                        (val) => setModalState(() => _stockStatusFilter = val),
                      ),
                      const SizedBox(width: 10),
                      _buildFilterChip(
                        "Kritik (<10)",
                        'kritik',
                        _stockStatusFilter,
                        (val) => setModalState(() => _stockStatusFilter = val),
                      ),
                      const SizedBox(width: 10),
                      _buildFilterChip(
                        "Tükenenler",
                        'tukenen',
                        _stockStatusFilter,
                        (val) => setModalState(() => _stockStatusFilter = val),
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  // 3. FİYAT ARALIĞI
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Fiyat Aralığı",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "${_priceRange.start.toInt()} ₺ - ${_priceRange.end.toInt()} ₺",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 50000,
                    divisions: 100,
                    activeColor: const Color(0xFF0055FF),
                    labels: RangeLabels(
                      "${_priceRange.start.toInt()} ₺",
                      "${_priceRange.end.toInt()} ₺",
                    ),
                    onChanged: (RangeValues values) {
                      setModalState(() {
                        _priceRange = values;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // UYGULA BUTONU
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0055FF),
                      ),
                      onPressed: () {
                        setState(() {}); // Ana ekranı güncelle
                        Navigator.pop(context); // Kapat
                      },
                      child: const Text(
                        "FİLTRELERİ UYGULA",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // SIFIRLA BUTONU
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setModalState(() {
                          _sortType = 'tarih';
                          _sortAscending = false;
                          _stockStatusFilter = 'hepsi';
                          _priceRange = const RangeValues(0, 50000);
                        });
                      },
                      child: const Text(
                        "Sıfırla",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Yardımcı Widget: Sıralama Chip'i
  Widget _buildSortChip(
    String label,
    String type,
    bool ascending,
    StateSetter setModalState,
  ) {
    bool isSelected = _sortType == type && _sortAscending == ascending;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0055FF).withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF0055FF) : Colors.black,
      ),
      onSelected: (bool selected) {
        setModalState(() {
          _sortType = type;
          _sortAscending = ascending;
        });
      },
    );
  }

  // Yardımcı Widget: Filtre Chip'i
  Widget _buildFilterChip(
    String label,
    String value,
    String groupValue,
    Function(String) onSelected,
  ) {
    bool isSelected = groupValue == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.orange.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? Colors.orange[800] : Colors.black,
      ),
      onSelected: (bool selected) {
        if (selected) onSelected(value);
      },
    );
  }

  // --- EXCEL IMPORT ---
  Future<void> _importFromExcel() async {
    if (widget.userRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bu işlem için Admin yetkisi gereklidir."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excel Formatı"),
        content: const Text(
          "1. Ürün Adı\n2. SKU\n3. Kategori\n4. Stok\n5. Fiyat\n\n(İlk satır başlık olmalı)",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Dosya Seç"),
          ),
        ],
      ),
    );

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      setState(() => _isImporting = true);
      try {
        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);
        var table = excel.tables[excel.tables.keys.first];

        final firestore = FirebaseFirestore.instance;
        WriteBatch batch = firestore.batch();
        int count = 0;

        for (var i = 1; i < table!.rows.length; i++) {
          var row = table.rows[i];
          if (row.isEmpty || row[0] == null) continue;

          String name = row[0]?.value?.toString() ?? "İsimsiz";
          String sku = row[1]?.value?.toString() ?? "";
          String category = row[2]?.value?.toString() ?? "Genel";
          int stock = int.tryParse(row[3]?.value?.toString() ?? "0") ?? 0;
          double price =
              double.tryParse(row[4]?.value?.toString() ?? "0") ?? 0.0;

          DocumentReference newDocRef = _inventoryRef.doc();
          batch.set(newDocRef, {
            "name": name,
            "sku": sku,
            "category": category,
            "stock": stock,
            "price": price,
            "createdAt": FieldValue.serverTimestamp(),
          });

          if (stock > 0) {
            batch.set(firestore.collection('inventory_movements').doc(), {
              "type": "Giriş",
              "productName": "$name (Excel)",
              "sku": sku,
              "quantity": stock,
              "date": FieldValue.serverTimestamp(),
            });
          }

          count++;
          if (count % 400 == 0) {
            await batch.commit();
            batch = firestore.batch();
          }
        }
        await batch.commit();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$count ürün yüklendi!"),
              backgroundColor: Colors.green,
            ),
          );
      } catch (e) {
        debugPrint("Hata: $e");
      } finally {
        if (mounted) setState(() => _isImporting = false);
      }
    }
  }

  void _deleteProduct(String docId, Map<String, dynamic> item) async {
    if (widget.userRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sadece admin silebilir!"),
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
        "sku": item['sku'],
        "quantity": stock,
        "date": FieldValue.serverTimestamp(),
      });
    }
    _inventoryRef.doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Envanter"),
        actions: [
          if (widget.userRole == 'admin')
            IconButton(
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file, color: Colors.green),
              onPressed: _isImporting ? null : _importFromExcel,
            ),
          // --- YENİ FİLTRE BUTONU ---
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_stockStatusFilter != 'hepsi' ||
                    _sortType != 'tarih' ||
                    _priceRange.end != 50000)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: "Filtrele ve Sırala",
            onPressed: _openFilterSheet,
          ),
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
          // Kategori
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

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _inventoryRef
                  .snapshots(), // Hepsini çekip client-side filtreliyoruz
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                // 1. LİSTEYİ OLUŞTUR
                var docs = snapshot.data!.docs;
                List<DocumentSnapshot> filteredList = [];

                for (var doc in docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  String name = (data['name'] ?? "").toString().toLowerCase();
                  String sku = (data['sku'] ?? "").toString().toLowerCase();
                  String category = (data['category'] ?? "Genel").toString();
                  int stock = int.tryParse(data['stock'].toString()) ?? 0;
                  double price =
                      double.tryParse(data['price'].toString()) ?? 0.0;

                  // 2. FİLTRELERİ UYGULA
                  // Arama
                  if (!name.contains(_searchQuery) &&
                      !sku.contains(_searchQuery))
                    continue;
                  // Kategori
                  if (_selectedCategoryFilter != "Tümü" &&
                      category != _selectedCategoryFilter)
                    continue;
                  // Stok Durumu
                  if (_stockStatusFilter == 'kritik' && stock >= 10) continue;
                  if (_stockStatusFilter == 'tukenen' && stock > 0) continue;
                  // Fiyat Aralığı
                  if (price < _priceRange.start || price > _priceRange.end)
                    continue;

                  filteredList.add(doc);
                }

                // 3. SIRALAMA
                filteredList.sort((a, b) {
                  var dA = a.data() as Map<String, dynamic>;
                  var dB = b.data() as Map<String, dynamic>;

                  if (_sortType == 'fiyat') {
                    double pA = double.tryParse(dA['price'].toString()) ?? 0;
                    double pB = double.tryParse(dB['price'].toString()) ?? 0;
                    return _sortAscending ? pA.compareTo(pB) : pB.compareTo(pA);
                  } else if (_sortType == 'stok') {
                    int sA = int.tryParse(dA['stock'].toString()) ?? 0;
                    int sB = int.tryParse(dB['stock'].toString()) ?? 0;
                    return _sortAscending ? sA.compareTo(sB) : sB.compareTo(sA);
                  } else {
                    // Tarih (Varsayılan)
                    Timestamp tA = dA['createdAt'] ?? Timestamp.now();
                    Timestamp tB = dB['createdAt'] ?? Timestamp.now();
                    return tB.compareTo(
                      tA,
                    ); // Hep en yeni en üstte olsun default olarak
                  }
                });

                int totalProduct = filteredList.length;
                int lowStock = 0;
                for (var doc in filteredList) {
                  var d = doc.data() as Map<String, dynamic>;
                  if ((int.tryParse(d['stock'].toString()) ?? 0) < 10)
                    lowStock++;
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
                              "Sonuç",
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
                      child: filteredList.isEmpty
                          ? const Center(
                              child: Text("Filtrelere uygun ürün yok."),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                var doc = filteredList[index];
                                var item = doc.data() as Map<String, dynamic>;

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
                                    subtitle: Text(
                                      "${item['category'] ?? '-'} \nSKU: ${item['sku']}",
                                    ),
                                    isThreeLine: true,
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${item['stock']} Adet",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                (int.tryParse(
                                                          item['stock']
                                                              .toString(),
                                                        ) ??
                                                        0) <
                                                    10
                                                ? Colors.red
                                                : Colors.blue,
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
                                }
                                return GestureDetector(
                                  onTap: () =>
                                      _addOrEdit(product: item, docId: doc.id),
                                  child: cardContent,
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
