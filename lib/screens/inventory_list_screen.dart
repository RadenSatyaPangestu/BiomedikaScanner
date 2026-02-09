import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:biomedscanner/models/item.dart';
import 'package:biomedscanner/services/api_service.dart';
import 'package:biomedscanner/screens/item_form_screen.dart';
import 'package:biomedscanner/screens/item_detail_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Item> _items = [];
  bool _isLoading = false;
  bool _isMoreLoading = false;
  int _currentPage = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isMoreLoading &&
        _currentPage < _lastPage) {
      _loadMoreItems();
    }
  }

  Future<void> _fetchItems({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _items.clear();
      });
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.getItems(
        page: _currentPage,
        search: _searchController.text,
      );

      final dynamic responseData = response['data'];
      final List<dynamic> data = (responseData is List) ? responseData : [];

      final List<Item> newItems = data
          .map((json) => Item.fromJson(json))
          .toList();

      setState(() {
        _items = newItems;
        _lastPage = response['last_page'] ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadMoreItems() async {
    setState(() => _isMoreLoading = true);
    _currentPage++;

    try {
      final response = await _apiService.getItems(
        page: _currentPage,
        search: _searchController.text,
      );

      final dynamic responseData = response['data'];
      final List<dynamic> data = (responseData is List) ? responseData : [];

      final List<Item> newItems = data
          .map((json) => Item.fromJson(json))
          .toList();

      setState(() {
        _items.addAll(newItems);
        _isMoreLoading = false;
      });
    } catch (e) {
      setState(() {
        _isMoreLoading = false;
        _currentPage--; // Revert page if failed
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchItems(refresh: true);
    });
  }

  void _navigateToDetail(Item item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
    );

    if (result == true) {
      _fetchItems(refresh: true); // Refresh if item was edited or deleted
    }
  }

  void _navigateToForm({Item? item}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemFormScreen(item: item)),
    );

    if (result == true) {
      _fetchItems(refresh: true); // Refresh list after add
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Barang'), elevation: 0),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari Nama / S.N...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
            ),
          ),

          // List Inventory
          Expanded(
            child: _items.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Barang tidak ditemukan',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _fetchItems(refresh: true),
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _items.length + (_isMoreLoading ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final item = _items[index];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => _navigateToDetail(item),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Icon Box
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.inventory,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Data
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.itemName,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.serialNumber,
                                              style: GoogleFonts.sourceCodePro(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on,
                                                  size: 14,
                                                  color: Colors.grey[500],
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    item.roomName ??
                                                        'Unknown Location',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                if (item.status != null) ...[
                                                  _buildStatusBadge(
                                                    item.status!,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),

          if (_isLoading && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'baik':
      case 'available':
      case 'tersedia':
        color = Colors.green;
        break;
      case 'rusak':
      case 'broken':
        color = Colors.red;
        break;
      case 'perbaikan':
      case 'maintenace':
      case 'maintenance': // Typo handling
        color = Colors.orange;
        break;
      case 'hilang':
      case 'lost':
        color = Colors.black;
        break;
      case 'dipinjam':
      case 'borrowed':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
