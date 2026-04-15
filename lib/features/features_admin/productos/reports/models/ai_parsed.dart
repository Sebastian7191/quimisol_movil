import 'dart:convert';

class AiParsed {
  final String status; 
  final String summary;
  final String error;
  final List<String> insights;
  final List<String> risks;
  final List<String> actions;

  const AiParsed({
    required this.status,
    required this.summary,
    required this.error,
    required this.insights,
    required this.risks,
    required this.actions,
  });

  static AiParsed fromAiMap(Map<String, dynamic> ai) {
    final status = (ai['status'] ?? '').toString().trim();

    // Campos normales
    var summary = (ai['summary'] ?? '').toString().trim();
    final err = (ai['error'] ?? '').toString().trim();

    final insights = (ai['insights'] is List)
        ? (ai['insights'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final risks = (ai['risks'] is List)
        ? (ai['risks'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final actions = (ai['actions'] is List)
        ? (ai['actions'] as List).map((e) => e.toString()).toList()
        : <String>[];

    // Si vino mal: summary empieza con {"summary":
    final parsedFromSummary = _tryParseJsonString(summary);
    final raw = (ai['raw'] ?? '').toString().trim();
    final parsedFromRaw = _tryParseJsonString(raw);

    Map<String, dynamic>? best;
    if (parsedFromSummary != null) best = parsedFromSummary;
    if (best == null && parsedFromRaw != null) best = parsedFromRaw;

    if (best != null) {
      summary = (best['summary'] ?? best['resumen'] ?? '').toString().trim();

      List<String> readList(String key) {
        final v = best?[key];
        if (v is List) return v.map((e) => e.toString()).toList();
        return <String>[];
      }

      final ins = readList('insights');
      final rsk = readList('risks');
      final act = readList('actions');

      // Si el doc tenía arrays vacíos pero el JSON los trae, usamos los del JSON
      return AiParsed(
        status: status.isEmpty ? 'unknown' : status,
        summary: summary,
        error: err,
        insights: ins.isNotEmpty ? ins : insights,
        risks: rsk.isNotEmpty ? rsk : risks,
        actions: act.isNotEmpty ? act : actions,
      );
    }

    summary = _stripCodeFences(summary);

// Caso 1: viene como {"summary":"..."}
if (summary.contains('"summary"')) {
  final m = RegExp(r'"summary"\s*:\s*"([\s\S]*)').firstMatch(summary);
  if (m != null && m.groupCount >= 1) {
    summary = m.group(1)!.trim();

    // intenta quitar cierres típicos al final
    summary = summary.replaceAll(RegExp(r'"\s*\}\s*$'), '');
    summary = summary.replaceAll(r'\"', '"');
    summary = summary.trim();
  }
}

// Caso 2: si todavía quedó con comillas sobrantes al inicio/fin
summary = summary.replaceFirst(RegExp(r'^"+'), '');
summary = summary.replaceFirst(RegExp(r'"+$'), '');
summary = summary.trim();
    return AiParsed(
      status: status.isEmpty ? 'unknown' : status,
      summary: summary,
      error: err,
      insights: insights,
      risks: risks,
      actions: actions,
    );
  }

  static String _stripCodeFences(String s) {
    var out = s.trim();
    out = out.replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '');
    out = out.replaceAll(RegExp(r'```$', multiLine: true), '');
    return out.trim();
  }

  static Map<String, dynamic>? _tryParseJsonString(String s) {
    if (s.trim().isEmpty) return null;
    final cleaned = _stripCodeFences(s);

    if (!cleaned.trimLeft().startsWith('{')) return null;

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}