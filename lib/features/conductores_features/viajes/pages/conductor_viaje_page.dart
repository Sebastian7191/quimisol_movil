// lib/features/conductores_features/pages/conductor_trips_page.dart
import 'package:flutter/material.dart';

class ConductorTripsPage extends StatelessWidget {
  const ConductorTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        "name": "Danna",
        "initial": "D",
        "distance": "~1,1km",
        "price": "Bs 15",
        "rating": "4,44",
        "reviews": "185",
        "time": "Ahora mismo",
        "streetMain": "C. Ecuador (Noroeste)",
        "streetDetail": "Condominio \"Las Acacias\" (Av Decima)",
        "badge": null
      },
      {
        "name": "Jason Joel",
        "initial": "J",
        "distance": "~2,3km",
        "price": "Bs 14,20",
        "rating": "4,12",
        "reviews": "175",
        "time": "2 min.",
        "streetMain": "+594, Cochabamba (Bolivia)",
        "streetDetail": "Oasis San Jacinto (75983822, Cochabamba)\nQue el auto tenga parrilla para llevar cosas porfavor",
        "badge": "Precio justo"
      },
      {
        "name": "Carlos",
        "initial": null,
        "photo":
            "https://i.pravatar.cc/150?img=12", // Ejemplo de foto
        "distance": "~2,3km",
        "price": "Bs 13",
        "rating": "4,8",
        "reviews": "191",
        "time": "Ahora mismo",
        "streetMain": "Av. Circunvalación (Queru Queru Alto)",
        "streetDetail": "Santiváñez 182 (Sudoeste)",
        "badge": null
      },
      {
        "name": "Susana",
        "initial": "S",
        "distance": "~2,9km",
        "price": "Bs 7,50",
        "rating": "4,61",
        "reviews": "158",
        "time": "Ahora mismo",
        "streetMain": "Av. Circunvalación (Pacata)",
        "streetDetail":
            "Colegio San Agustín (Avenida América, Cochabamba)",
        "badge": "Pago por código QR"
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFEAEAEA)),
              ),
              color: Colors.white,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFEEEEEE),
                  backgroundImage: item["photo"] != null
                      ? NetworkImage(item["photo"]!)
                      : null,
                  child: item["photo"] == null
                      ? Text(
                          item["initial"] ?? "?",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),

                const SizedBox(width: 12),

                // Info principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item["distance"]!,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        item["price"]!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item["streetMain"]!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item["streetDetail"]!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Badge (si existe)
                      if (item["badge"] != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: item["badge"] == "Pago por código QR"
                                  ? const Color(0xFFD6FF94)
                                  : const Color(0xFFEAD7FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item["badge"]!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: item["badge"] == "Pago por código QR"
                                    ? Colors.black
                                    : const Color(0xFF8B4FC5),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Rating + menú
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 2),
                        Text(
                          "${item["rating"]} (${item["reviews"]})",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      item["time"]!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
