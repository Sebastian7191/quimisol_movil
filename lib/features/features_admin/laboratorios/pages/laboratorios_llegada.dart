import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class LaboratoriosPage extends StatelessWidget {
  const LaboratoriosPage({super.key});

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Quimisol SRL',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'I.- INFORMACIÓN GENERAL DEL CLIENTE',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'RECEPCIÓN DE MUESTRAS',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('FTSGI-01-02'),
                      pw.Text('Versión 03'),
                      pw.Text('Vigente 18-09-2024'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              _pdfLinea('Empresa / Cliente', 'TENTALAB S.R.L.'),
              _pdfLinea('Solicitante', 'TENTALAB S.R.L.'),
              _pdfLinea('Proyecto / Instalación', ''),
              _pdfLinea('Dirección', ''),
              pw.SizedBox(height: 12),

              pw.Text(
                'II.- DATOS GENERALES',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),

              pw.Row(
                children: [
                  pw.Expanded(
                    child: _pdfMiniLinea('Fecha de muestreo', ' / / '),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _pdfMiniLinea(
                      'Fecha de recepción de muestra',
                      '27/01/2026',
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _pdfMiniLinea(
                      'Hora de recepción de muestra',
                      '14:30',
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(child: _pdfMiniLinea('Número de cotización', '')),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    flex: 2,
                    child: _pdfMiniLinea(
                      'Temperatura del recipiente de la muestra (°C)',
                      'No aplica',
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 12),
              pw.Text(
                'III.- DESCRIPCIÓN DE LAS MUESTRAS',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(width: 0.8),
                columnWidths: {
                  0: const pw.FixedColumnWidth(28),
                  1: const pw.FixedColumnWidth(95),
                  2: const pw.FixedColumnWidth(42),
                  3: const pw.FixedColumnWidth(42),
                  4: const pw.FixedColumnWidth(58),
                  5: const pw.FixedColumnWidth(40),
                  6: const pw.FlexColumnWidth(),
                  7: const pw.FixedColumnWidth(70),
                },
                children: [
                  _pdfTableHeader(),
                  _pdfTableRow([
                    '1',
                    'E1-01\n26666/10',
                    'L',
                    '1',
                    '100 ml',
                    'P',
                    '',
                    '70',
                  ]),
                  _pdfTableRow([
                    '2',
                    'E1-10\n26401/10',
                    'L',
                    '1',
                    '100 ml',
                    'P',
                    '',
                    '71',
                  ]),
                  for (int i = 0; i < 8; i++)
                    _pdfTableRow(['', '', '', '', '', '', '', '']),
                ],
              ),

              pw.SizedBox(height: 14),
              pw.Text(
                'IV.- INFORMACIÓN DE LAS MUESTRAS',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(width: 0.8),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FixedColumnWidth(70),
                  2: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  _pdfChecklistHeader(),
                  _pdfChecklistRow(
                    '¿Se tiene definido los parámetros a ensayar? (adjuntar solicitud o cotización)',
                    'SI',
                    '',
                  ),
                  _pdfChecklistRow(
                    '¿Se han utilizado conservadoras diferentes para evitar la contaminación cruzada?',
                    'SI',
                    '',
                  ),
                  _pdfChecklistRow(
                    '¿La conservadora se encuentra cerrada?',
                    'SI',
                    '',
                  ),
                  _pdfChecklistRow(
                    '¿Los envases están herméticamente cerrados (sin derrame)?',
                    'SI',
                    '',
                  ),
                  _pdfChecklistRow(
                    '¿La cantidad de muestra es suficiente para los ensayos solicitados?',
                    'SI',
                    '',
                  ),
                  _pdfChecklistRow(
                    '¿Se han utilizado conservantes en los envases?',
                    '-',
                    '',
                  ),
                  _pdfChecklistRow(
                    '¿Los envases cuentan con la identificación respectiva?',
                    'SI',
                    '',
                  ),
                  _pdfChecklistRow(
                    '¿Los datos de las etiquetas coinciden con los descritos en los registros?',
                    'SI',
                    '',
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'TOTAL DE MUESTRAS ENTREGADAS: 2',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Text(
                'V.- RECEPCIÓN',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _pdfFirmaBox(
                      titulo: 'ENTREGADO POR:',
                      firma: 'Firma manual',
                      nombre: 'Laura Cubela',
                      fecha: '27-01-2026',
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: _pdfFirmaBox(
                      titulo: 'RECIBIDO POR:',
                      firma: 'Firma manual',
                      nombre: 'Rocío Cutipa R.',
                      fecha: '2026-01-27',
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: _pdfFirmaBox(
                      titulo: 'OBSERVACIONES ADICIONALES:',
                      firma: '',
                      nombre: '',
                      fecha: '',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _imprimirPdf() async {
    await Printing.layoutPdf(
      onLayout: (format) => _buildPdf(format),
      name: 'recepcion_muestras_quimisol.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isMobile = c.maxWidth < 900;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    runSpacing: 10,
                    spacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Laboratorios',
                            style: TextStyle(
                              fontSize: isMobile ? 22 : 28,
                              fontWeight: FontWeight.w900,
                              color: Palette.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vista PDF del formato de recepción de muestras',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('Llenar formulario'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Palette.primary,
                              side: BorderSide(
                                color: Palette.primary.withValues(alpha: 0.3),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _imprimirPdf,
                            icon: const Icon(Icons.print_rounded),
                            label: const Text('Imprimir / Descargar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Palette.button,
                              foregroundColor: Palette.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Palette.primary.withValues(alpha: 0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: PdfPreview(
                          build: _buildPdf,
                          canChangePageFormat: false,
                          canChangeOrientation: false,
                          allowPrinting: true,
                          allowSharing: true,
                          useActions: true,
                          maxPageWidth: isMobile ? 700 : 900,
                          pdfFileName: 'recepcion_muestras_quimisol.pdf',
                          loadingWidget: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

pw.Widget _pdfLinea(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 2),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 0.6),
              ),
            ),
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pdfMiniLinea(String label, String value) {
  return pw.Row(
    children: [
      pw.Expanded(
        child: pw.Text(
          '$label:',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
      ),
      pw.SizedBox(width: 6),
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 2),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(width: 0.6),
            ),
          ),
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ),
    ],
  );
}

pw.TableRow _pdfTableHeader() {
  pw.Widget h(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 8,
          ),
          textAlign: pw.TextAlign.center,
        ),
      );

  return pw.TableRow(
    decoration: const pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF1F3F8),
    ),
    children: [
      h('No'),
      h('Códigos de muestras'),
      h('Tipo'),
      h('Cantidad'),
      h('Vol/Peso'),
      h('Tipo'),
      h('Descripción'),
      h('N° Lab.'),
    ],
  );
}

pw.TableRow _pdfTableRow(List<String> cells) {
  return pw.TableRow(
    children: cells
        .map(
          (e) => pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(
              e,
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
        )
        .toList(),
  );
}

pw.TableRow _pdfChecklistHeader() {
  pw.Widget h(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 8,
          ),
        ),
      );

  return pw.TableRow(
    decoration: const pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF1F3F8),
    ),
    children: [
      h('Detalle'),
      h('Cumple (Si/No/N/A)'),
      h('Observaciones'),
    ],
  );
}

pw.TableRow _pdfChecklistRow(String detalle, String cumple, String obs) {
  return pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          detalle,
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          cumple,
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          obs,
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
    ],
  );
}

pw.Widget _pdfFirmaBox({
  required String titulo,
  required String firma,
  required String nombre,
  required String fecha,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          titulo,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 8,
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Firma: ${firma.isEmpty ? "________________" : firma}',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Nombre: ${nombre.isEmpty ? "________________" : nombre}',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Fecha: ${fecha.isEmpty ? "________________" : fecha}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ),
  );
}