
import 'package:flutter/material.dart';
import '../models/product.dart';
import 'notifications_page.dart';
import '../services/push_notification_service.dart';
import '../services/product_api_service.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final quantityController = TextEditingController();

  final _productsApi = ProductApiService();
  final _push = PushNotificationService.instance;
  List<Product> products = [];
  bool _isLoadingProducts = true;
  String? _productsError;

  @override
  void initState() {
    super.initState();
    _lastDisplayedMessage = _push.latestForegroundMessage;
    _push.addListener(_showForegroundNotification);
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final loadedProducts = await _productsApi.fetchProducts();
      if (!mounted) return;
      setState(() {
        products = loadedProducts;
        _productsError = null;
        _isLoadingProducts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _productsError = error.toString();
        _isLoadingProducts = false;
      });
    }
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
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                  onPressed: () => _saveProduct(product),
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProduct(Product? existingProduct) async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final name = nameController.text.trim();
      final description = descriptionController.text.trim();
      final price = double.parse(priceController.text);
      final quantity = int.parse(quantityController.text);
      final savedProduct = existingProduct == null
          ? await _productsApi.createProduct(
              name: name,
              description: description,
              price: price,
              quantity: quantity,
            )
          : await _productsApi.updateProduct(
              id: existingProduct.id,
              name: name,
              description: description,
              price: price,
              quantity: quantity,
            );
      if (!mounted) return;
      setState(() {
        final index = products.indexWhere((item) => item.id == savedProduct.id);
        if (index == -1) {
          products.add(savedProduct);
        } else {
          products[index] = savedProduct;
        }
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(existingProduct == null ? 'Produit ajouté.' : 'Produit modifié.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Enregistrement impossible. Vérifiez les champs et réessayez.'),
      ));
    }
  }

  Future<void> _deleteProduct(Product product) async {
    try {
      await _productsApi.deleteProduct(product.id);
      if (!mounted) return;
      setState(() => products.removeWhere((item) => item.id == product.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit supprimé.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('La suppression a échoué. Réessayez.'),
      ));
    }
  }

  @override
  void dispose() {
    _push.removeListener(_showForegroundNotification);
    _productsApi.close();
    _searchController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visibleProducts = products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inventaire',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Text(
              'Vos produits, en un coup d’œil.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF74788A),
                  ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF5264D8), Color(0xFF7887F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x225264D8),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PRODUITS EN STOCK',
                          style: TextStyle(
                            color: Color(0xFFDCE0FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLoadingProducts ? '…' : '${products.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Articles dans votre inventaire',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0x33FFFFFF),
                    child: Icon(Icons.inventory_2_outlined,
                        color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher un produit',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tous les produits',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                  ),
                ),
                Text(
                  '${visibleProducts.length} article${visibleProducts.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Color(0xFF85899A)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingProducts)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_productsError != null)
              _EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Connexion impossible',
                message: 'Vérifiez votre connexion, puis réessayez.',
                action: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoadingProducts = true;
                      _productsError = null;
                    });
                    _loadProducts();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              )
            else if (visibleProducts.isEmpty)
              _EmptyState(
                icon: query.isEmpty
                    ? Icons.inventory_2_outlined
                    : Icons.search_off_rounded,
                title: query.isEmpty ? 'Inventaire vide' : 'Aucun résultat',
                message: query.isEmpty
                    ? 'Ajoutez un produit pour commencer.'
                    : 'Essayez un autre nom ou mot-clé.',
              )
            else
              ...visibleProducts.map(_productCard),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
    );
  }

  Widget _productCard(Product product) {
    final lowStock = product.quantity <= 5;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1FF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  color: Color(0xFF5264D8)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF85899A)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${product.price.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: lowStock
                              ? const Color(0xFFFFF1E9)
                              : const Color(0xFFEAF7F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Stock ${product.quantity}',
                          style: TextStyle(
                            color: lowStock
                                ? const Color(0xFFB85D28)
                                : const Color(0xFF32805A),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (value) {
                if (value == 'edit') showForm(product: product);
                if (value == 'delete') _deleteProduct(product);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 18),
        child: Column(
          children: [
            Icon(icon, size: 42, color: const Color(0xFF9A9EAE)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF85899A))),
            if (action != null) ...[const SizedBox(height: 10), action!],
          ],
        ),
      );
}
