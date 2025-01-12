import 'package:flutter/material.dart';
import 'package:food_for_later_new/services/in_app_purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchasePage extends StatefulWidget {
  @override
  _PurchasePageState createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  final InAppPurchaseService _iapService = InAppPurchaseService();
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    List<ProductDetails> products = await _iapService.getProducts();
    setState(() {
      _products = products;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('프리미엄 구매')),
      body: _products.isEmpty
          ? Center(child: CircularProgressIndicator()) // 로딩 인디케이터
          : ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          ProductDetails product = _products[index];
          return ListTile(
            title: Text(product.title),
            subtitle: Text(product.price),
            trailing: ElevatedButton(
              onPressed: () => _iapService.buyProduct(product),
              child: Text('구매하기'),
            ),
          );
        },
      ),
    );
  }
}
