import 'package:flutter/material.dart';

class ConductorRendimientoPage extends StatelessWidget {
  const ConductorRendimientoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F2933);
    const softBg = Color(0xFFF5F5F5);
    const levelBg = Color(0xFFE0FAFF); // celestito
    const walletGrey = Color(0xFFF2F2F2);

    return Scaffold(
      backgroundColor: softBg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ────────── CARD NIVEL / RANGO ──────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: levelBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + nivel
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        const CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(
                            'https://i.pravatar.cc/150?img=11',
                          ),
                        ),
                        Positioned(
                          bottom: -2,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.star,
                                    size: 12, color: Colors.amber),
                                SizedBox(width: 3),
                                Text(
                                  '4.90',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Text(
                              'Básico',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: primaryText,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.diamond_rounded,
                              size: 18,
                              color: Color(0xFF00A2FF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tu nivel esta semana',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Barra de progreso a Platino
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBEEBFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '25 viajes a Platino',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          // progreso
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.35,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          // circulito del diamante
                          Positioned(
                            right: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.diamond_rounded,
                                size: 15,
                                color: Color(0xFF00A2FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Mantén la calificación 4.80+',
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryText,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Botón "Ver beneficios"
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Ver beneficios',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: primaryText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ────────── INGRESOS DE HOY ──────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // título + arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Ingresos de hoy',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.black45),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bs0',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 16),

                // Agregar meta diaria
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: walletGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(width: 12),
                      Icon(Icons.add, size: 20, color: primaryText),
                      SizedBox(width: 8),
                      Text(
                        'Agregar meta diaria',
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Saldo de la cartera + Recarga
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 20, color: primaryText),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bs 20,04',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Saldo de la cartera',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: walletGrey,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Recarga',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: primaryText,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Bonificaciones
                _SettingsRow(
                  icon: Icons.schedule_rounded,
                  title: '0',
                  subtitle: 'Bonificaciones',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ────────── % pago por servicio ──────────
          _SimpleCardRow(
            leading: const Text(
              '%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: primaryText,
              ),
            ),
            title:
                '9,99% — el pago por el servicio de inDrive es justo',
          ),

          const SizedBox(height: 12),

          // ────────── LOGROS ──────────
          _SimpleCardRow(
            leading: const Icon(Icons.flag_outlined,
                color: primaryText),
            title: 'Logros',
          ),
        ],
      ),
    );
  }
}

// Row tipo "configuración" con icono, título y subtítulo
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F2933);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryText),
          const SizedBox(width: 10),
          Column(
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
        ],
      ),
    );
  }
}

// Card simple con título y chevron
class _SimpleCardRow extends StatelessWidget {
  final Widget leading;
  final String title;

  const _SimpleCardRow({
    required this.leading,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2933),
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.black45),
        ],
      ),
    );
  }
}
