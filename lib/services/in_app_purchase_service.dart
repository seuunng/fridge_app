import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        await _updateUserRole(); // ✅ Firestore에서 `role: paid_user`로 업데이트
        isPremiumUser = true;
      } else if (purchase.status == PurchaseStatus.error) {
        print('구매 실패: ${purchase.error}');
      }
    }
  }
  /// 🔹 Firestore에서 `role`을 `paid_user`로 업데이트하는 함수
  Future<void> _updateUserRole() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'role': 'paid_user', // ✅ 구매 완료 시 `role` 변경
        });
        print('✅ Firestore: 유저 역할이 paid_user로 업데이트됨');
      } else {
        print('❌ Firestore 업데이트 실패: 로그인된 유저가 없음');
      }
    } catch (e) {
      print('❌ Firestore 업데이트 오류: $e');
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
