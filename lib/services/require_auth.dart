import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/auth/login_main_page.dart';
import 'package:provider/provider.dart';
import 'package:food_for_later_new/providers/role_provider.dart';

class RequireAuth extends StatelessWidget {
  final Widget child;
  final List<String> allowedRoles;

  RequireAuth({required this.child, required this.allowedRoles});

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<RoleProvider>(context).role;

    if (!allowedRoles.contains(role)) {
      return LoginPage(); // 🔹 권한 없으면 로그인 페이지로 이동
    }

    return child;
  }
}
