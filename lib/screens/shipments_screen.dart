import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'shipment_detail_screen.dart';
import 'shipment_form_screen.dart'; // Form ekranını import ettik

class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen({super.key});

  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  // --- YENİ SEVKİYAT SÜRECİNİ BAŞLAT ---
  void _createNewShipment() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        String? selectedCustomerId;
        String? selectedCustomerName;

        return StatefulBuilder(
          builder: (BuildContext sbContext, StateSetter setModalState) {
            return AlertDialog(
              title: const Text("Müşteri Seçimi"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Sevkiyat kime yapılacak?",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('contacts')
                        .where('type', isEqualTo: 'Müşteri')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Text("Hata oluştu");
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      var docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return const Text(
                          "Kayıtlı müşteri yok. 'Cari' menüsünden ekleyin.",
                          style: TextStyle(color: Colors.red),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "Müşteri Seçiniz",
                          prefixIcon: Icon(Icons.person),
                        ),
                        value: selectedCustomerId,
                        isExpanded: true,
                        items: docs.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(data['name'] ?? "İsimsiz"),
                          );
                        }).toList(),
                        onChanged: (val) {
                          var selectedDoc = docs.firstWhere((d) => d.id == val);
                          var selectedData =
                              selectedDoc.data() as Map<String, dynamic>;

                          setModalState(() {
                            selectedCustomerId = val;
                            selectedCustomerName = selectedData['name'];
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    "İptal",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0055FF),
                  ),
                  onPressed: selectedCustomerId == null
                      ? null
                      : () {
                          // 1. Dialogu kapat
                          Navigator.pop(dialogContext);

                          // 2. FORM SAYFASINA GİT (Müşteri bilgisiyle)
                          // İşte burası seni veri girebileceğin ekrana atıyor
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ShipmentFormScreen(
                                customerId: selectedCustomerId!,
                                customerName: selectedCustomerName!,
                              ),
                            ),
                          );
                        },
                  child: const Text(
                    "DEVAM ET",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- SİLME İŞLEMİ ---
  void _deleteShipment(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sevkiyatı Sil"),
        content: const Text("Bu sevkiyat silinecek. Emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('shipments')
                  .doc(docId)
                  .delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Sevkiyat silindi.")),
                );
              }
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sevkiyatlar")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewShipment,
        backgroundColor: const Color(0xFF0055FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "YENİ SEVKİYAT",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shipments')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Henüz sevkiyat oluşturulmadı.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              String dateStr = "-";
              if (data['createdAt'] != null) {
                dateStr = DateFormat(
                  'dd/MM/yyyy HH:mm',
                ).format((data['createdAt'] as Timestamp).toDate());
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    // Detay sayfasına giderken ID ve Kod gönderiyoruz
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ShipmentDetailScreen(
                          shipmentId: doc.id,
                          shipmentCode: data['code'],
                        ),
                      ),
                    );
                  },
                  onLongPress: () => _deleteShipment(doc.id),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: Color(0xFF0055FF),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['code'] ?? "Kodsuz",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    data['customerName'] ?? "Müşteri Seçilmedi",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              // Eğer şoför varsa onu da gösterelim
                              if (data['driverName'] != null &&
                                  data['driverName'].toString().isNotEmpty)
                                Text(
                                  "Şoför: ${data['driverName']} - ${data['plateNumber']}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[800],
                                  ),
                                ),

                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (data['status'] == 'Teslim Edildi')
                                ? Colors.green[100]
                                : Colors.orange[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            data['status'] ?? "Hazırlanıyor",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: (data['status'] == 'Teslim Edildi')
                                  ? Colors.green
                                  : Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
