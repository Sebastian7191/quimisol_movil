import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class PagosPage extends StatefulWidget {
  const PagosPage({super.key});

  @override
  State<PagosPage> createState() => _PagosPageState();
}

class _PagosPageState extends State<PagosPage> {
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Uint8List? _selectedQrBytes;
  String? _selectedQrName;

  String? _savedQrUrl;
  String? _savedQrStoragePath;
  String? _savedQrFileName;

  bool _qrActive = true;
  bool _cashActive = true;

  bool _isInitialLoading = true;
  bool _isPicking = false;
  bool _isSavingQr = false;
  bool _isUpdatingQrState = false;
  bool _isUpdatingCashState = false;

  int _mobileTab = 0; // 0 = métodos de pago, 1 = estados

  DocumentReference<Map<String, dynamic>> get _qrConfigRef =>
      _firestore.collection('pagos').doc('config_qr');

  DocumentReference<Map<String, dynamic>> get _cashConfigRef =>
      _firestore.collection('pagos').doc('config_efectivo');

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      setState(() => _isInitialLoading = true);

      final results = await Future.wait([
        _qrConfigRef.get(),
        _cashConfigRef.get(),
      ]);

      final qrDoc = results[0];
      final cashDoc = results[1];

      final qrData = qrDoc.data();
      final cashData = cashDoc.data();

      if (mounted) {
        setState(() {
          _savedQrUrl = qrData != null
              ? _readNullableString(qrData['qrImageUrl'])
              : null;
          _savedQrStoragePath = qrData != null
              ? _readNullableString(qrData['qrStoragePath'])
              : null;
          _savedQrFileName = qrData != null
              ? _readNullableString(qrData['qrFileName'])
              : null;

          _qrActive = (qrData?['activo'] as bool?) ??
              (qrData?['qrActive'] as bool?) ??
              true;

          _cashActive = (cashData?['activo'] as bool?) ??
              (cashData?['cashActive'] as bool?) ??
              true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar la configuración de pagos: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  String? _readNullableString(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _pickQrImage() async {
    try {
      setState(() => _isPicking = true);

      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.lengthInBytes > _maxFileSizeBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'La imagen supera el límite de 5 MB. Elige una más ligera.',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _selectedQrBytes = bytes;
        _selectedQrName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo seleccionar la imagen: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _saveQrImage() async {
    try {
      if (_selectedQrBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Primero selecciona una imagen QR.'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }

      if (_selectedQrBytes!.lengthInBytes > _maxFileSizeBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'La imagen seleccionada supera el límite de 5 MB.',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }

      setState(() => _isSavingQr = true);

      final now = DateTime.now().millisecondsSinceEpoch;
      final safeName = (_selectedQrName ?? 'qr_pago.png').replaceAll(' ', '_');
      final storagePath = 'pagos/qr/qr_$now\_$safeName';

      final ref = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: 'image/png',
        customMetadata: {
          'uploadedBy': _auth.currentUser?.uid ?? 'unknown',
          'module': 'pagos',
          'type': 'qr',
        },
      );

      await ref.putData(_selectedQrBytes!, metadata);
      final downloadUrl = await ref.getDownloadURL();

      final previousStoragePath = _savedQrStoragePath;

      await _qrConfigRef.set({
        'metodo': 'qr',
        'activo': _qrActive,
        'qrImageUrl': downloadUrl,
        'qrStoragePath': storagePath,
        'qrFileName': _selectedQrName ?? safeName,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      }, SetOptions(merge: true));

      if (previousStoragePath != null &&
          previousStoragePath.isNotEmpty &&
          previousStoragePath != storagePath) {
        try {
          await _storage.ref().child(previousStoragePath).delete();
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _savedQrUrl = downloadUrl;
        _savedQrStoragePath = storagePath;
        _savedQrFileName = _selectedQrName ?? safeName;
        _selectedQrBytes = null;
        _selectedQrName = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Imagen QR guardada correctamente en Storage y Firestore.',
          ),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar el QR: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingQr = false);
      }
    }
  }

  void _showNoPaymentMethodAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 42),
        title: const Text(
          'No puedes desactivar este método',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Debes dejar al menos un método de pago activo. Si desactivas ambos, tus clientes no podrán realizar compras.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.button,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateQrActive(bool value) async {
    if (!value && !_cashActive) {
      _showNoPaymentMethodAlert();
      return;
    }
    try {
      setState(() => _isUpdatingQrState = true);

      await _qrConfigRef.set({
        'metodo': 'qr',
        'activo': value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _qrActive = value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar el estado del QR: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingQrState = false);
      }
    }
  }

  Future<void> _updateCashActive(bool value) async {
    if (!value && !_qrActive) {
      _showNoPaymentMethodAlert();
      return;
    }
    try {
      setState(() => _isUpdatingCashState = true);

      await _cashConfigRef.set({
        'metodo': 'efectivo',
        'activo': value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _cashActive = value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar el estado de efectivo: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingCashState = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewBytes = _selectedQrBytes;
    final previewUrl = _selectedQrBytes == null ? _savedQrUrl : null;
    final hasPersistedQr = _savedQrUrl != null && _savedQrUrl!.isNotEmpty;
    final hasAnyQr = previewBytes != null || previewUrl != null;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isMobile = width < 900;
            final isDesktop = width >= 1180;

            if (_isInitialLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 14 : 20,
                isMobile ? 14 : 18,
                isMobile ? 14 : 20,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PagosHeader(isMobile: isMobile),
                  const SizedBox(height: 16),
                  if (isMobile) ...[
                    _MobileTopSwitch(
                      selectedIndex: _mobileTab,
                      onChanged: (index) {
                        setState(() => _mobileTab = index);
                      },
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _mobileTab == 0
                          ? _MetodosPagoPanel(
                              key: const ValueKey('metodos_pago_mobile'),
                              qrImageBytes: previewBytes,
                              qrImageUrl: previewUrl,
                              hasPersistedQr: hasPersistedQr,
                              hasAnyQr: hasAnyQr,
                              isPicking: _isPicking,
                              isSavingQr: _isSavingQr,
                              qrActive: _qrActive,
                              cashActive: _cashActive,
                              isUpdatingQrState: _isUpdatingQrState,
                              isUpdatingCashState: _isUpdatingCashState,
                              onPickQrImage: _pickQrImage,
                              onSaveQrImage: _saveQrImage,
                              onToggleQrActive: _updateQrActive,
                              onToggleCashActive: _updateCashActive,
                            )
                          : const _CobroEstadosPanel(
                              key: ValueKey('cobro_estados_mobile'),
                            ),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: isDesktop ? 5 : 6,
                          child: _MetodosPagoPanel(
                            qrImageBytes: previewBytes,
                            qrImageUrl: previewUrl,
                            hasPersistedQr: hasPersistedQr,
                            hasAnyQr: hasAnyQr,
                            isPicking: _isPicking,
                            isSavingQr: _isSavingQr,
                            qrActive: _qrActive,
                            cashActive: _cashActive,
                            isUpdatingQrState: _isUpdatingQrState,
                            isUpdatingCashState: _isUpdatingCashState,
                            onPickQrImage: _pickQrImage,
                            onSaveQrImage: _saveQrImage,
                            onToggleQrActive: _updateQrActive,
                            onToggleCashActive: _updateCashActive,
                          ),
                        ),
                        const SizedBox(width: 18),
                        const Expanded(
                          flex: 6,
                          child: _CobroEstadosPanel(),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PagosHeader extends StatelessWidget {
  final bool isMobile;

  const _PagosHeader({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Palette.button.withValues(alpha: 0.95),
            Palette.secondary.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isMobile ? 52 : 60,
            height: isMobile ? 52 : 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestión de pagos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 23 : 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Administra los métodos de pago disponibles y la imagen QR que se mostrará a tus clientes.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: isMobile ? 14.5 : 15.5,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileTopSwitch extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _MobileTopSwitch({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Palette.primary.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitchOption(
              selected: selectedIndex == 0,
              icon: Icons.account_balance_wallet_rounded,
              label: 'Métodos de pago',
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SwitchOption(
              selected: selectedIndex == 1,
              icon: Icons.receipt_long_rounded,
              label: 'Estados',
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SwitchOption({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Palette.button.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Palette.primary : Palette.ink,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Palette.primary : Palette.ink,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetodosPagoPanel extends StatelessWidget {
  final Uint8List? qrImageBytes;
  final String? qrImageUrl;
  final bool hasPersistedQr;
  final bool hasAnyQr;
  final bool isPicking;
  final bool isSavingQr;
  final bool qrActive;
  final bool cashActive;
  final bool isUpdatingQrState;
  final bool isUpdatingCashState;
  final VoidCallback onPickQrImage;
  final VoidCallback onSaveQrImage;
  final ValueChanged<bool> onToggleQrActive;
  final ValueChanged<bool> onToggleCashActive;

  const _MetodosPagoPanel({
    super.key,
    required this.qrImageBytes,
    required this.qrImageUrl,
    required this.hasPersistedQr,
    required this.hasAnyQr,
    required this.isPicking,
    required this.isSavingQr,
    required this.qrActive,
    required this.cashActive,
    required this.isUpdatingQrState,
    required this.isUpdatingCashState,
    required this.onPickQrImage,
    required this.onSaveQrImage,
    required this.onToggleQrActive,
    required this.onToggleCashActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Palette.primary.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Métodos de pago',
            subtitle: 'Configura los métodos disponibles para tus clientes.',
          ),
          const SizedBox(height: 18),
          _MetodoSectionCard(
            title: 'Pago por QR',
            subtitle: 'Muestra una imagen QR para pagos digitales.',
            trailing: _InlineStatusSwitch(
              value: qrActive,
              isLoading: isUpdatingQrState,
              onChanged: onToggleQrActive,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QrPreviewBox(
                  qrImageBytes: qrImageBytes,
                  qrImageUrl: qrImageUrl,
                ),
                const SizedBox(height: 16),
                _QrActionBox(
                  hasAnyQr: hasAnyQr,
                  hasPersistedQr: hasPersistedQr,
                  isPicking: isPicking,
                  isSavingQr: isSavingQr,
                  onPickQrImage: onPickQrImage,
                  onSaveQrImage: onSaveQrImage,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _MetodoSectionCard(
            title: 'Pago en efectivo',
            subtitle: 'Permite pagos presenciales o contra entrega.',
            trailing: _InlineStatusSwitch(
              value: cashActive,
              isLoading: isUpdatingCashState,
              onChanged: onToggleCashActive,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Palette.fieldBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Palette.primary.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                'Este método no requiere imagen.',
                style: TextStyle(
                  color: Palette.ink.withValues(alpha: 0.72),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetodoSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget child;

  const _MetodoSectionCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Palette.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Palette.button.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  title.contains('QR')
                      ? Icons.qr_code_scanner_rounded
                      : Icons.payments_rounded,
                  color: Palette.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Palette.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Palette.ink.withValues(alpha: 0.68),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InlineStatusSwitch extends StatelessWidget {
  final bool value;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  const _InlineStatusSwitch({
    required this.value,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value ? 'Activo' : 'Inactivo',
          style: TextStyle(
            color: value ? Colors.green.shade700 : Colors.red.shade700,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        isLoading
            ? const SizedBox(
                width: 28,
                height: 28,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Switch(
                value: value,
                onChanged: onChanged,
              ),
      ],
    );
  }
}

class _QrPreviewBox extends StatelessWidget {
  final Uint8List? qrImageBytes;
  final String? qrImageUrl;

  const _QrPreviewBox({
    required this.qrImageBytes,
    required this.qrImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasBytes = qrImageBytes != null;
    final hasUrl = qrImageUrl != null && qrImageUrl!.isNotEmpty;
    final hasImage = hasBytes || hasUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Palette.primary.withValues(alpha: 0.08),
        ),
      ),
      child: hasImage
          ? Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 280),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 340,
                    maxHeight: 340,
                  ),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: hasBytes
                      ? Image.memory(qrImageBytes!, fit: BoxFit.contain)
                      : Image.network(qrImageUrl!, fit: BoxFit.contain),
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Palette.button.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    size: 56,
                    color: Palette.primary,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'No hay imagen QR cargada',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona una imagen para visualizar el QR de pago. Peso máximo permitido: 5 MB.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Palette.ink.withValues(alpha: 0.68),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
    );
  }
}

class _QrActionBox extends StatelessWidget {
  final bool hasAnyQr;
  final bool hasPersistedQr;
  final bool isPicking;
  final bool isSavingQr;
  final VoidCallback onPickQrImage;
  final VoidCallback onSaveQrImage;

  const _QrActionBox({
    required this.hasAnyQr,
    required this.hasPersistedQr,
    required this.isPicking,
    required this.isSavingQr,
    required this.onPickQrImage,
    required this.onSaveQrImage,
  });

  @override
  Widget build(BuildContext context) {
    final bool alreadyHasQr = hasPersistedQr || hasAnyQr;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Palette.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuración del QR',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Palette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            alreadyHasQr
                ? 'Ya existe una imagen QR configurada o seleccionada. Puedes reemplazarla cuando quieras.'
                : 'Carga una imagen QR clara y nítida. Se guardará en Storage y su referencia en Firestore.',
            style: TextStyle(
              color: Palette.ink.withValues(alpha: 0.68),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isPicking ? null : onPickQrImage,
              icon: isPicking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_rounded),
              label: Text(
                alreadyHasQr ? 'Cambiar imagen QR' : 'Agregar imagen QR',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.button,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSavingQr ? null : onSaveQrImage,
              icon: isSavingQr
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                isSavingQr ? 'Guardando...' : 'Guardar configuración',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _normEstadoPago(dynamic v) {
  final s = (v ?? '').toString().trim().toLowerCase();
  if (s.isEmpty || s.contains('pend')) return 'pendiente';
  if (s.contains('pag')) return 'pagado';
  if (s.contains('rech')) return 'rechazado';
  if (s.contains('verif')) return 'verificando';
  return s;
}

class _CobroEstadosPanel extends StatelessWidget {
  const _CobroEstadosPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Palette.primary.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('pedidos').snapshots(),
        builder: (context, snap) {
          int pendiente = 0;
          int pagoQr = 0;
          int pagoEfectivo = 0;

          if (snap.hasData) {
            for (final doc in snap.data!.docs) {
              final d = doc.data();
              // el admin guarda 'estado_pago', el cliente crea con 'estadoPago'
              final estado = _normEstadoPago(d['estado_pago'] ?? d['estadoPago']);
              // ídem para tipoPago
              final tipo = (d['tipo_pago'] ?? d['tipoPago'] ?? '')
                  .toString().toLowerCase().trim();

              if (estado == 'pendiente') pendiente++;
              if (tipo == 'qr' && estado == 'pagado') pagoQr++;
              if (tipo == 'efectivo' && estado == 'pagado') pagoEfectivo++;
            }
          }

          final loading = snap.connectionState == ConnectionState.waiting;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitle(
                icon: Icons.receipt_long_rounded,
                title: 'Estados de cobro',
                subtitle: 'Seguimiento de pagos por pedido.',
              ),
              const SizedBox(height: 18),
              _StateCard(
                title: 'Pendiente de pago',
                count: loading ? '…' : pendiente.toString(),
                description: 'Pedidos aún no pagados o en espera de confirmación.',
                icon: Icons.schedule_rounded,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _StateCard(
                title: 'Pagado por QR',
                count: loading ? '…' : pagoQr.toString(),
                description: 'Pedidos cuyo pago se realizó mediante escaneo QR.',
                icon: Icons.qr_code_rounded,
                color: Palette.primary,
              ),
              const SizedBox(height: 12),
              _StateCard(
                title: 'Pagado en efectivo',
                count: loading ? '…' : pagoEfectivo.toString(),
                description: 'Pedidos marcados con pago presencial o contra entrega.',
                icon: Icons.payments_rounded,
                color: Colors.green,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final String title;
  final String count;
  final String description;
  final IconData icon;
  final Color color;

  const _StateCard({
    required this.title,
    required this.count,
    required this.description,
    required this.icon,
    this.color = Palette.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Palette.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: Palette.ink.withValues(alpha: 0.68),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: color.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              count,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Palette.button.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: Palette.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Palette.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Palette.ink.withValues(alpha: 0.68),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}