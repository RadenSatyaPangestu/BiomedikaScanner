import 'package:flutter/material.dart';
import 'package:biomedscanner/models/item.dart';
import 'package:biomedscanner/services/api_service.dart';
import 'package:biomedscanner/screens/item_form_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final Item item;
  final ApiService _apiService = ApiService();

  ItemDetailScreen({super.key, required this.item});

  void _navigateToEdit(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemFormScreen(item: item)),
    );

    if (result == true && context.mounted) {
      Navigator.pop(context, true); // Return true to trigger refresh
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Barang?'),
        content: Text('Anda yakin ingin menghapus "${item.itemName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _deleteItem(context);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context) async {
    if (item.id == null) return;

    try {
      await _apiService.deleteItem(item.id.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barang berhasil dihapus')),
        );
        Navigator.pop(context, true); // Pop back to list with refresh signal
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Barang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEdit(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Center(
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: (item.imageUrl == null || item.imageUrl!.isEmpty)
                    ? const Icon(
                        Icons.image_not_supported,
                        size: 80,
                        color: Colors.grey,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          (loadingProgress.expectedTotalBytes ??
                                              1)
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.broken_image,
                              size: 80,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Main Info
            Text(
              item.itemName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildStatusBadge(item.status ?? 'unknown'),
            const SizedBox(height: 24),

            const Divider(),

            // Details Grid
            _buildDetailRow('Serial Number', item.serialNumber),
            _buildDetailRow('Asset Number', item.assetNumber ?? '-'),
            _buildDetailRow('Brand', item.brand ?? '-'),
            _buildDetailRow('Type / Category', item.type ?? item.category),
            _buildDetailRow('Location', item.roomName ?? 'Unknown'),
            _buildDetailRow('Condition', item.condition ?? '-'),
            _buildDetailRow('Quantity', item.quantity.toString()),
            _buildDetailRow('Fiscal Group', item.fiscalGroup ?? '-'),
            _buildDetailRow('Source', item.source ?? '-'),
            _buildDetailRow(
              'Acq. Year',
              item.acquisitionYear?.toString() ?? '-',
            ),
            _buildDetailRow(
              'Placed In Service',
              item.placedInServiceAt?.toIso8601String().split('T').first ?? '-',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'available':
      case 'baik':
        color = Colors.green;
        break;
      case 'borrowed':
      case 'dipinjam':
        color = Colors.blue;
        break;
      case 'broken':
      case 'rusak':
        color = Colors.red;
        break;
      case 'maintenance':
      case 'perbaikan':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
