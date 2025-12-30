// lib/features/conductores_features/pages/conductor_profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/shared/stores/user_store.dart';
import 'package:quimisol_movil/shared/models/app_user.dart';

class ConductorProfilePage extends StatelessWidget {
  final Future<void> Function() onLogout;

  const ConductorProfilePage({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final userStore = Modular.get<UserStore>();

    return Container(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ValueListenableBuilder<AppUser?>(
          valueListenable: userStore.user,
          builder: (context, appUser, _) {
            final name = appUser?.name ?? 'Conductor';
            final email = appUser?.email ?? '—';
            final photoUrl = appUser?.photo;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? const Icon(Icons.person_rounded, size: 45)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 200,
                  child: OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
