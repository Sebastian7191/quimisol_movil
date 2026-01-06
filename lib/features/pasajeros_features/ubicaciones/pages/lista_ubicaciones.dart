// lib/features/perfil/ubicaciones_page.dart
//
// ✅ Lista de ubicaciones (Firestore)
// ✅ usuarios/{uid}/ubicaciones
// ✅ Muestra SOLO: nombre + dirección
// ✅ Separado por secciones de departamento
// ✅ Botón “Agregar nueva ubicación”
//    -> Abre mapa (AgregadoUbicacionPage)
//    -> ✅ YA NO GUARDA AQUÍ (para evitar duplicados)
// ✅ Eliminar ubicación
//
// Nota:
// - Si un doc no trae "direccion", se muestra fallback con coords.

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/ubicaciones/pages/agregado_ubicacion.dart';

class UbicacionesPage extends StatefulWidget {
  const UbicacionesPage({super.key});

  @override
  State<UbicacionesPage> createState() => _UbicacionesPageState();
}

class _UbicacionesPageState extends State<UbicacionesPage> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _ubicRef =>
      _fire.collection('usuarios').doc(_uid).collection('ubicaciones');

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return _ubicRef.snapshots();
  }

  Future<void> _addUbicacion() async {
    if (_uid.isEmpty) return;

    // ✅ Abrir mapa: allí se guarda en Firestore
    // ✅ Aquí NO guardamos nada para evitar duplicados
    final res = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => const AgregadoUbicacionPage()),
    );

    // Si vuelve algo o no, igual no hacemos nada.
    // El StreamBuilder se actualizará solo cuando Firestore reciba el doc.
    if (res == null) return;
  }

  Future<void> _delete(String docId) async {
    if (_uid.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ubicación'),
        content: const Text('¿Seguro que deseas eliminar esta ubicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await _ubicRef.doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    final pink = Palette.button;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: ink),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Ubicaciones',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  _SoftCircleBtn(
                    icon: Icons.add_rounded,
                    onTap: _addUbicacion,
                    fill: pink,
                    iconColor: Colors.white,
                  ),
                ],
              ),
            ),

            // Botón grande
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _PrimaryBigButton(
                text: 'Agregar nueva ubicación',
                onTap: _addUbicacion,
              ),
            ),

            Expanded(
              child: _uid.isEmpty
                  ? Center(
                      child: Text(
                        'Inicia sesión para ver tus ubicaciones.',
                        style: TextStyle(
                          color: ink.withOpacity(0.60),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _stream(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snap.error}',
                              style: TextStyle(color: ink),
                            ),
                          );
                        }
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 54,
                                    color: ink.withOpacity(0.28),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Aún no tienes ubicaciones guardadas.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ink.withOpacity(0.65),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Agrega una ubicación para entregas más rápidas.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ink.withOpacity(0.50),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // ✅ Agrupar por departamento
                        final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
                            grouped = {};
                        for (final d in docs) {
                          final data = d.data();
                          final depto =
                              (data['departamento'] ?? '').toString().trim();
                          final key =
                              depto.isEmpty ? 'Sin departamento' : depto;
                          grouped.putIfAbsent(key, () => []).add(d);
                        }

                        // Orden secciones: alfabético, "Sin departamento" al final
                        final sections = grouped.keys.toList()
                          ..sort((a, b) {
                            if (a == 'Sin departamento') return 1;
                            if (b == 'Sin departamento') return -1;
                            return a.toLowerCase().compareTo(b.toLowerCase());
                          });

                        final flat = _flatten(sections, grouped);

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                          itemCount: flat.length,
                          itemBuilder: (context, index) {
                            final item = flat[index];

                            if (item is _DeptHeader) {
                              return _DeptSectionHeader(title: item.title);
                            }

                            final it = item as _UbicItem;
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _UbicCard(
                                nombre: it.nombre,
                                direccion: it.direccion,
                                onDelete: () => _delete(it.docId),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> _flatten(
    List<String> sections,
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped,
  ) {
    final out = <dynamic>[];

    for (final s in sections) {
      out.add(_DeptHeader(s));

      final list = grouped[s]!;
      // ordenar ubicaciones por nombre
      list.sort((a, b) {
        final an = (a.data()['nombre'] ?? '').toString().toLowerCase();
        final bn = (b.data()['nombre'] ?? '').toString().toLowerCase();
        return an.compareTo(bn);
      });

      for (final d in list) {
        final data = d.data();
        final nombre = (data['nombre'] ?? 'Ubicación').toString();

        // Dirección: campo real "direccion" (preferido)
        var direccion =
            (data['direccion'] ?? data['address'] ?? '').toString().trim();

        // fallback por si solo guardaron coords
        if (direccion.isEmpty) {
          final latRaw = data['lat'] ?? data['latitud'];
          final lngRaw = data['lng'] ?? data['longitud'];
          final lat = (latRaw is num)
              ? latRaw.toDouble()
              : double.tryParse(latRaw?.toString() ?? '');
          final lng = (lngRaw is num)
              ? lngRaw.toDouble()
              : double.tryParse(lngRaw?.toString() ?? '');
          if (lat != null && lng != null) {
            direccion =
                'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
          }
        }

        out.add(
          _UbicItem(
            docId: d.id,
            nombre: nombre,
            direccion: direccion.isEmpty ? 'Dirección no disponible' : direccion,
          ),
        );
      }
    }

    return out;
  }
}

/* ---------------- UI ---------------- */

class _DeptSectionHeader extends StatelessWidget {
  const _DeptSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: ink.withOpacity(0.85),
                fontWeight: FontWeight.w900,
                fontSize: 13.2,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Container(
            height: 1,
            width: 90,
            color: ink.withOpacity(0.10),
          ),
        ],
      ),
    );
  }
}

class _UbicCard extends StatefulWidget {
  const _UbicCard({
    required this.nombre,
    required this.direccion,
    required this.onDelete,
  });

  final String nombre;
  final String direccion;
  final VoidCallback onDelete;

  @override
  State<_UbicCard> createState() => _UbicCardState();
}

class _UbicCardState extends State<_UbicCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    final pink = Palette.button;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        scale: _down ? 0.992 : 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: Palette.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ink.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: pink.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: Palette.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      widget.direccion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink.withOpacity(0.62),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SoftCircleBtn(
                icon: Icons.delete_outline_rounded,
                onTap: widget.onDelete,
                fill: const Color(0xFFFF3B30).withOpacity(0.10),
                iconColor: const Color(0xFFFF3B30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftCircleBtn extends StatelessWidget {
  const _SoftCircleBtn({
    required this.icon,
    required this.onTap,
    required this.fill,
    required this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color fill;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.ink.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

class _PrimaryBigButton extends StatefulWidget {
  const _PrimaryBigButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  State<_PrimaryBigButton> createState() => _PrimaryBigButtonState();
}

class _PrimaryBigButtonState extends State<_PrimaryBigButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final pink = Palette.button;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        scale: _down ? 0.99 : 1,
        child: Container(
          height: 58,
          width: double.infinity,
          decoration: BoxDecoration(
            color: pink,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_location_alt_outlined,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                widget.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------- Helpers para “secciones” ---------------- */

class _DeptHeader {
  final String title;
  _DeptHeader(this.title);
}

class _UbicItem {
  final String docId;
  final String nombre;
  final String direccion;

  _UbicItem({
    required this.docId,
    required this.nombre,
    required this.direccion,
  });
}
