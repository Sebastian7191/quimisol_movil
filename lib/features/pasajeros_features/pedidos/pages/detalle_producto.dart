// lib/features/pedidos/detalle_pedido.dart
//
// ✅ Detalle realtime del pedido (AHORA EN RAÍZ: /pedidos/{pedidoId})
// ✅ Muestra TODOS los productos con: imagen + nombre + cantidad + precio + subtotal
// ✅ Muestra costo_envio:
//    - si 0 => "Gratis"
//    - si >0 => "Bs. X.XX"
// ✅ Total final = subtotal productos + costo_envio (si el campo "total" no viene o viene 0, se calcula igual)
// ✅ fecha_entrega (o fecha_envio si lo usas así):
//    - si es null => muestra "En revisión" (PERO SOLO EN LA FECHA, NO CAMBIA EL ESTADO)
// ✅ Fondo blanco, textos morados, cards rosadas
// ✅ Abajo: Seguimiento con iconos (Pendiente, Aceptado, En curso, Completado)
// ✅ Retrasado y Cancelado: ocultos por ahora (listos para activar cuando corresponda)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class DetallePedidoPage extends StatefulWidget {
  const DetallePedidoPage({
    super.key,
    required this.pedidoId,
    required this.pedidoCode,
  });

  final String pedidoId;
  final String pedidoCode;

  @override
  State<DetallePedidoPage> createState() => _DetallePedidoPageState();
}

class _DetallePedidoPageState extends State<DetallePedidoPage> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  // 🔥 Ya no depende de /usuarios/{uid}/pedidos
  DocumentReference<Map<String, dynamic>> get _pedidoDoc =>
      _fire.collection('pedidos').doc(widget.pedidoId);

  // ---------------- parsing helpers ----------------

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0.0;
  }

  int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  String _asString(dynamic v) => (v ?? '').toString();

  String _formatTimestamp(dynamic v) {
    try {
      if (v is Timestamp) {
        final d = v.toDate();
        final dd = d.day.toString().padLeft(2, '0');
        final mm = d.month.toString().padLeft(2, '0');
        final yyyy = d.year.toString();
        final hh = d.hour.toString().padLeft(2, '0');
        final mi = d.minute.toString().padLeft(2, '0');
        return '$dd/$mm/$yyyy • $hh:$mi';
      }
    } catch (_) {}
    return '—';
  }

  String _itemName(Map<String, dynamic> it) {
    final a = _asString(it['name']).trim();
    if (a.isNotEmpty) return a;
    final b = _asString(it['nombre']).trim();
    if (b.isNotEmpty) return b;
    return 'Producto';
  }

  String _itemImage(Map<String, dynamic> it) => _asString(it['imageUrl']).trim();

  int _itemQty(Map<String, dynamic> it) {
    final q1 = _asInt(it['qty']);
    if (q1 > 0) return q1;
    final q2 = _asInt(it['cantidad']);
    if (q2 > 0) return q2;
    return 1;
  }

  double _itemPrice(Map<String, dynamic> it) {
    final p1 = _asDouble(it['price']);
    if (p1 > 0) return p1;
    final p2 = _asDouble(it['precio']);
    if (p2 > 0) return p2;
    final p3 = _asDouble(it['unitPrice']);
    if (p3 > 0) return p3;
    return 0.0;
  }

  double _itemSubtotal(Map<String, dynamic> it) {
    final s1 = _asDouble(it['subtotal']);
    if (s1 > 0) return s1;
    return _itemQty(it) * _itemPrice(it);
  }

  // ---------------- status mapping ----------------

  String _norm(String s) => s.trim().toLowerCase();

  _TrackStep _stepFromRaw(String raw) {
    final s = _norm(raw);

    if (s == 'pendiente' || s == 'en proceso' || s == 'proceso') {
      return _TrackStep.pendiente;
    }
    if (s == 'aceptado' || s == 'aceptada') {
      return _TrackStep.aceptado;
    }
    if (s == 'en_curso' ||
        s == 'en curso' ||
        s == 'encurso' ||
        s == 'en_camino' ||
        s == 'en camino' ||
        s == 'encamino') {
      return _TrackStep.enCurso;
    }
    if (s == 'completado' ||
        s == 'completada' ||
        s == 'entregado' ||
        s == 'entregada') {
      return _TrackStep.completado;
    }

    // especiales (ocultos por ahora)
    if (s == 'retrasado') return _TrackStep.retrasado;
    if (s == 'cancelado' || s == 'cancelada') return _TrackStep.cancelado;

    return _TrackStep.pendiente;
  }

  _BadgeMeta _badgeFromStep(_TrackStep step) {
    switch (step) {
      case _TrackStep.completado:
        return _BadgeMeta(
          'Completado',
          Icons.check_circle_outline_rounded,
          Palette.statsSuccess,
        );
      case _TrackStep.cancelado:
        return _BadgeMeta(
          'Cancelado',
          Icons.cancel_outlined,
          Palette.statsDanger,
        );
      case _TrackStep.retrasado:
        return _BadgeMeta(
          'Retrasado',
          Icons.warning_amber_rounded,
          Palette.statsWarning,
        );
      case _TrackStep.enCurso:
        return _BadgeMeta(
          'En curso',
          Icons.local_shipping_outlined,
          Palette.statsWarning,
        );
      case _TrackStep.aceptado:
        return _BadgeMeta(
          'Aceptado',
          Icons.verified_outlined,
          Palette.statsSuccess,
        );
      case _TrackStep.pendiente:
        return _BadgeMeta(
          'Pendiente',
          Icons.timelapse_rounded,
          Palette.statsWarning,
        );
    }
  }

  int _stepIndex(_TrackStep s) {
    switch (s) {
      case _TrackStep.pendiente:
        return 0;
      case _TrackStep.aceptado:
        return 1;
      case _TrackStep.enCurso:
        return 2;
      case _TrackStep.completado:
        return 3;
      case _TrackStep.retrasado:
        return 99;
      case _TrackStep.cancelado:
        return 100;
    }
  }

  bool _isLoggedIn() => _auth.currentUser != null;

  @override
  Widget build(BuildContext context) {
    final bg = Palette.fieldBg;
    final purple = Palette.primary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar sencillo
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: purple),
                  ),
                  Expanded(
                    child: Text(
                      'Pedido #${widget.pedidoCode}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: purple,
                        fontWeight: FontWeight.w900,
                        fontSize: 16.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            Expanded(
              // ✅ Ya no depende del /uid para leer el pedido, pero si quieres puedes mostrar aviso si no hay sesión.
              child: !_isLoggedIn()
                  ? Center(
                      child: Text(
                        'Inicia sesión para ver el pedido.',
                        style: TextStyle(
                          color: purple.withOpacity(0.75),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _pedidoDoc.snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                'Error al cargar el pedido.\n${snap.error}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: purple.withOpacity(0.75),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        }

                        final data = snap.data?.data();
                        if (data == null) {
                          return Center(
                            child: Text(
                              'Pedido no encontrado.',
                              style: TextStyle(
                                color: purple.withOpacity(0.75),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        }

                        final estadoRaw = _asString(data['estado']);
                        final step = _stepFromRaw(estadoRaw);
                        final badge = _badgeFromStep(step);

                        // ✅ fecha: si es null => "En revisión" (SIN TOCAR ESTADO)
                        // soporta ambos nombres por si acaso
                        final fechaEntregaRaw = data.containsKey('fecha_entrega')
                            ? data['fecha_entrega']
                            : data['fecha_envio'];

                        final fechaEntregaText = (fechaEntregaRaw == null)
                            ? 'En revisión'
                            : _formatTimestamp(fechaEntregaRaw);

                        // ✅ costo_envio (admite "costo_envio" o "costoEnvio")
                        final costoEnvio = _asDouble(
                          data.containsKey('costo_envio')
                              ? data['costo_envio']
                              : data['costoEnvio'],
                        );

                        // items
                        final itemsRaw = data['items'];
                        final items = <Map<String, dynamic>>[];
                        if (itemsRaw is List) {
                          for (final e in itemsRaw) {
                            if (e is Map) items.add(Map<String, dynamic>.from(e));
                          }
                        }

                        // subtotal productos
                        final productsSubtotal = items.fold<double>(
                          0,
                          (acc, it) => acc + _itemSubtotal(it),
                        );

                        // total productos (si viene total>0 lo respetamos, si no calculamos)
                        final totalDoc = _asDouble(data['total']);
                        final totalProductos = totalDoc > 0 ? totalDoc : productsSubtotal;

                        // total final = productos + envío
                        final totalFinal = totalProductos + (costoEnvio > 0 ? costoEnvio : 0);

                        // especiales listos pero ocultos
                        final showSpecial = false;
                        final isCancelled = step == _TrackStep.cancelado;
                        final isDelayed = step == _TrackStep.retrasado;

                        return Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                                children: [
                                  // Card superior: Estado + Resumen
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Palette.card,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.white.withOpacity(0.65)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 18,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 7,
                                              ),
                                              decoration: BoxDecoration(
                                                color: badge.bg,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    badge.icon,
                                                    size: 16,
                                                    color: Palette.white,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    badge.label,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              'Resumen',
                                              style: TextStyle(
                                                color: purple.withOpacity(0.80),
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // ✅ FECHA (aquí va “En revisión” si es null)
                                        _ResumenRow(
                                          label: 'Entrega',
                                          value: fechaEntregaText,
                                          valueColor: (fechaEntregaRaw == null)
                                              ? Palette.statsWarning
                                              : purple,
                                        ),

                                        const SizedBox(height: 10),
                                        Divider(color: purple.withOpacity(0.12), height: 1),
                                        const SizedBox(height: 10),

                                        _ResumenRow(
                                          label: 'Productos',
                                          value: 'Bs. ${totalProductos.toStringAsFixed(2)}',
                                        ),
                                        const SizedBox(height: 8),
                                        _ResumenRow(
                                          label: 'Envío',
                                          value: costoEnvio <= 0
                                              ? 'Gratis'
                                              : 'Bs. ${costoEnvio.toStringAsFixed(2)}',
                                          valueColor:
                                              costoEnvio <= 0 ? Palette.statsSuccess : purple,
                                        ),
                                        const SizedBox(height: 10),
                                        Divider(color: purple.withOpacity(0.12), height: 1),
                                        const SizedBox(height: 10),
                                        _ResumenRow(
                                          label: 'Total',
                                          value: 'Bs. ${totalFinal.toStringAsFixed(2)}',
                                          strong: true,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // Título productos
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.shopping_bag_rounded,
                                        color: purple.withOpacity(0.90),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Productos',
                                        style: TextStyle(
                                          color: purple,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${items.length})',
                                        style: TextStyle(
                                          color: purple.withOpacity(0.75),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  if (items.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 18),
                                      child: Center(
                                        child: Text(
                                          'Este pedido no tiene items.',
                                          style: TextStyle(
                                            color: purple.withOpacity(0.75),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ...items.map((it) {
                                      final name = _itemName(it);
                                      final img = _itemImage(it);
                                      final qty = _itemQty(it);
                                      final price = _itemPrice(it);
                                      final sub = _itemSubtotal(it);

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _PedidoItemRow(
                                          name: name,
                                          imageUrl: img,
                                          qty: qty,
                                          price: price,
                                          subtotal: sub,
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),

                            // Barra inferior: Seguimiento
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                              decoration: BoxDecoration(
                                color: Palette.white,
                                border: Border(
                                  top: BorderSide(color: purple.withOpacity(0.10)),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 18,
                                    offset: const Offset(0, -10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.route_rounded,
                                        size: 18,
                                        color: purple.withOpacity(0.90),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Seguimiento',
                                        style: TextStyle(
                                          color: purple,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        badge.label,
                                        style: TextStyle(
                                          color: purple.withOpacity(0.85),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (showSpecial && (isCancelled || isDelayed))
                                    _SpecialStateBanner(
                                      type: isCancelled
                                          ? _SpecialType.cancelado
                                          : _SpecialType.retrasado,
                                    )
                                  else
                                    _TrackingRow(
                                      activeIndex: _stepIndex(step).clamp(0, 3),
                                      purple: purple,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- UI: resumen rows ---------------- */

class _ResumenRow extends StatelessWidget {
  const _ResumenRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final purple = Palette.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: purple.withOpacity(0.75),
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? purple,
              fontWeight: FontWeight.w900,
              fontSize: strong ? 14.5 : 13.0,
            ),
          ),
        ),
      ],
    );
  }
}

/* ---------------- UI: item row ---------------- */

class _PedidoItemRow extends StatelessWidget {
  const _PedidoItemRow({
    required this.name,
    required this.imageUrl,
    required this.qty,
    required this.price,
    required this.subtotal,
  });

  final String name;
  final String imageUrl;
  final int qty;
  final double price;
  final double subtotal;

  @override
  Widget build(BuildContext context) {
    final purple = Palette.primary;

    return Container(
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.65)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: Palette.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: purple.withOpacity(0.10)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl.trim().isEmpty
                  ? Icon(Icons.image_outlined, color: purple.withOpacity(0.55))
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image_outlined,
                        color: purple.withOpacity(0.55),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: purple,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.2,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(text: 'Cant: $qty'),
                    _Pill(text: 'Bs. ${price.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Subtotal',
                style: TextStyle(
                  color: purple.withOpacity(0.70),
                  fontWeight: FontWeight.w800,
                  fontSize: 11.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bs. ${subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  color: purple,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final purple = Palette.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.white.withOpacity(0.60),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: purple.withOpacity(0.10)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: purple.withOpacity(0.90),
          fontWeight: FontWeight.w900,
          fontSize: 11.2,
        ),
      ),
    );
  }
}

/* ---------------- Seguimiento (normal) ---------------- */

class _TrackingRow extends StatelessWidget {
  const _TrackingRow({required this.activeIndex, required this.purple});

  final int activeIndex; // 0..3
  final Color purple;

  @override
  Widget build(BuildContext context) {
    final steps = const <_TrackNode>[
      _TrackNode('Pendiente', Icons.receipt_long_rounded),
      _TrackNode('Aceptado', Icons.verified_outlined),
      _TrackNode('En curso', Icons.local_shipping_outlined),
      _TrackNode('Completado', Icons.check_circle_outline_rounded),
    ];

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Expanded(
            child: _TrackDot(
              label: steps[i].label,
              icon: steps[i].icon,
              done: i < activeIndex,
              active: i == activeIndex,
            ),
          ),
          if (i != steps.length - 1)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: (i < activeIndex)
                      ? Palette.statsSuccess.withOpacity(0.85)
                      : purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _TrackDot extends StatelessWidget {
  const _TrackDot({
    required this.label,
    required this.icon,
    required this.done,
    required this.active,
  });

  final String label;
  final IconData icon;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final purple = Palette.primary;

    Color bg;
    Color fg;
    if (done) {
      bg = Palette.statsSuccess;
      fg = Palette.white;
    } else if (active) {
      bg = Palette.button;
      fg = Palette.white;
    } else {
      bg = Palette.white;
      fg = purple.withOpacity(0.70);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: purple.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: fg),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: purple.withOpacity(active || done ? 0.95 : 0.70),
            fontWeight: FontWeight.w800,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _TrackNode {
  final String label;
  final IconData icon;
  const _TrackNode(this.label, this.icon);
}

/* ---------------- Especiales (ocultos por ahora) ---------------- */

enum _SpecialType { retrasado, cancelado }

class _SpecialStateBanner extends StatelessWidget {
  const _SpecialStateBanner({required this.type});
  final _SpecialType type;

  @override
  Widget build(BuildContext context) {
    final purple = Palette.primary;

    final isCancel = type == _SpecialType.cancelado;
    final bg = isCancel ? Palette.statsDanger : Palette.statsWarning;
    final icon = isCancel ? Icons.cancel_outlined : Icons.warning_amber_rounded;
    final text = isCancel ? 'Pedido cancelado' : 'Pedido retrasado';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bg.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: Palette.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: purple, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Models ---------------- */

enum _TrackStep {
  pendiente,
  aceptado,
  enCurso,
  completado,
  retrasado,
  cancelado,
}

class _BadgeMeta {
  final String label;
  final IconData icon;
  final Color bg;

  _BadgeMeta(this.label, this.icon, this.bg);
}
