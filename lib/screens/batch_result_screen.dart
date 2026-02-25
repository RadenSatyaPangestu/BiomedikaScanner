import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BatchResultScreen extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const BatchResultScreen({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    // Grouping data berdasarkan "room", "room_name", atau "location"
    Map<String, List<Map<String, dynamic>>> groupedItems = {};
    for (var item in items) {
      String roomName =
          item['room'] ??
          item['room_name'] ??
          item['location'] ??
          'Tanpa Ruangan';
      if (!groupedItems.containsKey(roomName)) {
        groupedItems[roomName] = [];
      }
      groupedItems[roomName]!.add(item);
    }

    // Sort daftar ruangan agar konsisten
    final sortedRooms = groupedItems.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Hasil Sortir (${items.length} Barang)',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: groupedItems.isEmpty
          ? Center(
              child: Text(
                "Tidak ada data barang.",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: sortedRooms.length,
              itemBuilder: (context, index) {
                final room = sortedRooms[index];
                final roomItems = groupedItems[room]!;

                return _buildRoomSection(room, roomItems, context);
              },
            ),
    );
  }

  Widget _buildRoomSection(
    String roomName,
    List<Map<String, dynamic>> roomItems,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Ruangan
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.meeting_room,
                  color: Colors.indigo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  roomName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${roomItems.length} Item",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),

        // List Barang di Dalam Ruangan Tersebut
        ...roomItems.map((item) => _buildItemCard(item, context)),

        const SizedBox(height: 16),
        const Divider(),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, BuildContext context) {
    final String imageUrl = item['image_url'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Gambar Barang
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.broken_image,
                          size: 30,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Container(
                      width: 70,
                      height: 70,
                      color: Colors.grey[100],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 30,
                        color: Colors.grey,
                      ),
                    ),
            ),
            const SizedBox(width: 16),

            // Detail Barang
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? 'Tidak ada nama',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "SN: ${item['serial_number'] ?? '-'}",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildStatusChip(item['status']),
                      const SizedBox(width: 8),
                      // Tampilkan Icon Check jika ada kondisi tambahan yang mau ditampilkan
                      if (item['condition'] != null) ...[
                        Text(
                          "• ${item['condition']}",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    String text = status?.toLowerCase() ?? 'unknown';
    Color color;
    Color bgColor;

    if (text.contains('available')) {
      color = Colors.green.shade700;
      bgColor = Colors.green.shade50;
    } else if (text.contains('borrowed')) {
      color = Colors.red.shade700;
      bgColor = Colors.red.shade50;
    } else {
      color = Colors.orange.shade800;
      bgColor = Colors.orange.shade50;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status ?? 'Unknown',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
