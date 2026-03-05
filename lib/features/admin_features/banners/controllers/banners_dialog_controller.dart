// lib/features/banners/controllers/banners_dialog_controller.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class BannerProductOption {
  final String id;
  final String nombre;
  final String imagenUrl;

  const BannerProductOption({
    required this.id,
    required this.nombre,
    required this.imagenUrl,
  });
}

class BannersDialogController {
  BannersDialogController({
    String initialTitulo = '',
    String initialSubtitulo = '',
    String initialImagen = '',
    String initialEstado = 'ACTIVO',
    String initialIdProducto = '',
  }) {
    tituloCtrl = TextEditingController(text: initialTitulo);
    subtituloCtrl = TextEditingController(text: initialSubtitulo);

    // compat
    idProductoCtrl = TextEditingController(text: initialIdProducto);

    _estado = (initialEstado).toUpperCase();
    if (_estado != 'ACTIVO' && _estado != 'INACTIVO') _estado = 'ACTIVO';

    _uploadedBannerUrl = initialImagen.trim().isEmpty ? null : initialImagen.trim();

    // listeners -> refrescar preview + marcar "touched" cuando el user escribe
    tituloCtrl.addListener(() {
      _tituloTouched = true;
      _tick();
    });
    subtituloCtrl.addListener(() {
      _subtituloTouched = true;
      _tick();
    });
    idProductoCtrl.addListener(_tick);
  }

  // fields
  late final TextEditingController tituloCtrl;
  late final TextEditingController subtituloCtrl;
  late final TextEditingController idProductoCtrl;

  // preview tick
  final ValueNotifier<int> previewTick = ValueNotifier<int>(0);
  void _tick() => previewTick.value++;

  // estado
  String _estado = 'ACTIVO';
  String get estado => _estado;
  void setEstado(String v) {
    _estado = v.toUpperCase();
    if (_estado != 'ACTIVO' && _estado != 'INACTIVO') _estado = 'ACTIVO';
    _tick();
  }

  // productos
  BannerProductOption? selectedProduct;
  List<BannerProductOption> products = const [];
  bool loadingProducts = false;

  // ✅ touched flags (para no pisar lo que el user editó)
  bool _tituloTouched = false;
  bool _subtituloTouched = false;

  // ✅ default descuento cuando eliges producto (editable luego)
  // si después guardas "descuento" en producto/banner, cambia esto.
  String defaultDiscount = '20%';

  Future<void> loadProducts() async {
    loadingProducts = true;
    _tick();

    final snap = await FirebaseFirestore.instance
        .collection('productos')
        .orderBy('nombre')
        .get();

    products = snap.docs.map((d) {
      final data = d.data();
      return BannerProductOption(
        id: d.id,
        nombre: (data['nombre'] ?? '').toString(),
        // tu data puede venir como imagen o imagenUrl
        imagenUrl: (data['imagen'] ?? data['imagenUrl'] ?? '').toString(),
      );
    }).toList();

    // si venía idproducto inicial, intenta seleccionar (modo edición)
    final initialId = idProductoCtrl.text.trim();
    if (initialId.isNotEmpty && selectedProduct == null) {
      final found = products.where((p) => p.id == initialId).toList();
      if (found.isNotEmpty) {
        // en edición, NO queremos forzar defaults si ya había valores iniciales
        // por eso marcamos touched si ya venían con texto.
        if (tituloCtrl.text.trim().isNotEmpty) _tituloTouched = true;
        if (subtituloCtrl.text.trim().isNotEmpty) _subtituloTouched = true;

        selectProduct(found.first, applyDefaults: false);
      }
    }

    loadingProducts = false;
    _tick();
  }

  /// Selecciona producto (opcional) y aplica defaults si corresponde
  void selectProduct(
    BannerProductOption? p, {
    bool applyDefaults = true,
  }) {
    selectedProduct = p;
    idProductoCtrl.text = p?.id ?? '';

    if (p != null && applyDefaults) {
      // ✅ titulo por defecto = nombre producto, pero editable
      if (!_tituloTouched || tituloCtrl.text.trim().isEmpty) {
        // importante: no queremos que esto marque touched como "escritura del usuario"
        // así que hacemos un mini-flag temporal
        _setTextWithoutTouch(tituloCtrl, p.nombre.trim(), isTitulo: true);
      }

      // ✅ subtitulo por defecto = descuento, pero editable
      if (!_subtituloTouched || subtituloCtrl.text.trim().isEmpty) {
        _setTextWithoutTouch(subtituloCtrl, defaultDiscount, isTitulo: false);
      }
    }

    _tick();
  }

  void _setTextWithoutTouch(TextEditingController ctrl, String text, {required bool isTitulo}) {
    // guardamos estado actual touched
    final prev = isTitulo ? _tituloTouched : _subtituloTouched;

    // set
    ctrl.value = ctrl.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );

    // restaurar touched (para que siga siendo "no tocado" si venía vacío)
    if (isTitulo) {
      _tituloTouched = prev;
    } else {
      _subtituloTouched = prev;
    }
  }

  // imagen banner (custom)
  Uint8List? pickedBytes;
  String? _uploadedBannerUrl; // si subiste imagen propia
  bool uploadingImage = false;

  /// URL final para guardar en Firestore (prioridad: custom subida -> imagen producto)
  String get finalImagenUrl {
    final custom = (_uploadedBannerUrl ?? '').trim();
    if (custom.isNotEmpty) return custom;

    final prod = (selectedProduct?.imagenUrl ?? '').trim();
    if (prod.isNotEmpty) return prod;

    return '';
  }

  /// Fuente para el preview (bytes si hay, si no URL final)
  Uint8List? get previewBytes => pickedBytes;
  String get previewUrl => finalImagenUrl;

  void clearCustomImage() {
    pickedBytes = null;
    _uploadedBannerUrl = null;
    _tick();
  }

  /// Sube bytes al bucket en carpeta banners/
  Future<void> uploadBannerBytes({
    required Uint8List bytes,
    required String fileExt, // "jpg" "png"
  }) async {
    final productId = (selectedProduct?.id ?? 'no_product').trim();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'banners/$productId/$ts.$fileExt';

    uploadingImage = true;
    _tick();

    final ref = FirebaseStorage.instance.ref().child(path);
    final meta = SettableMetadata(contentType: 'image/$fileExt');
    final task = await ref.putData(bytes, meta);
    final url = await task.ref.getDownloadURL();

    pickedBytes = bytes;
    _uploadedBannerUrl = url;

    uploadingImage = false;
    _tick();
  }

  /// ✅ Ahora producto es opcional
  bool validateBasic() {
    if (tituloCtrl.text.trim().length < 2) return false;
    if (subtituloCtrl.text.trim().isEmpty) return false;
    // ❌ ya no validamos producto obligatorio
    return true;
  }

  void dispose() {
    tituloCtrl.dispose();
    subtituloCtrl.dispose();
    idProductoCtrl.dispose();
    previewTick.dispose();
  }
}
