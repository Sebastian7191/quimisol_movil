import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/dashboard_models.dart';
import '_download_stub.dart'
    if (dart.library.html) '_download_web.dart';

class DashboardExportService {
  // ── Palette ──────────────────────────────────────────────────────────
  static final _cPrimary   = PdfColor.fromHex('#1DA1F2');
  static final _cAqua      = PdfColor.fromHex('#1DF2CB');
  static final _cInk       = PdfColor.fromHex('#16324A');
  static final _cMuted     = PdfColor.fromHex('#64748B');
  static final _cSurface   = PdfColor.fromHex('#F8FAFC');
  static final _cBorder    = PdfColor.fromHex('#E2E8F0');
  static final _cSuccess   = PdfColor.fromHex('#16A34A');
  static final _cWarning   = PdfColor.fromHex('#D97706');
  static final _cDanger    = PdfColor.fromHex('#DC2626');
  static final _cCyan      = PdfColor.fromHex('#0891B2');

  // ── Formatters ───────────────────────────────────────────────────────
  static final _numFmt      = NumberFormat('#,##0.00', 'es');
  static final _dtFmt       = DateFormat('dd/MM/yyyy HH:mm');
  static final _dateFmt     = DateFormat('dd/MM/yyyy');
  static final _filenameFmt = DateFormat('yyyyMMdd_HHmm');

  // ═════════════════════════════════════════════════════════════════════
  //  PDF  (descarga directa, sin diálogo de impresión)
  // ═════════════════════════════════════════════════════════════════════

  static Future<void> exportPDF({
    required DashboardStats stats,
    required String rangeLabel,
  }) async {
    final doc = pw.Document();
    doc.addPage(_page1(stats, rangeLabel));
    doc.addPage(_page2(stats, rangeLabel));

    final bytes = await doc.save();
    downloadFile(
      bytes,
      'dashboard_${_filenameFmt.format(DateTime.now())}.pdf',
      'application/pdf',
    );
  }

  // ─── Página 1: Resumen Ejecutivo ─────────────────────────────────────

  static pw.Page _page1(DashboardStats stats, String rangeLabel) {
    final total        = stats.pedidosTotal;
    final tasaEntrega  = total > 0 ? stats.pedidosEntregados / total * 100 : 0.0;

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header('Resumen Ejecutivo', rangeLabel),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(28, 22, 28, 0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // KPIs
                  pw.Row(children: [
                    pw.Expanded(child: _kpiCard('Total Pedidos',   total.toString(),                          'En el período',          _cPrimary)),
                    pw.SizedBox(width: 10),
                    pw.Expanded(child: _kpiCard('Ventas Totales',  'Bs ${_numFmt.format(stats.ventasTotal)}', 'Ingresos del período',   _cSuccess)),
                    pw.SizedBox(width: 10),
                    pw.Expanded(child: _kpiCard('Entregados',      stats.pedidosEntregados.toString(),        'Pedidos completados',    _cCyan)),
                    pw.SizedBox(width: 10),
                    pw.Expanded(child: _kpiCard('Tasa de Entrega', '${tasaEntrega.toStringAsFixed(1)}%',      'Completados / total',    _cWarning)),
                  ]),
                  pw.SizedBox(height: 24),

                  // Estado
                  _sectionTitle('Estado de Pedidos'),
                  pw.SizedBox(height: 12),
                  _estadoBars(stats),
                  pw.SizedBox(height: 24),

                  // Departamento
                  _sectionTitle('Distribución por Departamento'),
                  pw.SizedBox(height: 12),
                  _deptBars(stats),
                ],
              ),
            ),
          ),
          _footer(1, 2, rangeLabel),
        ],
      ),
    );
  }

  // ─── Página 2: Inventario & Operaciones ──────────────────────────────

  static pw.Page _page2(DashboardStats stats, String rangeLabel) {
    final stockOk      = stats.productosTotal - stats.productosStockBajo;
    final stockBajoNet = stats.productosStockBajo - stats.productosStockCero;
    final ticket       = stats.pedidosEntregados > 0 ? stats.ventasTotal / stats.pedidosEntregados : 0.0;
    final envioProm    = stats.pedidosTotal > 0 ? stats.costoEnvioTotal / stats.pedidosTotal : 0.0;
    final disponibles  = stats.repartidoresTodos.where((r) => r.disponible).length;
    final tasaCanc     = stats.pedidosTotal > 0
        ? (stats.pedidosCancelados / stats.pedidosTotal * 100).toStringAsFixed(1)
        : '0.0';

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header('Inventario & Operaciones', rangeLabel),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(28, 22, 28, 0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Métricas de ventas
                  _sectionTitle('Métricas de Ventas'),
                  pw.SizedBox(height: 12),
                  pw.Row(children: [
                    pw.Expanded(child: _metricCard('Ticket Promedio',      'Bs ${_numFmt.format(ticket)}',    'Ventas / pedidos entregados')),
                    pw.SizedBox(width: 10),
                    pw.Expanded(child: _metricCard('Costo Envío Prom.',    'Bs ${_numFmt.format(envioProm)}',  'Total envíos / pedidos')),
                    pw.SizedBox(width: 10),
                    pw.Expanded(child: _metricCard('Usuarios Registrados', stats.usuariosTotal.toString(),    'En el sistema')),
                    pw.SizedBox(width: 10),
                    pw.Expanded(child: _metricCard('Tasa Cancelación',     '$tasaCanc%',                      '${stats.pedidosCancelados} cancelados')),
                  ]),
                  pw.SizedBox(height: 24),

                  // Inventario
                  _sectionTitle('Estado del Inventario'),
                  pw.SizedBox(height: 8),
                  _inventoryRow(stats.productosTotal),
                  pw.SizedBox(height: 12),
                  _inventoryBars(stats, stockOk, stockBajoNet),
                  pw.SizedBox(height: 24),

                  // Operaciones
                  _sectionTitle('Operaciones'),
                  pw.SizedBox(height: 12),
                  pw.Row(children: [
                    pw.Expanded(child: _metricCard(
                      'Repartidores Disponibles',
                      '$disponibles / ${stats.repartidoresTotal}',
                      'De un total de ${stats.repartidoresTotal}',
                    )),
                    pw.SizedBox(width: 10),
                    pw.Expanded(child: _metricCard(
                      'Banners Activos',
                      '${stats.bannersActivos} / ${stats.bannersTotal}',
                      'Publicados en la app',
                    )),
                    pw.SizedBox(width: 10),
                    pw.Expanded(child: _metricCard(
                      'Pedidos en Camino',
                      stats.pedidosEnCamino.toString(),
                      'En reparto actualmente',
                    )),
                    pw.SizedBox(width: 10),
                    pw.Expanded(child: _metricCard(
                      'Costo Total Envíos',
                      'Bs ${_numFmt.format(stats.costoEnvioTotal)}',
                      'Suma del período',
                    )),
                  ]),
                ],
              ),
            ),
          ),
          _footer(2, 2, rangeLabel),
        ],
      ),
    );
  }

  // ─── Componentes compartidos ──────────────────────────────────────────

  static pw.Widget _header(String subtitle, String rangeLabel) {
    return pw.Column(
      children: [
        pw.Container(
          width: double.infinity,
          color: _cPrimary,
          padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 16),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Dashboard Quimisol',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    subtitle,
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.white),
                  ),
                ],
              ),
              pw.Expanded(child: pw.SizedBox()),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Período: $rangeLabel',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.white),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Generado: ${_dtFmt.format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Franja aqua decorativa
        pw.Container(width: double.infinity, height: 3, color: _cAqua),
      ],
    );
  }

  static pw.Widget _footer(int page, int total, String rangeLabel) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 9),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _cBorder, width: 0.8)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'Quimisol Admin Web  •  Reporte generado automáticamente',
            style: pw.TextStyle(fontSize: 7.5, color: _cMuted),
          ),
          pw.Expanded(child: pw.SizedBox()),
          pw.Text(
            'Período: $rangeLabel',
            style: pw.TextStyle(fontSize: 7.5, color: _cMuted),
          ),
          pw.SizedBox(width: 16),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: _cPrimary,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              'Pág. $page / $total',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Row(
      children: [
        pw.Container(width: 4, height: 16, color: _cPrimary),
        pw.SizedBox(width: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _cInk,
          ),
        ),
      ],
    );
  }

  // KPI card (número grande + accent superior)
  // Nota: pdf package no permite borderRadius con Border no-uniforme,
  // por eso el accent va como Container hijo en lugar de borde superior.
  static pw.Widget _kpiCard(
      String title, String value, String sub, PdfColor accent) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _cSurface,
        border: pw.Border.all(color: _cBorder, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Franja de color superior
          pw.Container(height: 4, color: accent),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _cMuted,
                  ),
                ),
                pw.SizedBox(height: 7),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 19,
                    fontWeight: pw.FontWeight.bold,
                    color: accent,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  sub,
                  style: pw.TextStyle(fontSize: 7.5, color: _cMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Metric card (número mediano, sin accent bar)
  static pw.Widget _metricCard(String title, String value, String note) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: _cSurface,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _cBorder, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _cMuted,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _cInk,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(note, style: pw.TextStyle(fontSize: 7, color: _cMuted)),
        ],
      ),
    );
  }

  // ─── Gráficos ─────────────────────────────────────────────────────────

  static pw.Widget _estadoBars(DashboardStats stats) {
    final total = stats.pedidosTotal;
    final rows = [
      ('Pendiente',  stats.pedidosPendientes,   _cWarning),
      ('Aceptado',   stats.pedidosAceptados,    _cPrimary),
      ('En camino',  stats.pedidosEnCamino,     _cCyan),
      ('Entregado',  stats.pedidosEntregados,   _cSuccess),
      ('Cancelado',  stats.pedidosCancelados,   _cDanger),
    ];
    final maxVal = rows.map((r) => r.$2).fold(0, (a, b) => a > b ? a : b);
    return pw.Column(
      children: rows
          .map((r) => _bar(
                label:    r.$1,
                value:    r.$2,
                total:    total,
                maxValue: maxVal,
                color:    r.$3,
              ))
          .toList(),
    );
  }

  static pw.Widget _deptBars(DashboardStats stats) {
    if (stats.pedidosPorDepartamento.isEmpty) {
      return pw.Text('Sin datos de departamento.',
          style: pw.TextStyle(fontSize: 9, color: _cMuted));
    }
    final entries = (stats.pedidosPorDepartamento.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6)
        .toList();
    final maxVal = entries.first.value;
    return pw.Column(
      children: entries
          .map((e) => _bar(
                label:    e.key,
                value:    e.value,
                total:    stats.pedidosTotal,
                maxValue: maxVal,
                color:    _cPrimary,
              ))
          .toList(),
    );
  }

  static pw.Widget _inventoryRow(int total) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#EFF6FF'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        border: pw.Border.all(color: _cPrimary, width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'Total en catálogo:',
            style: pw.TextStyle(fontSize: 9, color: _cMuted),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            '$total productos',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _cPrimary,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _inventoryBars(
      DashboardStats stats, int stockOk, int stockBajoNet) {
    final total = stats.productosTotal;
    return pw.Column(
      children: [
        _bar(label: 'Stock OK  (> 5)',   value: stockOk,                  total: total, maxValue: total, color: _cSuccess),
        _bar(label: 'Stock bajo (≤ 5)',  value: stockBajoNet,             total: total, maxValue: total, color: _cWarning),
        _bar(label: 'Sin stock  (= 0)',  value: stats.productosStockCero, total: total, maxValue: total, color: _cDanger),
      ],
    );
  }

  // Barra horizontal reutilizable
  static pw.Widget _bar({
    required String label,
    required int value,
    required int total,
    required int maxValue,
    required PdfColor color,
  }) {
    const maxBarW  = 300.0;
    const labelW   = 110.0;
    const valueW   = 80.0;

    final fraction = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    final barW     = maxBarW * fraction;
    final pct      = total > 0 ? (value / total * 100).toStringAsFixed(1) : '0.0';

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: labelW,
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 9.5, color: _cInk)),
          ),
          pw.SizedBox(width: 8),
          pw.Stack(
            children: [
              // fondo
              pw.Container(
                width:  maxBarW,
                height: 15,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F1F5F9'),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
              ),
              // barra
              if (barW > 1)
                pw.Container(
                  width:  barW,
                  height: 15,
                  decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                ),
            ],
          ),
          pw.SizedBox(width: 10),
          pw.SizedBox(
            width: valueW,
            child: pw.Text(
              '$value  ($pct%)',
              style: pw.TextStyle(fontSize: 9, color: _cMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  //  Excel
  // ═════════════════════════════════════════════════════════════════════

  static Future<void> exportExcel({
    required DashboardStats stats,
    required String rangeLabel,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    _buildResumenSheet(excel, stats, rangeLabel);
    _buildPedidosSheet(excel, stats.pedidosTodos);
    _buildProductosSheet(excel, stats.productosTodos);
    _buildUsuariosSheet(excel, stats.usuariosTodos);
    _buildRepartidoresSheet(excel, stats.repartidoresTodos);
    _buildBannersSheet(excel, stats.bannersTodos);

    final bytes = excel.encode();
    if (bytes == null) return;

    downloadFile(
      bytes,
      'dashboard_${_filenameFmt.format(DateTime.now())}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  static void _buildResumenSheet(
      Excel excel, DashboardStats stats, String rangeLabel) {
    final sheet = excel['Resumen'];
    _xlsHeader(sheet, ['Métrica', 'Valor']);
    final rows = <List<dynamic>>[
      ['Período', rangeLabel],
      ['Generado', _dtFmt.format(DateTime.now())],
      ['—', '—'],
      ['Pedidos total', stats.pedidosTotal],
      ['  Pendientes', stats.pedidosPendientes],
      ['  Aceptados', stats.pedidosAceptados],
      ['  En camino', stats.pedidosEnCamino],
      ['  Entregados', stats.pedidosEntregados],
      ['  Cancelados', stats.pedidosCancelados],
      ['Ventas total (Bs)', stats.ventasTotal],
      ['Costo envío total (Bs)', stats.costoEnvioTotal],
      ['—', '—'],
      ['Productos total', stats.productosTotal],
      ['  Stock bajo (≤ 5)', stats.productosStockBajo],
      ['  Sin stock', stats.productosStockCero],
      ['—', '—'],
      ['Usuarios registrados', stats.usuariosTotal],
      ['Repartidores', stats.repartidoresTotal],
      ['—', '—'],
      ['Banners total', stats.bannersTotal],
      ['  Banners activos', stats.bannersActivos],
    ];
    for (final r in rows) {
      sheet.appendRow([
        TextCellValue(r[0].toString()),
        r[1] is num
            ? DoubleCellValue((r[1] as num).toDouble())
            : TextCellValue(r[1].toString()),
      ]);
    }
    sheet.setColumnWidth(0, 34);
    sheet.setColumnWidth(1, 18);
  }

  static void _buildPedidosSheet(Excel excel, List<PedidoMini> pedidos) {
    final sheet = excel['Pedidos'];
    _xlsHeader(sheet, [
      'Código', 'Estado', 'Departamento', 'Dirección',
      'Repartidor', 'Total (Bs)', 'Costo Envío (Bs)', 'Fecha',
    ]);
    for (final p in pedidos) {
      sheet.appendRow([
        TextCellValue(p.codigo.isEmpty ? p.id : p.codigo),
        TextCellValue(p.estado),
        TextCellValue(p.departamento),
        TextCellValue(p.direccion),
        TextCellValue(p.repartidorNombre.isEmpty ? '—' : p.repartidorNombre),
        DoubleCellValue(p.total),
        DoubleCellValue(p.costoEnvio),
        TextCellValue(_dateFmt.format(p.createdAt)),
      ]);
    }
    sheet.setColumnWidth(0, 16);
    sheet.setColumnWidth(1, 14);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 30);
    sheet.setColumnWidth(4, 20);
    sheet.setColumnWidth(5, 14);
    sheet.setColumnWidth(6, 16);
    sheet.setColumnWidth(7, 18);
  }

  static void _buildProductosSheet(Excel excel, List<ProductoMini> productos) {
    final sheet = excel['Productos'];
    _xlsHeader(sheet, ['Nombre', 'Tipo', 'Stock', 'Almacén']);
    for (final p in productos) {
      sheet.appendRow([
        TextCellValue(p.nombre),
        TextCellValue(p.tipo),
        IntCellValue(p.stock),
        TextCellValue(p.almacenNombre.isEmpty ? '—' : p.almacenNombre),
      ]);
    }
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 16);
    sheet.setColumnWidth(2, 10);
    sheet.setColumnWidth(3, 20);
  }

  static void _buildUsuariosSheet(Excel excel, List<UsuarioMini> usuarios) {
    final sheet = excel['Usuarios'];
    _xlsHeader(sheet, ['Nombre', 'Email', 'Rol']);
    for (final u in usuarios) {
      sheet.appendRow([
        TextCellValue(u.nombre),
        TextCellValue(u.email),
        TextCellValue(u.rol),
      ]);
    }
    sheet.setColumnWidth(0, 26);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 16);
  }

  static void _buildRepartidoresSheet(
      Excel excel, List<RepartidorMini> reps) {
    final sheet = excel['Repartidores'];
    _xlsHeader(sheet, ['Nombre', 'Almacén', 'Disponible']);
    for (final r in reps) {
      sheet.appendRow([
        TextCellValue(r.nombre),
        TextCellValue(r.almacenNombre.isEmpty ? '—' : r.almacenNombre),
        TextCellValue(r.disponible ? 'Sí' : 'No'),
      ]);
    }
    sheet.setColumnWidth(0, 26);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 12);
  }

  static void _buildBannersSheet(Excel excel, List<BannerMini> banners) {
    final sheet = excel['Banners'];
    _xlsHeader(sheet, ['Título', 'Estado']);
    for (final b in banners) {
      sheet.appendRow([
        TextCellValue(b.titulo.isEmpty ? '—' : b.titulo),
        TextCellValue(b.estado),
      ]);
    }
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 14);
  }

  static void _xlsHeader(Sheet sheet, List<String> cols) {
    final style = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1DA1F2'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
    sheet.appendRow(cols.map((c) => TextCellValue(c)).toList());
    for (var i = 0; i < cols.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .cellStyle = style;
    }
  }
}
