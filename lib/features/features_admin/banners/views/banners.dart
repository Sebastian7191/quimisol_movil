// lib/features/banners/pages/banners.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/banners/widgets/dialog/banner_dialog.dart';
import 'package:quimisol_movil/shared/dialogs/delete_dialog.dart';




import '../controllers/banners_controller.dart';
import '../widgets/banner_empty_box.dart';
import '../widgets/banner_error_box.dart';
import '../widgets/banner_loading_grid.dart';
import '../widgets/banner_card.dart';

class BannersPage extends StatefulWidget {
  const BannersPage({super.key});

  @override
  State<BannersPage> createState() => _BannersPageState();
}

class _BannersPageState extends State<BannersPage> {
  final controller = BannersController();

  @override
  void initState() {
    super.initState();
    controller.searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _bannersStream() =>
      controller.bannersStream();

  Future<BannerDialogResult?> _showBannerDialog(Widget dialog) {
    FocusManager.instance.primaryFocus?.unfocus();

    return showDialog<BannerDialogResult>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
  }

  Future<String> _uploadBannerImage(Uint8List bytes, String docId) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'banners/$docId/$ts.jpg';
    final ref = FirebaseStorage.instance.ref().child(path);
    final task = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return task.ref.getDownloadURL();
  }

  Future<void> _openAddDialog() async {
    final res = await _showBannerDialog(
      const BannerDialog(title: 'Agregar banner'),
    );

    if (res == null) return;

    try {
      String imageUrl = '';
      if (res.pickedImageBytes != null) {
        imageUrl = await _uploadBannerImage(
          res.pickedImageBytes!,
          'new_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
      await controller.crearBanner(
        titulo: res.titulo,
        subtitulo: res.subtitulo,
        imagen: imageUrl,
        estado: res.activo ? 'ACTIVO' : 'INACTIVO',
        idproducto: '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner agregado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar banner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openEditDialog({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final existingImage = (data['imagen'] ?? '').toString();
    final isActivo = (data['estado'] ?? '').toString().toUpperCase() == 'ACTIVO';

    final res = await _showBannerDialog(
      BannerDialog(
        title: 'Editar banner',
        initialTitulo: (data['titulo'] ?? '').toString(),
        initialSubtitulo: (data['subtitulo'] ?? '').toString(),
        initialActivo: isActivo,
        initialImageUrl: existingImage.isNotEmpty ? existingImage : null,
      ),
    );

    if (res == null) return;

    try {
      String imageUrl = existingImage;
      if (res.pickedImageBytes != null) {
        imageUrl = await _uploadBannerImage(res.pickedImageBytes!, docId);
      }
      await controller.actualizarBanner(
        docId: docId,
        titulo: res.titulo,
        subtitulo: res.subtitulo,
        imagen: imageUrl,
        estado: res.activo ? 'ACTIVO' : 'INACTIVO',
        idproducto: (data['idproducto'] ?? '').toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar banner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteBanner(String docId, String titulo) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => ConfirmDeleteDialog(
        title: 'Eliminar banner',
        message: '¿Seguro que quieres eliminar "$titulo"?',
      ),
    );

    if (ok != true) return;

    try {
      await controller.eliminarBanner(docId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar banner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 640;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= HEADER =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Palette.primary.withValues(alpha: 0.95),
                      Palette.secondary.withValues(alpha: 0.90),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Palette.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Palette.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Icon(
                            Icons.campaign_rounded, // banners
                            color: Palette.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gestión de Banners',
                                style: TextStyle(
                                  fontSize: isNarrow ? 18 : 22,
                                  fontWeight: FontWeight.w900,
                                  color: Palette.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Crea y administra banners promocionales',
                                style: TextStyle(
                                  fontSize: isNarrow ? 12 : 13,
                                  color: Palette.white.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: isNarrow ? 140 : null,
                          child: ElevatedButton.icon(
                            onPressed: _openAddDialog,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(isNarrow ? 'Agregar' : 'Agregar banner'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Palette.white.withValues(alpha: 0.18),
                              foregroundColor: Palette.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: Palette.white, width: 2,
                                ),
                              ),
                              textStyle: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ===== buscador dentro del header =====
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Palette.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: Palette.ink.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: controller.searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Buscar por título o subtítulo',
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: Palette.ink.withValues(alpha: 0.35),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: const TextStyle(
                                color: Palette.ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: controller.searchCtrl,
                            builder: (_, v, __) {
                              final has = v.text.trim().isNotEmpty;
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 160),
                                transitionBuilder: (c, a) =>
                                    FadeTransition(opacity: a, child: c),
                                child: !has
                                    ? const SizedBox(width: 10, key: ValueKey('empty'))
                                    : InkWell(
                                        key: const ValueKey('clear'),
                                        onTap: () => controller.searchCtrl.clear(),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: Palette.ink.withValues(alpha: 0.55),
                                          ),
                                        ),
                                      ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ================= GRID =================
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _bannersStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return BannerErrorBox(
                        message: 'Error al cargar banners: ${snapshot.error}',
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const BannerLoadingGrid();
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final items = controller.buildCards(docs);

                    if (items.isEmpty) {
                      return const BannerEmptyBox(
                        title: 'No hay banners',
                        subtitle: 'Agrega un banner o ajusta tu búsqueda.',
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Palette.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Palette.button.withValues(alpha: 0.35),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: LayoutBuilder(
                          builder: (context, g) {
                            final isMobile = g.maxWidth < 560;

                            return GridView.builder(
                              padding: const EdgeInsets.all(14),
                              gridDelegate: isMobile
                                  ? const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 1,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      mainAxisExtent: 300,
                                    )
                                  : const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 520,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                      mainAxisExtent: 220,
                                    ),
                              itemCount: items.length,
                              itemBuilder: (_, i) {
                                final r = items[i];
                                final docId = r['docId'] as String;
                                final titulo = (r['titulo'] ?? '').toString();

                                return BannerCard(
                                  titulo: titulo,
                                  subtitulo: (r['subtitulo'] ?? '').toString(),
                                  imagen: (r['imagen'] ?? '').toString(),
                                  estado: (r['estado'] ?? '').toString(),
                                  onEdit: () => _openEditDialog(
                                    docId: docId,
                                    data: r,
                                  ),
                                  onDelete: () => _deleteBanner(docId, titulo),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}