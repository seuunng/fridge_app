import 'package:flutter/material.dart';
import 'package:food_for_later_new/services/auth_service.dart';

class RoleProvider with ChangeNotifier {
  String _role = "guest"; // 🔹 기본값은 guest (비회원)

  String get role => _role;

  Future<void> fetchUserRole() async {
    _role = await AuthService().getUserRole();
    notifyListeners();
  }

  void setRole(String newRole) {
    _role = newRole;
    notifyListeners();
  }
}
