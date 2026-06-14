// lib/features/admin/banners/widgets/dialog/banner_dialog.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

/// Resultado (UI-only). No toca data.
/// Ajusta/expande a lo que tú ya retornas si necesitas más campos.
class BannerDialogResult {
  final String titulo;
  final String subtitulo;
  final bool activo;
  final Uint8List? pickedImageBytes;

  const BannerDialogResult({
    required this.titulo,
    required this.subtitulo,
    required this.activo,
    required this.pickedImageBytes,
  });
}

class BannerDialog extends StatefulWidget {
  final String title; // "Crear banner" / "Editar banner"
  final String? initialTitulo;
  final String? initialSubtitulo;
  final bool initialActivo;

  /// Opcional: si ya tienes una imagen actual (URL) para preview
  final String? initialImageUrl;

  const BannerDialog({
    super.key,
    required this.title,
    this.initialTitulo,
    this.initialSubtitulo,
    this.initialActivo = true,
    this.initialImageUrl,
  });

  /// ✅ Abre el dialog usando root navigator (importante en Flutter Modular / nested navigators)
  static Future<BannerDialogResult?> open(
    BuildContext context, {
    required String title,
    String? initialTitulo,
    String? initialSubtitulo,
    bool initialActivo = true,
    String? initialImageUrl,
  }) {
    return showDialog<BannerDialogResult>(
      context: context,
      useRootNavigator: true, // ✅ clave para que no “se pierda” el dialog
      barrierDismissible: false,
      builder: (_) => BannerDialog(
        title: title,
        initialTitulo: initialTitulo,
        initialSubtitulo: initialSubtitulo,
        initialActivo: initialActivo,
        initialImageUrl: initialImageUrl,
      ),
    );
  }

  @override
  State<BannerDialog> createState() => _BannerDialogState();
}

class _BannerDialogState extends State<BannerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _tituloCtrl;
  late final TextEditingController _subtituloCtrl;

  bool _activo = true;

  // Imagen seleccionada desde galería
  Uint8List? _pickedBytes;

  @override
  void initState() {
    super.initState();
    _tituloCtrl = TextEditingController(text: widget.initialTitulo ?? '');
    _subtituloCtrl = TextEditingController(text: widget.initialSubtitulo ?? '');
    _activo = widget.initialActivo;
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _tituloCtrl.dispose();
    _subtituloCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _pickedBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _close() => Navigator.pop(context);

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      BannerDialogResult(
        titulo: _tituloCtrl.text.trim(),
        subtitulo: _subtituloCtrl.text.trim(),
        activo: _activo,
        pickedImageBytes: _pickedBytes,
      ),
    );
  }

  // ---------- UI helpers ----------
  static const BorderRadius _r18 = BorderRadius.all(Radius.circular(18));

  InputDecoration _decor({
    required String label,
    String? hint,
    Widget? prefixIcon,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Palette.fieldBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Palette.button.withValues(alpha: 0.20)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Palette.button.withValues(alpha: 0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Palette.button.withValues(alpha: 0.55)),
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Palette.button.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.button.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Palette.button.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.button.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: Palette.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Palette.ink.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.button.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Palette.button.withValues(alpha: 0.18),
            Palette.button.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.button.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Palette.button.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Palette.button.withValues(alpha: 0.22)),
            ),
            child: const Icon(Icons.campaign_rounded, color: Palette.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Configura título, subtítulo, estado e imagen.',
                  style: TextStyle(
                    color: Palette.ink.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _close,
            icon: Icon(Icons.close_rounded, color: Palette.ink.withValues(alpha: 0.65)),
            splashRadius: 22,
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }

  // Preview simple (no toca data)
  Widget _previewBox() {
    Widget image;
    if (_pickedBytes != null) {
      image = Image.memory(_pickedBytes!, fit: BoxFit.cover);
    } else if ((widget.initialImageUrl ?? '').trim().isNotEmpty) {
      image = Image.network(
        widget.initialImageUrl!.trim(),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
      );
    } else {
      image = Icon(Icons.image_outlined, color: Palette.ink.withValues(alpha: 0.25), size: 36);
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Palette.button.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.button.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.phone_iphone_rounded, color: Palette.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Vista previa',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Marco tipo “móvil”
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: AspectRatio(
                aspectRatio: 9 / 19.5,
                child: Container(
                  color: Palette.fieldBg,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Banner preview
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Palette.button.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Palette.button.withValues(alpha: 0.18)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: ColoredBox(
                                    color: Palette.white,
                                    child: Center(child: image),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (_tituloCtrl.text.trim().isEmpty)
                                          ? 'Título del banner'
                                          : _tituloCtrl.text.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Palette.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (_subtituloCtrl.text.trim().isEmpty)
                                          ? 'Subtítulo del banner'
                                          : _subtituloCtrl.text.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Palette.ink.withValues(alpha: 0.65),
                                        fontSize: 12.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _activo ? 'ACTIVO' : 'INACTIVO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _activo
                                ? Palette.statsSuccess
                                : Palette.ink.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Form
  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ importante dentro de scroll
        children: [
          _sectionTitle(
            icon: Icons.edit_rounded,
            title: 'Datos del banner',
            subtitle: 'Título, subtítulo y estado.',
          ),
          const SizedBox(height: 12),

          _card(
            child: Column(
              children: [
                TextFormField(
                  controller: _tituloCtrl,
                  decoration: _decor(
                    label: 'Título',
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return 'Ingresa un título';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subtituloCtrl,
                  decoration: _decor(
                    label: 'Subtítulo',
                    prefixIcon: const Icon(Icons.subtitles_rounded),
                  ),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return 'Ingresa un subtítulo';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Palette.fieldBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Palette.button.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.toggle_on_rounded, color: Palette.primary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Activo',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Palette.ink,
                          ),
                        ),
                      ),
                      Switch(
                        value: _activo,
                        onChanged: (v) => setState(() => _activo = v),
                        activeThumbColor: Palette.primary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Imagen
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_rounded),
                  label: Text(
                    _pickedBytes == null ? 'Seleccionar imagen' : 'Cambiar imagen',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.ink,
                    side: BorderSide(color: Palette.button.withValues(alpha: 0.45)),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),

                if (_pickedBytes != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _pickedBytes = null;
                      });
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Quitar imagen seleccionada'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxH = (media.size.height * 0.92).clamp(520.0, 920.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1100, maxHeight: maxH),
        child: Container(
          decoration: const BoxDecoration(
            color: Palette.white,
            borderRadius: _r18,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _topBar(),
                const SizedBox(height: 14),

                // ✅ ZONA SCROLL (segura)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final isWide = box.maxWidth >= 980;

                      if (isWide) {
                        // Desktop: form scroll a la izquierda, preview fijo a la derecha
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Scrollbar(
                                controller: _scrollCtrl,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _scrollCtrl,
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _form(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 360,
                              height: box.maxHeight,
                              child: SingleChildScrollView(
                                child: _previewBox(),
                              ),
                            ),
                          ],
                        );
                      }

                      // Móvil: 1 solo scroll que incluye form + preview (abajo)
                      return Scrollbar(
                        controller: _scrollCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.only(right: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _form(),
                              const SizedBox(height: 14),
                              _previewBox(),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // ✅ BOTONES FIJOS (fuera del scroll)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _close,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Palette.ink,
                          side: BorderSide(
                            color: Palette.button.withValues(alpha: 0.55),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.button,
                          foregroundColor: Palette.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        child: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}