import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product.dart';

class ProductDeleteResult {
  const ProductDeleteResult({
    required this.product,
    required this.pushTriggered,
  });

  final Product product;
  final bool pushTriggered;
}

class ProductApiService {
  static const _productsUrl = String.fromEnvironment(
    'PRODUCTS_API_URL',
    defaultValue: 'http://127.0.0.1:3000/learn-flutter/products',
  );

  final http.Client _client;

  ProductApiService({http.Client? client}) : _client = client ?? http.Client();

  Uri get _baseUri => Uri.parse(_productsUrl);

  Future<List<Product>> fetchProducts() async {
    final response = await _client
        .get(_baseUri)
        .timeout(const Duration(seconds: 12));
    _ensureSuccess(response);
    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList(growable: true);
  }

  Future<Product> createProduct({
    required String name,
    required String description,
    required double price,
    required int quantity,
  }) async {
    final response = await _client
        .post(
          _baseUri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(_productBody(name, description, price, quantity)),
        )
        .timeout(const Duration(seconds: 12));
    _ensureSuccess(response);
    return Product.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Product> updateProduct({
    required int id,
    required String name,
    required String description,
    required double price,
    required int quantity,
  }) async {
    final response = await _client
        .put(
          _baseUri.replace(path: '${_baseUri.path}/$id'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(_productBody(name, description, price, quantity)),
        )
        .timeout(const Duration(seconds: 12));
    _ensureSuccess(response);
    return Product.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ProductDeleteResult> deleteProduct(int id) async {
    final response = await _client
        .delete(_baseUri.replace(path: '${_baseUri.path}/$id'))
        .timeout(const Duration(seconds: 12));
    _ensureSuccess(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductDeleteResult(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      pushTriggered:
          (json['notification'] as Map<String, dynamic>?)?['triggered'] == true,
    );
  }

  Map<String, Object> _productBody(
          String name, String description, double price, int quantity) =>
      {
        'name': name,
        'description': description,
        'price': price,
        'quantity': quantity,
      };

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final message = response.body.isEmpty
        ? 'Erreur HTTP ${response.statusCode}'
        : response.body;
    throw Exception(message.length > 300 ? message.substring(0, 300) : message);
  }

  void close() => _client.close();
}
