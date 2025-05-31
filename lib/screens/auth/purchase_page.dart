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
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _iapService.restorePurchases(); // 🔹 앱 실행 시 구독 상태 확인
  }

  Future<void> _loadProducts() async {
    try {
      print('📦 상품 로드 중...');
      final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails({'premium_upgrade_yearly'}.toSet());

      if (response.notFoundIDs.isNotEmpty) {
        print('❌ [IAP] 찾을 수 없는 상품 ID: ${response.notFoundIDs}');
      }
      if (response.productDetails.isEmpty) {
        print('❌ [IAP] 불러온 상품 없음 (조회는 됐지만 없음)');
      }
      List<ProductDetails> products = await _iapService.getProducts();
      if (products.isEmpty) {
        print('❌ 상품 로드 실패: 상품이 비어 있음');
        setState(() {
          _loadFailed = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
      setState(() {
        _products = products;
      });
    } catch (e) {
      print('❌ 상품 로드 중 오류 발생: $e');
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상품 로드에 실패했습니다. 잠시 후 다시 시도하세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('프리미엄 업그레이드')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🔹 헤더 섹션
            Text(
              "프리미엄으로 업그레이드하면",
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              "더 많은 기능과 혜택을 사용할 수 있습니다!😄",
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),

            // 🔹 혜택 리스트
            Expanded(
              child: ListView(
                children: [
                  _buildFeatureItem(
                    context,
                    icon: Icons.kitchen,
                    title: "추가 공간을 만들어요",
                    description: "냉장, 냉동, 상온 단 3개의 분류로는 냉장고 관리가 어려우신가요? 냉장고를 효율적으로 관리하세요.",
                  ),
                  _buildFeatureItem(
                    context,
                    icon: Icons.food_bank,
                    title: "식품의 정보를 내맘대로 수정해요",
                    description: "내 손 안에서 내가 원하는 대로, 냉장고 관리의 새로운 기준!",
                  ),
                  _buildFeatureItem(
                    context,
                    icon: Icons.remove_circle_outline,
                    title: "광고없이 편안해요",
                    description: "지금 바로 스트레스 없는 완벽한 경험을 시작하세요!",
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // 🔹 CTA 버튼
            // _isLoading
            //     ? Center(child: CircularProgressIndicator()) // 로딩 인디케이터
            //     : (_loadFailed || _products.isEmpty)
            //     ? Column(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     Icon(Icons.error_outline, color: Colors.red, size: 48),
            //     SizedBox(height: 12),
            //     Text("상품 정보를 불러오지 못했습니다.", style: TextStyle(color: Colors.red)),
            //     SizedBox(height: 8),
            //     ElevatedButton(
            //       onPressed: () {
            //         setState(() {
            //           _isLoading = true;
            //           _loadFailed = false;
            //         });
            //         _loadProducts(); // 🔁 재시도
            //       },
            //       child: Text("다시 시도하기"),
            //     ),
            //   ],
            // )
            //     : Flexible(
            //         child: ListView.builder(
            //           shrinkWrap: true, // 내부 콘텐츠에 맞게 크기 축소
            //           physics: NeverScrollableScrollPhysics(),
            //           itemCount: _products.length,
            //           itemBuilder: (context, index) {
            //             ProductDetails product = _products[index];
            //             return ListTile(
            //               title: Text('프리미엄 구독',
            //                 style: TextStyle(
            //                     color: theme.colorScheme.onSurface
            //                 ),),
            //               subtitle: Text('${product.price} / 연간',
            //                 style: TextStyle(
            //                     color: theme.colorScheme.onSurface
            //                 ),),
            //               trailing: ElevatedButton(
            //                 onPressed: () => _iapService.buyProduct(product),
            //                 child: Text('구독하기'),
            //               ),
            //             );
            //           },
            //         ),
            //       ),
            // ElevatedButton(
            //   onPressed: () => _iapService.buyProduct(product),
            //   style: ElevatedButton.styleFrom(
            //     padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(30),
            //     ),
            //     backgroundColor: theme.primaryColor,
            //   ),
            //   child: Text(
            //     "지금 프리미엄으로 업그레이드",
            //     style: theme.textTheme.labelLarge?.copyWith(
            //       color: Colors.white,
            //       fontSize: 18,
            //     ),
            //   ),
            // ),

            // 🔹 추가 정보
            Text(
              "구매 후 언제든지 취소 가능합니다.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 프리미엄 혜택 리스트 아이템
  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.onSurface),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
