
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../data/product_data.dart';
import 'notifications_page.dart';
import '../services/push_notification_service.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final quantityController = TextEditingController();

  int nextId = 4;
  final _push = PushNotificationService.instance;

  @override
  void initState() {
    super.initState();
    _push.addListener(_showForegroundNotification);
  }

  void _showForegroundNotification() {
    final message = _push.latestForegroundMessage;
    if (!mounted || message == null || identical(message, _lastDisplayedMessage)) {
      return;
    }
    _lastDisplayedMessage = message;
    final title = message.notification?.title ??
        message.data['title']?.toString() ?? 'Notification';
    final body = message.notification?.body ??
        message.data['body']?.toString() ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(body.isEmpty ? title : '$title — $body'),
        action: SnackBarAction(
          label: 'Voir',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
        ),
      ),
    );
  }

  Object? _lastDisplayedMessage;

  void showForm({Product? product}) {
    nameController.text = product?.name ?? '';
    descriptionController.text = product?.description ?? '';
    priceController.text = product?.price.toString() ?? '';
    quantityController.text = product?.quantity.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product == null
                      ? 'Ajouter un produit'
                      : 'Modifier le produit',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
                ),
                TextFormField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Prix'),
                  validator: (v) {
                    final value = double.tryParse(v ?? '');
                    return value == null || value < 0
                        ? 'Prix invalide'
                        : null;
                  },
                ),
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantité'),
                  validator: (v) {
                    final value = int.tryParse(v ?? '');
                    return value == null || value < 0
                        ? 'Quantité invalide'
                        : null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;

                    setState(() {
                      if (product == null) {
                        products.add(Product(
                          id: nextId++,
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim(),
                          price: double.parse(priceController.text),
                          quantity: int.parse(quantityController.text),
                        ));
                      } else {
                        product.name = nameController.text.trim();
                        product.description = descriptionController.text.trim();
                        product.price = double.parse(priceController.text);
                        product.quantity = int.parse(quantityController.text);
                      }
                    });

                    Navigator.pop(context);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void deleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer ${product.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              setState(() => products.removeWhere((p) => p.id == product.id));
              Navigator.pop(dialogContext);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _push.removeListener(_showForegroundNotification);
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des produits'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
          ),
        ],
      ),
      body: products.isEmpty
          ? const Center(child: Text('Aucun produit disponible'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];

                return Card(
                  child: ListTile(
                    title: Text(product.name),
                    subtitle: Text(
                      '${product.description}\n'
                      '${product.price.toStringAsFixed(0)} FCFA · '
                      'Stock : ${product.quantity}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          showForm(product: product);
                        } else {
                          deleteProduct(product);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Modifier'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
