import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- KİŞİ EKLEME/DÜZENLEME DİYALOĞU ---
  void _showContactDialog({
    DocumentSnapshot? existingDoc,
    required String type,
  }) {
    final nameCtrl = TextEditingController(text: existingDoc?['name']);
    final phoneCtrl = TextEditingController(text: existingDoc?['phone']);
    final emailCtrl = TextEditingController(text: existingDoc?['email']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingDoc == null ? "$type Ekle" : "$type Düzenle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: "Firma / Kişi Adı",
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: "Telefon",
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: "E-Posta",
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0055FF),
            ),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;

              final data = {
                'name': nameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'type': type, // 'Müşteri' veya 'Tedarikçi'
                'createdAt': FieldValue.serverTimestamp(),
              };

              if (existingDoc == null) {
                await FirebaseFirestore.instance
                    .collection('contacts')
                    .add(data);
              } else {
                await existingDoc.reference.update(data);
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- LİSTE GÖRÜNÜMÜ ---
  Widget _buildList(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('contacts')
          .where('type', isEqualTo: type)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              "Henüz $type eklenmemiş.",
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: type == 'Müşteri'
                      ? Colors.green[100]
                      : Colors.orange[100],
                  child: Icon(
                    type == 'Müşteri' ? Icons.person : Icons.local_shipping,
                    color: type == 'Müşteri' ? Colors.green : Colors.orange,
                  ),
                ),
                title: Text(
                  data['name'] ?? "İsimsiz",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(data['phone'] ?? ""),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () =>
                      _showContactDialog(existingDoc: doc, type: type),
                ),
                onLongPress: () {
                  // Basılı tutunca silme onayı
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text("Silinsin mi?"),
                      content: Text("${data['name']} silinecek."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text("İptal"),
                        ),
                        TextButton(
                          onPressed: () {
                            doc.reference.delete();
                            Navigator.pop(c);
                          },
                          child: const Text(
                            "Sil",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cari Hesaplar"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0055FF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0055FF),
          tabs: const [
            Tab(text: "Müşteriler"),
            Tab(text: "Tedarikçiler"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildList("Müşteri"), _buildList("Tedarikçi")],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Hangi sekmedeyse ona göre ekleme yapar
          String type = _tabController.index == 0 ? "Müşteri" : "Tedarikçi";
          _showContactDialog(type: type);
        },
        backgroundColor: const Color(0xFF0055FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("YENİ EKLE", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
