import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import '../controllers/detalle_controller.dart';
import '../data/detalle_data.dart';
import '../data/pedido_item.dart';

import 'widgets/detalle_widgets/edit_row.dart';
import 'widgets/detalle_widgets/empty_box.dart';
import 'widgets/detalle_widgets/footer_detalle.dart';
import 'widgets/detalle_widgets/header_detalle.dart';
import 'widgets/detalle_widgets/repartidor_picker.dart';
import 'widgets/detalle_widgets/section_card.dart';
import 'widgets/detalle_widgets/entrega_info.dart';

Future<void> showPedidoDetalleDialog(
  BuildContext context,
  String pedidoId, {
  PedidoDetalleController? controller,
}) {
  final ctrl = controller ?? PedidoDetalleController();
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _PedidoDetalleDialog(pedidoId: pedidoId, controller: ctrl),
  );
}

class _PedidoDetalleDialog extends StatelessWidget {
  const _PedidoDetalleDialog({
    required this.pedidoId,
    required this.controller,
  });

  final String pedidoId;
  final PedidoDetalleController controller;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Material(
              color: Palette.white,
              child: FutureBuilder<PedidoDetalleData>(
                future: controller.fetchPedido(pedidoId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return SizedBox(
                      height: 240,
                      child: Center(
                        child: Text('Error cargando pedido: ${snap.error}'),
                      ),
                    );
                  }

                  final pedido = snap.data!;
                  return _PedidoDetalleForm(
                    pedido: pedido,
                    controller: controller,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PedidoDetalleForm extends StatefulWidget {
  const _PedidoDetalleForm({required this.pedido, required this.controller});

  final PedidoDetalleData pedido;
  final PedidoDetalleController controller;

  @override
  State<_PedidoDetalleForm> createState() => _PedidoDetalleFormState();
}

class _PedidoDetalleFormState extends State<_PedidoDetalleForm> {
  bool _saving = false;

  late String _estadoEdit;
  late String _estadoPagoEdit;
  DateTime? _fechaEnvioEdit;
  double? _costoEnvioEdit;
  String? _repartidorUidEdit;
  String? _repartidorNombreEdit;

  late TextEditingController _costoCtrl;
  late TextEditingController _motivoRechazoCtrl;

  bool get _esEfectivo =>
      widget.pedido.tipoPago.trim().toLowerCase().contains('efect');

  @override
  void initState() {
    super.initState();
    _estadoEdit = normalizeEstado(widget.pedido.estado);
    _estadoPagoEdit = _normalizeEstadoPago(widget.pedido.estadoPago);
    _fechaEnvioEdit = widget.pedido.fechaEnvio;
    _costoEnvioEdit = widget.pedido.costoEnvio;
    _repartidorUidEdit = widget.pedido.repartidorUid;
    _repartidorNombreEdit = widget.pedido.repartidorNombre;

    _costoCtrl = TextEditingController(
      text: _moneyNoSuffix(_costoEnvioEdit ?? 0),
    );
    _motivoRechazoCtrl = TextEditingController(
      text: widget.pedido.motivoRechazoPago,
    );

    if (!_esEfectivo && _estadoPagoEdit == 'rechazado') {
      _estadoEdit = kEstadoPendiente;
    }
  }

  @override
  void dispose() {
    _costoCtrl.dispose();
    _motivoRechazoCtrl.dispose();
    super.dispose();
  }

  String _normalizeEstadoPago(String? v) {
    final s = (v ?? '').trim().toLowerCase();
    if (s.contains('pag')) return 'pagado';
    if (s.contains('rech')) return 'rechazado';
    return 'pendiente';
  }

  void _applyCostoFromText() {
    final raw = _costoCtrl.text.trim();
    final v = _parseMoney(raw);
    setState(() => _costoEnvioEdit = v < 0 ? 0 : v);
  }

  Future<void> _pickFechaEnvio() async {
    final now = DateTime.now();
    final initial = _fechaEnvioEdit ?? now;

    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;

    setState(() {
      _fechaEnvioEdit = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? initial.hour,
        time?.minute ?? initial.minute,
      );
    });
  }

  Future<void> _saveChanges() async {
    _applyCostoFromText();

    if (!_esEfectivo &&
        _estadoPagoEdit == 'rechazado' &&
        _motivoRechazoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes escribir el motivo del rechazo del pago.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.controller.guardarCambios(
        pedidoId: widget.pedido.id,
        nuevoEstado: _estadoEdit,
        nuevoEstadoPago: _esEfectivo ? 'pendiente' : _estadoPagoEdit,
        motivoRechazoPago: (!_esEfectivo && _estadoPagoEdit == 'rechazado')
            ? _motivoRechazoCtrl.text.trim()
            : null,
        fechaEnvio: _fechaEnvioEdit,
        costoEnvio: _costoEnvioEdit ?? 0,
        repartidorUid: _repartidorUidEdit,
        repartidorNombre: _repartidorNombreEdit,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pedido actualizado ✅')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final costoEnvio = _costoEnvioEdit ?? pedido.costoEnvio;
    final totalFinal = pedido.totalProductos + costoEnvio;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Header(
          codigo: pedido.codigo,
          estado: normalizeEstado(
            (!_esEfectivo && _estadoPagoEdit == 'rechazado')
                ? kEstadoPendiente
                : pedido.estado,
          ),
          createdAt: pedido.createdAt,
          onClose: _saving ? null : () => Navigator.pop(context),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final isWide = c.maxWidth >= 780;
                    final left = SectionCard(
                      title: 'Entrega',
                      icon: Icons.location_on_rounded,
                      child: EntregaInfo(
                        ubNombre: pedido.ubicacionNombre,
                        direccion: pedido.direccion,
                        departamento: pedido.departamento,
                      ),
                    );
                    final right = SectionCard(
                      title: 'Cliente',
                      icon: Icons.person_rounded,
                      child: _ClienteInfoWidget(
                        uidCliente: pedido.uidCliente,
                        codigoPedido: pedido.codigo,
                        conteoItems: pedido.items.length,
                        controller: widget.controller,
                      ),
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: left),
                          const SizedBox(width: 14),
                          Expanded(flex: 4, child: right),
                        ],
                      );
                    }
                    return Column(
                      children: [left, const SizedBox(height: 14), right],
                    );
                  },
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Gestión',
                  icon: Icons.tune_rounded,
                  child: _GestionSection(
                    pedido: pedido,
                    estadoEdit: _estadoEdit,
                    onEstadoChanged:
                        (_saving ||
                            (!_esEfectivo && _estadoPagoEdit == 'rechazado'))
                        ? null
                        : (v) => setState(() => _estadoEdit = v),
                    fechaEnvioEdit: _fechaEnvioEdit,
                    onPickFecha: _saving ? null : _pickFechaEnvio,
                    costoCtrl: _costoCtrl,
                    costoEnvioEdit: _costoEnvioEdit,
                    onCostoChanged: _saving ? null : (_) => _applyCostoFromText(),
                    repartidorUidEdit: _repartidorUidEdit,
                    repartidorNombreEdit: _repartidorNombreEdit,
                    onRepartidorChanged: _saving
                        ? null
                        : (uid, nombre) {
                            setState(() {
                              _repartidorUidEdit = uid;
                              _repartidorNombreEdit = nombre;
                            });
                          },
                    controller: widget.controller,
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Pago',
                  icon: Icons.payments_rounded,
                  child: _PagoInfoWidget(
                    pedido: pedido,
                    estadoPagoEdit: _estadoPagoEdit,
                    motivoRechazoCtrl: _motivoRechazoCtrl,
                    onEstadoPagoChanged: _saving || _esEfectivo
                        ? null
                        : (v) {
                            setState(() {
                              _estadoPagoEdit = v;
                              if (v == 'rechazado') {
                                _estadoEdit = kEstadoPendiente;
                              } else if (_motivoRechazoCtrl.text
                                  .trim()
                                  .isNotEmpty) {
                                _motivoRechazoCtrl.clear();
                              }
                            });
                          },
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Productos',
                  icon: Icons.shopping_bag_rounded,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.button.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Palette.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      '${pedido.items.length}',
                      style: const TextStyle(
                        color: Palette.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  child: pedido.items.isEmpty
                      ? const EmptyBox(text: 'No hay items en este pedido.')
                      : Column(
                          children: [
                            for (int i = 0; i < pedido.items.length; i++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: i == pedido.items.length - 1 ? 0 : 10,
                                ),
                                child: _ItemTile(item: pedido.items[i]),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Totales',
                  icon: Icons.calculate_rounded,
                  child: _TotalesWidget(
                    totalProductos: pedido.totalProductos,
                    costoEnvio: costoEnvio,
                    totalFinal: totalFinal,
                  ),
                ),
              ],
            ),
          ),
        ),
        Footer(
          isSaving: _saving,
          readOnly: _estadoEdit == kEstadoEntregado,
          onClose: _saving ? null : () => Navigator.pop(context),
          onSave: _saving ? null : _saveChanges,
        ),
      ],
    );
  }
}

class _ClienteInfoWidget extends StatelessWidget {
  const _ClienteInfoWidget({
    required this.uidCliente,
    required this.codigoPedido,
    required this.conteoItems,
    required this.controller,
  });

  final PedidoDetalleController controller;
  final String uidCliente;
  final String codigoPedido;
  final int conteoItems;

  @override
  Widget build(BuildContext context) {
    if (uidCliente.isEmpty) {
      return const EmptyBox(text: 'No hay cliente asociado.');
    }

    return FutureBuilder<Map<String, String>>(
      future: controller.fetchClienteInfo(uidCliente),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _loadingField('Cargando cliente…');
        }

        final data = snap.data ?? {'nombre': '—', 'email': '—'};
        return _KeyValueList(
          rows: [
            _KV('Nombre', data['nombre'] ?? '—'),
            _KV('Email', data['email'] ?? '—'),
            _KV('Código', '#$codigoPedido', isStrong: true),
            _KV('Items', conteoItems.toString()),
          ],
        );
      },
    );
  }

  Widget _loadingField(String text) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Palette.ink.withValues(alpha: 0.7),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GestionSection extends StatelessWidget {
  const _GestionSection({
    required this.pedido,
    required this.estadoEdit,
    required this.onEstadoChanged,
    required this.fechaEnvioEdit,
    required this.onPickFecha,
    required this.costoCtrl,
    required this.costoEnvioEdit,
    required this.onCostoChanged,
    required this.repartidorUidEdit,
    required this.repartidorNombreEdit,
    required this.onRepartidorChanged,
    required this.controller,
  });

  final PedidoDetalleData pedido;
  final String estadoEdit;
  final ValueChanged<String>? onEstadoChanged;
  final DateTime? fechaEnvioEdit;
  final VoidCallback? onPickFecha;
  final TextEditingController costoCtrl;
  final double? costoEnvioEdit;
  final ValueChanged<String>? onCostoChanged;
  final String? repartidorUidEdit;
  final String? repartidorNombreEdit;
  final Function(String? uid, String? nombre)? onRepartidorChanged;
  final PedidoDetalleController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isMobile = c.maxWidth < 640;

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GestionFieldBlock(
                label: 'Estado',
                child: _EstadoDropdown(
                  value: estadoEdit,
                  onChanged: onEstadoChanged,
                ),
              ),
              const SizedBox(height: 14),
              _GestionFieldBlock(
                label: 'Fecha envío',
                child: _FechaEnvioField(
                  value: fechaEnvioEdit,
                  onTap: onPickFecha,
                  compact: true,
                ),
              ),
              const SizedBox(height: 14),
              _GestionFieldBlock(
                label: 'Costo envío',
                child: _CostoEnvioField(
                  controller: costoCtrl,
                  onChanged: onCostoChanged,
                ),
              ),
              const SizedBox(height: 14),
              _GestionFieldBlock(
                label: 'Repartidor',
                child: RepartidorPickerWidget(
                  departamento: pedido.departamento,
                  almacenId: pedido.almacenId,
                  valueUid: repartidorUidEdit,
                  valueNombre: repartidorNombreEdit,
                  onChanged: onRepartidorChanged,
                  controller: controller,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            EditRow(
              label: 'Estado',
              child: _EstadoDropdown(
                value: estadoEdit,
                onChanged: onEstadoChanged,
              ),
            ),
            const SizedBox(height: 10),
            EditRow(
              label: 'Fecha envío',
              child: _FechaEnvioField(
                value: fechaEnvioEdit,
                onTap: onPickFecha,
              ),
            ),
            const SizedBox(height: 10),
            EditRow(
              label: 'Costo envío',
              child: _CostoEnvioField(
                controller: costoCtrl,
                onChanged: onCostoChanged,
              ),
            ),
            const SizedBox(height: 10),
            EditRow(
              label: 'Repartidor',
              child: RepartidorPickerWidget(
                departamento: pedido.departamento,
                almacenId: pedido.almacenId,
                valueUid: repartidorUidEdit,
                valueNombre: repartidorNombreEdit,
                onChanged: onRepartidorChanged,
                controller: controller,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GestionFieldBlock extends StatelessWidget {
  const _GestionFieldBlock({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Palette.ink.withValues(alpha: 0.72),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _PagoInfoWidget extends StatelessWidget {
  const _PagoInfoWidget({
    required this.pedido,
    required this.estadoPagoEdit,
    required this.motivoRechazoCtrl,
    required this.onEstadoPagoChanged,
  });

  final PedidoDetalleData pedido;
  final String estadoPagoEdit;
  final TextEditingController motivoRechazoCtrl;
  final ValueChanged<String>? onEstadoPagoChanged;

  String _tipoPagoLabel(String v) {
    final s = v.trim().toLowerCase();
    if (s.isEmpty) return '—';
    if (s.contains('qr')) return 'QR';
    if (s.contains('efect')) return 'Efectivo';
    return v;
  }

  String _estadoPagoLabel(String v) {
    final s = v.trim().toLowerCase();
    if (s.isEmpty) return 'Pendiente';
    if (s.contains('rech')) return 'Rechazado';
    if (s.contains('pag')) return 'Pagado';
    if (s.contains('pend')) return 'Pendiente';
    return v;
  }

  bool get _esEfectivo => pedido.tipoPago.trim().toLowerCase().contains('efect');

  @override
  Widget build(BuildContext context) {
    if (_esEfectivo) {
      return Column(
        children: [
          _KeyValueList(
            rows: [
              _KV('Tipo de pago', 'Efectivo', isStrong: true),
              _KV('Estado pago', _estadoPagoLabel(pedido.estadoPago)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Palette.fieldBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
            ),
            child: const Text(
              'Este pedido será pagado en efectivo al momento de la entrega. No requiere comprobante ni validación de imagen.',
              style: TextStyle(
                color: Palette.ink,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _KeyValueList(
          rows: [
            _KV('Tipo de pago', _tipoPagoLabel(pedido.tipoPago), isStrong: true),
          ],
        ),
        const SizedBox(height: 10),
        EditRow(
          label: 'Estado pago',
          child: _EstadoPagoDropdown(
            value: estadoPagoEdit,
            onChanged: onEstadoPagoChanged,
          ),
        ),
        if (estadoPagoEdit == 'rechazado') ...[
          const SizedBox(height: 12),
          EditRow(
            label: 'Motivo rechazo',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Palette.fieldBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
              ),
              child: TextField(
                controller: motivoRechazoCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Describe por qué se está rechazando el pago...',
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(
                  color: Palette.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _ComprobanteWidget(
          comprobanteUrl: pedido.comprobanteUrl,
          comprobanteNombre: pedido.comprobanteNombre,
        ),
      ],
    );
  }
}

class _ComprobanteWidget extends StatelessWidget {
  const _ComprobanteWidget({
    required this.comprobanteUrl,
    required this.comprobanteNombre,
  });

  final String comprobanteUrl;
  final String comprobanteNombre;

  @override
  Widget build(BuildContext context) {
    if (comprobanteUrl.trim().isEmpty) {
      return const EmptyBox(text: 'No hay comprobante registrado.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comprobanteNombre.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              comprobanteNombre,
              style: const TextStyle(
                color: Palette.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              barrierColor: Colors.black.withOpacity(0.9),
              builder: (_) => _ComprobanteZoomDialog(
                imageUrl: comprobanteUrl,
                title: comprobanteNombre,
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Palette.fieldBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1.15,
                child: Image.network(
                  comprobanteUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) {
                    return const Center(
                      child: Text('No se pudo cargar el comprobante.'),
                    );
                  },
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Toca la imagen para verla completa.',
          style: TextStyle(
            color: Palette.ink.withValues(alpha: 0.62),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ComprobanteZoomDialog extends StatelessWidget {
  const _ComprobanteZoomDialog({
    required this.imageUrl,
    required this.title,
  });

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.92),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.trim().isEmpty ? 'Comprobante' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17.5,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    panEnabled: true,
                    child: Center(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          return const Text(
                            'No se pudo cargar la imagen.',
                            style: TextStyle(color: Colors.white),
                          );
                        },
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const CircularProgressIndicator(
                            color: Colors.white,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Usa dos dedos para hacer zoom y arrastra para mover la imagen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoPagoDropdown extends StatelessWidget {
  const _EstadoPagoDropdown({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    const options = ['pendiente', 'rechazado', 'pagado'];
    final current = options.contains(value) ? value : 'pendiente';

    String labelFor(String e) {
      switch (e) {
        case 'pendiente':
          return 'Pendiente';
        case 'rechazado':
          return 'Rechazado';
        case 'pagado':
          return 'Pagado';
        default:
          return e;
      }
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isExpanded: true,
          items: options
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(labelFor(e)),
                ),
              )
              .toList(),
          onChanged: onChanged == null
              ? null
              : (v) => onChanged!(v ?? 'pendiente'),
        ),
      ),
    );
  }
}

class _EstadoDropdown extends StatelessWidget {
  const _EstadoDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      kEstadoPendiente,
      kEstadoAceptado,
      kEstadoEnCamino,
      kEstadoEntregado,
      kEstadoCancelado,
    ];

    String labelFor(String e) {
      switch (e) {
        case kEstadoPendiente:
          return 'Pendiente';
        case kEstadoAceptado:
          return 'Aceptado';
        case kEstadoEnCamino:
          return 'En camino';
        case kEstadoEntregado:
          return 'Entregado';
        case kEstadoCancelado:
          return 'Cancelado';
        default:
          return e;
      }
    }

    final current = options.contains(value) ? value : options.first;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isExpanded: true,
          items: options
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(labelFor(e)),
                ),
              )
              .toList(),
          onChanged: onChanged == null
              ? null
              : (v) => onChanged!(v ?? options.first),
        ),
      ),
    );
  }
}

class _FechaEnvioField extends StatelessWidget {
  const _FechaEnvioField({
    required this.value,
    required this.onTap,
    this.compact = false,
  });

  final DateTime? value;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final field = Container(
      alignment: Alignment.centerLeft,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
      ),
      child: Text(
        value == null
            ? '—'
            : DateFormat('dd/MM/yyyy HH:mm', 'es_BO').format(value!),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Palette.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    final button = OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_month_rounded),
      label: const Text('Editar'),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(compact ? double.infinity : 0, 44),
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          const SizedBox(height: 10),
          button,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: 10),
        button,
      ],
    );
  }
}

class _CostoEnvioField extends StatelessWidget {
  const _CostoEnvioField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_shipping_rounded,
            size: 18,
            color: Palette.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(
                color: Palette.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Palette.button.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Palette.primary.withValues(alpha: 0.10),
              ),
            ),
            child: Text(
              'Bs',
              style: TextStyle(
                color: Palette.ink.withValues(alpha: 0.85),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});
  final PedidoItemData item;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isMobile = c.maxWidth < 560;

        if (isMobile) {
          return Container(
            decoration: BoxDecoration(
              color: Palette.fieldBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Thumb(url: item.imageUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nombre,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Palette.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 14.9,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(text: 'Cant: ${item.cantidad}'),
                    _Pill(
                      text: 'Precio: ${_money(item.precio)}',
                      icon: Icons.price_check,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.button.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Palette.primary.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(
                      'Subtotal: ${_money(item.subtotal)}',
                      style: const TextStyle(
                        color: Palette.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Palette.fieldBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _Thumb(url: item.imageUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Palette.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.7,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Pill(text: 'Cant: ${item.cantidad}'),
                        _Pill(
                          text: 'Precio: ${_money(item.precio)}',
                          icon: Icons.price_check,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Palette.button.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Palette.primary.withValues(alpha: 0.10),
                  ),
                ),
                child: Text(
                  _money(item.subtotal),
                  style: const TextStyle(
                    color: Palette.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.ink.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: url.isEmpty
            ? Icon(
                Icons.image_not_supported_rounded,
                color: Palette.primary.withValues(alpha: 0.6),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Icon(
                    Icons.broken_image_rounded,
                    color: Palette.primary.withValues(alpha: 0.6),
                  );
                },
              ),
      ),
    );
  }
}

class _TotalesWidget extends StatelessWidget {
  const _TotalesWidget({
    required this.totalProductos,
    required this.costoEnvio,
    required this.totalFinal,
  });

  final double totalProductos;
  final double costoEnvio;
  final double totalFinal;

  @override
  Widget build(BuildContext context) {
    return _KeyValueList(
      rows: [
        _KV('Total productos', _money(totalProductos)),
        _KV('Costo envío', _money(costoEnvio)),
        _KV('Total final', _money(totalFinal), isStrong: true),
      ],
    );
  }
}

class _KeyValueList extends StatelessWidget {
  const _KeyValueList({required this.rows});
  final List<_KV> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Palette.fieldBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    rows[i].k,
                    style: TextStyle(
                      color: Palette.ink.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Text(
                    rows[i].v,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Palette.ink,
                      fontWeight: rows[i].isStrong
                          ? FontWeight.w900
                          : FontWeight.w800,
                      fontSize: rows[i].isStrong ? 15 : 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (i != rows.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Palette.primary),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: Palette.ink.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

String _money(double v) {
  final f = NumberFormat('#,##0.00', 'es_BO');
  return '${f.format(v)} Bs';
}

String _moneyNoSuffix(double v) {
  final f = NumberFormat('#,##0.00', 'es_BO');
  return f.format(v);
}

double _parseMoney(String raw) {
  final s = raw.replaceAll('Bs', '').replaceAll(' ', '').trim();
  if (s.isEmpty) return 0;
  if (s.contains(',') && s.contains('.')) {
    final normalized = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }
  if (s.contains(',') && !s.contains('.')) {
    return double.tryParse(s.replaceAll(',', '.')) ?? 0;
  }
  return double.tryParse(s) ?? 0;
}

class _KV {
  final String k;
  final String v;
  final bool isStrong;
  const _KV(this.k, this.v, {this.isStrong = false});
}