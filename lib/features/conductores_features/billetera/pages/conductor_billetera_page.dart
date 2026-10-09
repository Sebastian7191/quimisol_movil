import 'package:flutter/material.dart';

class ConductorBilleteraPage extends StatelessWidget {
  const ConductorBilleteraPage({super.key});

  @override
  Widget build(BuildContext context) {
    const softBg = Color(0xFFF5F5F5);
    const primaryText = Color(0xFF1F2933);
    const accentGreen = Color(0xFF2E8B57);

    // Mock de movimientos
    final transactions = [
      {
        'date': 'Hoy',
        'items': [
          {
            'title': 'Pago viaje #1245',
            'subtitle': 'Pasajero: Jason Joel',
            'amount': '+ Bs 18,50',
            'isIncome': true,
            'icon': Icons.local_taxi_rounded,
          },
          {
            'title': 'Propina',
            'subtitle': 'Pasajero: Danna',
            'amount': '+ Bs 2,00',
            'isIncome': true,
            'icon': Icons.stars_rounded,
          },
          {
            'title': 'Cargo por servicio',
            'subtitle': 'Comisión quimisol_movil',
            'amount': '- Bs 2,05',
            'isIncome': false,
            'icon': Icons.percent_rounded,
          },
        ],
      },
      {
        'date': 'Ayer',
        'items': [
          {
            'title': 'Retiro a cuenta bancaria',
            'subtitle': '**** 1234 · Banco Unión',
            'amount': '- Bs 50,00',
            'isIncome': false,
            'icon': Icons.account_balance_rounded,
          },
          {
            'title': 'Pago viaje #1238',
            'subtitle': 'Pasajero: Susana',
            'amount': '+ Bs 12,40',
            'isIncome': true,
            'icon': Icons.local_taxi_rounded,
          },
        ],
      },
    ];

    return Scaffold(
      backgroundColor: softBg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ────────── CARD SALDO ──────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo de la cartera',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bs 20,04',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: () {
                            // TODO: abrir flujo de retiro
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryText,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_downward_rounded),
                          label: const Text(
                            'Retirar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: abrir flujo de recarga
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: primaryText),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(
                            Icons.add_rounded,
                            color: primaryText,
                          ),
                          label: const Text(
                            'Añadir fondos',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.black45,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Los pagos de tus viajes se acreditan automáticamente a tu cartera.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ────────── HISTORIAL ──────────
          const Text(
            'Historial de movimientos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 8),

          ...transactions.map((group) {
            return _TransactionGroup(
              dateLabel: group['date'] as String,
              items: (group['items'] as List<Map<String, dynamic>>),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _TransactionGroup extends StatelessWidget {
  final String dateLabel;
  final List<Map<String, dynamic>> items;

  const _TransactionGroup({required this.dateLabel, required this.items});

  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F2933);
    const accentGreen = Color(0xFF2E8B57);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          dateLabel,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map((tx) {
          final bool isIncome = tx['isIncome'] as bool;
          final String amount = tx['amount'] as String;
          final String title = tx['title'] as String;
          final String subtitle = tx['subtitle'] as String;
          final IconData icon = tx['icon'] as IconData;

          return Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isIncome ? accentGreen : Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isIncome ? accentGreen : Colors.redAccent,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
