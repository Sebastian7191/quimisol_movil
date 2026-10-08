import 'package:flutter/material.dart';
import '../../../../../core/theme/palette.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 8),
        // Logo de Quimisol
        Image(
          image: AssetImage('assets/images/logo-quimisol.png'),
          height: 90,
        ),
        SizedBox(height: 18),
        Text('BIENVENIDOS', style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Palette.primary,
        )),
        SizedBox(height: 28),
      ],
    );
  }
}
