import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_parsed.dart';
import '../services/predictive_service.dart';
import '../utils/pr_report_formatters.dart';

import 'pr_ai_box.dart';
import 'pr_common_widgets.dart';
import 'pr_overview_box.dart';
import 'pr_product_list.dart';

class PredictiveReportPanel extends StatefulWidget {
  const PredictiveReportPanel({
    super.key,
    required this.departamentoSeleccionado,
  });

  final String? departamentoSeleccionado;

  @override
  State<PredictiveReportPanel> createState() => _PredictiveReportPanelState();
}

class _PredictiveReportPanelState extends State<PredictiveReportPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = PredictiveReportService();

  bool _loading = false;
  String? _reportId;
  String? _error;

  // Parámetros
  int historyWeeks = 12;
  int horizonDays = 28;
  bool deliveredOnly = true;
  int? limitProducts = 50;

  bool _showAllProducts = false;

  String get _deptKey {
    final d = (widget.departamentoSeleccionado ?? '').trim();
    return d.isEmpty ? 'ALL' : d.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }

  String get _prefsKey => 'predictive_report_last_id_$_deptKey';

  Future<String?> _findLatestReportId() async {
  final db = FirebaseFirestore.instance;

  final dept = (widget.departamentoSeleccionado ?? '').trim();
  final hasDept = dept.isNotEmpty;

  final snap = await db
      .collection('reports')
      .orderBy('createdAt', descending: true)
      .limit(30)
      .get();

  String? partialCandidate;

  for (final doc in snap.docs) {
    final data = doc.data();

    final type = (data['type'] ?? '').toString().trim();
    if (type != 'predictivo') continue;

    final filters = (data['filters'] is Map)
        ? (data['filters'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final reportDept = (filters['departamento'] ?? '').toString().trim();
    final matchesDept = !hasDept || reportDept == dept;
    if (!matchesDept) continue;

    final ai = (data['ai'] is Map)
        ? (data['ai'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final status = (ai['status'] ?? '').toString().trim().toLowerCase();

    // Si encontramos un reporte completo, usamos ese 
    if (status == 'done') {
      return doc.id;
    }

    // Guardamos un parcial solo como respaldo
    if (partialCandidate == null && (status == 'done_text' || status == 'generating')) {
      partialCandidate = doc.id;
    }
  }

  // Si no hubo uno completo, devolvemos el mejor parcial encontrado
  return partialCandidate;
}
  Future<void> _persistReportId(String? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null || id.trim().isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, id.trim());
      }
    } catch (_) {
      // silencioso xdd
    }
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final id = await _svc.generate(
        historyWeeks: historyWeeks,
        horizonDays: horizonDays,
        deliveredOnly: deliveredOnly,
        limitProducts: limitProducts,
        departamento: widget.departamentoSeleccionado,
      );

      if (!mounted) return;
      setState(() => _reportId = id);
      await _persistReportId(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

 Future<void> _confirmAndGenerate() async {
  if (_loading) return;

  // Si NO hay reporte cargado, primero intentamos cargar el más reciente
  if (_reportId == null) {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final latestId = await _findLatestReportId();

      if (!mounted) return;

      if (latestId != null && latestId.trim().isNotEmpty) {
        setState(() => _reportId = latestId.trim());
        return;
      }

      // Si no existe ninguno, recién generamos
      await _generate();
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Si YA hay reporte cargado, mostramos el dialog y si acepta, generamos uno nuevo
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Generar un nuevo reporte?'),
      content: const Text(
        'Ya tienes un reporte. Si generas otro, se creará un nuevo reporte y se mostrará el más reciente.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Generar'),
        ),
      ],
    ),
  );

  if (ok == true) {
    await _generate();
  }
}
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final dept = (widget.departamentoSeleccionado ?? '').trim();
    final hasDept = dept.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: Palette.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Palette.primary.withValues(alpha: 0.15)),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Palette.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Reporte predictivo',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                  ),
                ),
              ),
              if (_reportId != null)
                AiStatusPill(
                  status: 'ID guardado',
                  //color: Palette.statsSuccess,
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Actions + params
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PredictivePrimaryButton(
                loading: _loading,
                label: _loading
              ? 'Cargando…'
              : (_reportId == null ? 'Ver último reporte' : 'Generar nuevo reporte'),
                onPressed: _loading ? null : _confirmAndGenerate,
              ),
              PredictiveMiniChip(
                label: 'Histórico: $historyWeeks semanas',
                selected: true,
                onTap: () => setState(() => historyWeeks = (historyWeeks == 12) ? 8 : 12),
              ),
              PredictiveMiniChip(
                label: 'Horizonte: $horizonDays días',
                selected: true,
                onTap: () => setState(() => horizonDays = (horizonDays == 28) ? 14 : 28),
              ),
              PredictiveMiniChip(
                label: deliveredOnly ? 'Solo entregados' : 'Incluye no entregados',
                selected: deliveredOnly,
                onTap: () => setState(() => deliveredOnly = !deliveredOnly),
              ),
              if (hasDept)
                PredictiveMiniChip(
                  label: 'Dpto: $dept',
                  selected: true,
                  onTap: () {},
                ),
              if (_reportId != null)
                PredictiveMiniChip(
                  label: 'Limpiar',
                  selected: false,
                  onTap: () async {
                    setState(() => _reportId = null);
                    await _persistReportId(null);
                  },
                ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            PredictiveInlineError(text: _error!),
          ],

          const SizedBox(height: 12),

          if (_reportId == null)
            Text(
              'Genera un reporte para verlo aquí.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Palette.ink.withValues(alpha: 0.75),
              ),
            )
          else
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _svc.reportStream(_reportId!),
              builder: (context, snap) {
                if (snap.hasError) {
                  return PredictiveInlineError(text: 'Error leyendo reporte: ${snap.error}');
                }

                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: LinearProgressIndicator(minHeight: 3),
                  );
                }

                final doc = snap.data;
                if (doc == null || !doc.exists) {
                  return Text(
                    'El reporte todavía se está creando…',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Palette.ink.withValues(alpha: 0.70),
                    ),
                  );
                }

                final data = doc.data() ?? {};
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                final overview = (data['overview'] as Map?)?.cast<String, dynamic>() ?? {};
                final perProduct = (data['perProduct'] as List?)?.cast<dynamic>() ?? const [];

                final aiRawMap = (data['ai'] as Map?)?.cast<String, dynamic>() ?? {};
                final ai = AiParsed.fromAiMap(aiRawMap);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //borrar o comentar luego luego
                    //_kv('Report ID', _reportId!),
                    _kv('Creado', formatDateNice(createdAt)),

                    const Divider(height: 22),

                    const Text(
                      'Resumen',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Palette.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PredictiveOverviewBox (overview: overview),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Productos destacados',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Palette.ink,
                            ),
                          ),
                        ),
                        if (perProduct.length > 6)
                          TextButton(
                            onPressed: () => setState(() => _showAllProducts = !_showAllProducts),
                            child: Text(
                              _showAllProducts ? 'Ver menos' : 'Ver más',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PerProductList(
                      perProduct: perProduct,
                      showAll: _showAllProducts,
                    ),

                    const Divider(height: 22),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'IA (análisis ejecutivo)',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Palette.ink,
                            ),
                          ),
                        ),
                        AiStatusPill(status: ai.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AiBox(ai: ai),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              k,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Palette.ink,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                color: Palette.ink.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}