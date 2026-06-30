import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import '../../data/dashboard_models.dart';

final _bsFmt = NumberFormat('#,##0.00', 'es_BO');
final _dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'es_BO');

void showDashboardDetail(
  BuildContext context, {
  required String title,
  required Color accent,
  required IconData icon,
  required Widget content,
}) {
  showDialog(
    context: context,
    builder: (_) => _DetailDialog(
      title: title,
      accent: accent,
      icon: icon,
      content: content,
    ),
  );
}

class _DetailDialog extends StatelessWidget {
  const _DetailDialog({
    required this.title,
    required this.accent,
    required this.icon,
    required this.content,
  });

  final String title;
  final Color accent;
  final IconData icon;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final dialogWidth = (w * 0.72).clamp(360.0, 780.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.7)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Content
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: content,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CONTENIDOS POR TIPO DE TARJETA
// ─────────────────────────────────────────────

class PedidosDetailContent extends StatelessWidget {
  const PedidosDetailContent({super.key, required this.pedidos, this.showEnvio = false});
  final List<PedidoMini> pedidos;
  final bool showEnvio;

  @override
  Widget build(BuildContext context) {
    if (pedidos.isEmpty) return _emptyState('No hay pedidos en este rango.');

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: pedidos.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final p = pedidos[i];
        final estadoColor = _estadoColor(p.estado);
        final monto = showEnvio ? p.costoEnvio : p.total;
        return ListTile(
          dense: true,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: estadoColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long_rounded, color: estadoColor, size: 18),
          ),
          title: Text(
            p.codigo.isNotEmpty ? '#${p.codigo}' : p.id.substring(0, 8),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          subtitle: Text(
            '${p.direccion.isNotEmpty ? p.direccion : '—'}  •  ${_dateFmt.format(p.createdAt)}',
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EstadoBadge(estado: p.estado),
              const SizedBox(width: 10),
              Text(
                'Bs ${_bsFmt.format(monto)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProductosDetailContent extends StatelessWidget {
  const ProductosDetailContent({super.key, required this.productos, this.soloStockBajo = false});
  final List<ProductoMini> productos;
  final bool soloStockBajo;

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) return _emptyState('No hay productos registrados.');

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: productos.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final p = productos[i];
        final isLow = p.stock <= 5;
        final isCero = p.stock <= 0;
        final Color badgeBg = isCero
            ? Palette.statsDanger
            : isLow
                ? Palette.statsWarning
                : Palette.primary;
        final Color iconColor = isCero
            ? Palette.statsDanger
            : isLow
                ? Palette.statsWarning
                : Palette.secondary;

        return ListTile(
          dense: true,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_rounded, color: iconColor, size: 18),
          ),
          title: Text(
            p.nombre,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${p.tipo.isNotEmpty ? p.tipo : 'Sin tipo'}  •  ${p.almacenNombre.isNotEmpty ? p.almacenNombre : 'Sin almacén'}',
            style: const TextStyle(fontSize: 13),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Stock: ${p.stock}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

class UsuariosDetailContent extends StatelessWidget {
  const UsuariosDetailContent({super.key, required this.usuarios});
  final List<UsuarioMini> usuarios;

  @override
  Widget build(BuildContext context) {
    if (usuarios.isEmpty) return _emptyState('No hay usuarios registrados.');

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: usuarios.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final u = usuarios[i];
        final nombre = u.nombre.isNotEmpty ? u.nombre : u.email.isNotEmpty ? u.email : u.id.substring(0, 8);
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: Palette.primary.withValues(alpha: 0.13),
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.primary),
            ),
          ),
          title: Text(
            nombre,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            u.email.isNotEmpty ? u.email : '—',
            style: const TextStyle(fontSize: 13),
          ),
          trailing: _RolBadge(rol: u.rol),
        );
      },
    );
  }
}

class RepartidoresDetailContent extends StatelessWidget {
  const RepartidoresDetailContent({super.key, required this.repartidores});
  final List<RepartidorMini> repartidores;

  @override
  Widget build(BuildContext context) {
    if (repartidores.isEmpty) return _emptyState('No hay repartidores registrados.');

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: repartidores.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final r = repartidores[i];
        final nombre = r.nombre.isNotEmpty ? r.nombre : r.id.substring(0, 8);
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: Palette.secondary.withValues(alpha: 0.13),
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.secondary),
            ),
          ),
          title: Text(
            nombre,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          subtitle: Text(
            r.almacenNombre.isNotEmpty ? r.almacenNombre : 'Sin almacén asignado',
            style: const TextStyle(fontSize: 13),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: r.disponible
                  ? Palette.statsSuccess.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              r.disponible ? 'Disponible' : 'No disponible',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: r.disponible ? Palette.statsSuccess : Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }
}

class BannersDetailContent extends StatelessWidget {
  const BannersDetailContent({super.key, required this.banners, this.soloActivos = false});
  final List<BannerMini> banners;
  final bool soloActivos;

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return _emptyState('No hay banners registrados.');

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: banners.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final b = banners[i];
        final isActivo = b.estado.toUpperCase() == 'ACTIVO';
        final titulo = b.titulo.isNotEmpty ? b.titulo : b.id.substring(0, 8);

        return ListTile(
          dense: true,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActivo
                  ? Palette.statsSuccess.withValues(alpha: 0.13)
                  : Colors.grey.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.campaign_rounded,
              color: isActivo ? Palette.statsSuccess : Colors.grey,
              size: 18,
            ),
          ),
          title: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: b.imageUrl.isNotEmpty
              ? Text(b.imageUrl, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActivo ? const Color(0xFF27AE60) : const Color(0xFF7F8C8D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              b.estado.isNotEmpty ? b.estado : '—',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  HELPERS INTERNOS
// ─────────────────────────────────────────────

Widget _emptyState(String msg) => Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(msg,
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
      ),
    );

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});
  final String estado;

  @override
  Widget build(BuildContext context) {
    final color = _estadoColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        estado.isNotEmpty ? estado : '—',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _RolBadge extends StatelessWidget {
  const _RolBadge({required this.rol});
  final String rol;

  @override
  Widget build(BuildContext context) {
    final color = _rolColor(rol);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        rol.isNotEmpty ? rol : '—',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

Color _estadoColor(String estado) {
  final e = normalizeEstado(estado);
  if (e == kEstadoPendiente) return Palette.statsWarning;
  if (e == kEstadoAceptado) return Palette.primary;
  if (e == kEstadoEnCamino) return Palette.secondary;
  if (e == kEstadoEntregado) return Palette.statsSuccess;
  if (e == kEstadoCancelado) return Palette.statsDanger;
  return Colors.grey;
}

Color _rolColor(String rol) {
  final r = rol.toLowerCase();
  if (r == 'superadmin') return const Color(0xFF6C3483);
  if (r == 'admin') return Palette.primary;
  if (r == 'repartidor' || r == 'conductor') return const Color(0xFF00897B);
  if (r == 'cliente_mayorista') return const Color(0xFFE67E22);
  if (r == 'cliente') return const Color(0xFF5D6D7E);
  return const Color(0xFF7F8C8D);
}
