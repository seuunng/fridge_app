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
    try {
      print('📦 상품 로드 중...');
      List<ProductDetails> products = await _iapService.getProducts();
      if (products.isEmpty) {
        print('❌ 상품 로드 실패: 상품이 비어 있음');
      } else {
        print('✅ 상품 로드 성공: $products');
      }
      setState(() {
        _products = products;
      });
    } catch (e) {
      print('❌ 상품 로드 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상품 로드에 실패했습니다. 잠시 후 다시 시도하세요.')),
      );
    }
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
