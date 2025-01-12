import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class InAppPurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool isPremiumUser = false;

  InAppPurchaseService() {
    _subscription = _iap.purchaseStream.listen((purchaseDetailsList) {
      _handlePurchaseUpdates(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      print('인앱 결제 오류 발생: $error');
    });
  }

  /// 🔹 구매 가능한 상품 목록 가져오기
  Future<List<ProductDetails>> getProducts() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      print('인앱 결제 사용 불가');
      return [];
    }

    Set<String> productIds = {'premium_upgrade', 'remove_ads'};
    final ProductDetailsResponse response =
    await _iap.queryProductDetails(productIds);

    if (response.notFoundIDs.isNotEmpty) {
      print('상품을 찾을 수 없습니다.');
      return [];
    }

    return response.productDetails;
  }

  /// 🔹 상품 구매 함수 추가 (오류 해결)
  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// 🔹 구매 상태 감지 및 처리
  void listenToPurchaseUpdates(Stream<List<PurchaseDetails>> purchaseStream) {
    _subscription = purchaseStream.listen((purchaseDetailsList) {
      _handlePurchaseUpdates(purchaseDetailsList);
    });
  }

  /// 🔹 구매 완료 시 처리
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased) {
        await _savePremiumStatus(true);
        isPremiumUser = true;
      } else if (purchase.status == PurchaseStatus.error) {
        print('구매 실패: ${purchase.error}');
      }
    }
  }

  /// 🔹 구매 상태 저장
  Future<void> _savePremiumStatus(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremiumUser', value);
  }

  /// 🔹 구매 상태 확인
  Future<bool> getPremiumStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isPremiumUser') ?? false;
  }

  /// 🔹 객체 해제 (메모리 누수 방지)
  void dispose() {
    _subscription.cancel();
  }
}
