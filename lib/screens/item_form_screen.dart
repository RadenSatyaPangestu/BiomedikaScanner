import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:biomedscanner/models/item.dart';
import 'package:biomedscanner/services/api_service.dart';

class ItemFormScreen extends StatefulWidget {
  final Item? item;

  const ItemFormScreen({super.key, this.item});

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _serialController;
  late TextEditingController _assetController;
  late TextEditingController _brandController;
  late TextEditingController _quantityController;
  late TextEditingController _sourceController;
  late TextEditingController _fiscalController;

  // Dropdown & Selectors
  String? _selectedStatus;
  final List<String> _statusList = [
    'available',
    'borrowed',
    'maintenance',
    'disposed',
  ];

  String? _selectedCondition;
  final List<String> _conditionList = ['good', 'damaged', 'broken'];

  dynamic _selectedRoomId;
  List<dynamic> _rooms = [];

  // Type (Category) - using fetchCategories or free text if categories empty
  String? _selectedType;
  List<dynamic> _categories = [];
  bool _useTypeDropdown = false;
  late TextEditingController _typeController;

  // Dates
  int? _acquisitionYear;
  DateTime? _placedInServiceAt;

  // Image
  File? _imageFile;
  String? _currentImageUrl;

  bool _isLoading = false;
  bool _isEditing = false;
  bool _isInitLoading = true;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.item != null;
    _typeController = TextEditingController(text: widget.item?.type ?? '');
    _initControllers();
    _fetchDependencies();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.item?.itemName ?? '');
    _serialController = TextEditingController(
      text: widget.item?.serialNumber ?? '',
    );
    _assetController = TextEditingController(
      text: widget.item?.assetNumber ?? '',
    );
    _brandController = TextEditingController(text: widget.item?.brand ?? '');
    _quantityController = TextEditingController(
      text: widget.item?.quantity.toString() ?? '1',
    );
    _sourceController = TextEditingController(text: widget.item?.source ?? '');
    _fiscalController = TextEditingController(
      text: widget.item?.fiscalGroup ?? '',
    );

    if (_isEditing) {
      if (_statusList.contains(widget.item?.status)) {
        _selectedStatus = widget.item?.status;
      }
      if (_conditionList.contains(widget.item?.condition)) {
        _selectedCondition = widget.item?.condition;
      }
      _selectedRoomId = widget.item?.roomId;
      _acquisitionYear = widget.item?.acquisitionYear;
      _placedInServiceAt = widget.item?.placedInServiceAt;
      _currentImageUrl = widget.item?.imagePath;
      _selectedType = widget.item?.type;
    } else {
      _selectedStatus = 'available';
      _selectedCondition = 'good';
    }
  }

  Future<void> _fetchDependencies() async {
    try {
      final results = await Future.wait([
        _apiService.fetchRooms(),
        _apiService.fetchCategories(),
      ]);

      if (mounted) {
        setState(() {
          _rooms = results[0];
          _categories = results[1];
          _isInitLoading = false;
          _useTypeDropdown = _categories.isNotEmpty;

          // Try to match type if dropdown
          if (_useTypeDropdown && _selectedType != null) {
            // Ensure selectedType exists in categories (assuming category list is strings or objects with 'name')
            // Simplicity: assume category list contains Objects with 'name' or Strings.
            // We'll adapt in build.
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isInitLoading = false);
      print('Failed to fetch deps: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serialController.dispose();
    _assetController.dispose();
    _brandController.dispose();
    _typeController.dispose();
    _quantityController.dispose();
    _sourceController.dispose();
    _fiscalController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (photo != null) {
      setState(() {
        _imageFile = File(photo.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _placedInServiceAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _placedInServiceAt) {
      setState(() {
        _placedInServiceAt = picked;
      });
    }
  }

  Future<void> _selectYear(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Select Year"),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(DateTime.now().year - 20, 1),
              lastDate: DateTime(DateTime.now().year + 5, 1),
              initialDate: DateTime.now(),
              selectedDate: _acquisitionYear != null
                  ? DateTime(_acquisitionYear!)
                  : DateTime.now(),
              onChanged: (DateTime dateTime) {
                setState(() {
                  _acquisitionYear = dateTime.year;
                });
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Final Type Logic
    String finalType = _useTypeDropdown && _selectedType != null
        ? _selectedType!
        : _typeController.text.trim();

    final data = {
      'name': _nameController.text.trim(),
      'serial_number': _serialController.text.trim(),
      'asset_number': _assetController.text.trim(),
      'brand': _brandController.text.trim(),
      'type': finalType,
      'quantity': _quantityController.text.trim(),
      'source': _sourceController.text.trim(),
      'fiscal_group': _fiscalController.text.trim(),

      'status': _selectedStatus,
      'condition': _selectedCondition,
      'room_id': _selectedRoomId,

      'acquisition_year': _acquisitionYear,
      'placed_in_service_at': _placedInServiceAt
          ?.toIso8601String()
          .split('T')
          .first,
    };

    try {
      if (_isEditing) {
        await _apiService.updateItem(
          widget.item!.id.toString(),
          data,
          imagePath: _imageFile?.path,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Updated successfully')));
        }
      } else {
        await _apiService.createItem(data, imagePath: _imageFile?.path);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Created successfully')));
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Item' : 'New Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Image Section ---
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (_currentImageUrl != null
                              ? NetworkImage(_currentImageUrl!) as ImageProvider
                              : null),
                    child: (_imageFile == null && _currentImageUrl == null)
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 30,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- Mandatory Fields ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serialController,
                decoration: const InputDecoration(
                  labelText: 'Serial Number *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // --- Details ---
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _assetController,
                      decoration: const InputDecoration(
                        labelText: 'Asset Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _useTypeDropdown
                        ? DropdownButtonFormField<String>(
                            initialValue:
                                _selectedType, // Should make sure this matches items value
                            decoration: const InputDecoration(
                              labelText: 'Type / category',
                              border: OutlineInputBorder(),
                            ),
                            items: _categories.map<DropdownMenuItem<String>>((
                              cat,
                            ) {
                              // Assuming cat is Map {'id':.., 'name':..} or String
                              String val = cat is Map
                                  ? (cat['name'] ?? cat['id'].toString())
                                  : cat.toString();
                              return DropdownMenuItem(
                                value: val,
                                child: Text(val),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedType = val),
                          )
                        : TextFormField(
                            controller: _typeController,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              border: OutlineInputBorder(),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- Dropdowns ---
              DropdownButtonFormField<dynamic>(
                initialValue: _selectedRoomId, // Ensure type matching (int vs string)
                decoration: const InputDecoration(
                  labelText: 'Room / Location',
                  border: OutlineInputBorder(),
                ),
                items: _rooms.map((room) {
                  return DropdownMenuItem(
                    value: room['id'],
                    child: Text(room['name'] ?? 'Unknown Room'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedRoomId = val),
                hint: const Text("Select Room"),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: _statusList
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedStatus = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCondition,
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        border: OutlineInputBorder(),
                      ),
                      items: _conditionList
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCondition = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- Dates ---
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectYear(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Acq. Year',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _acquisitionYear?.toString() ?? 'Select Year',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Placed In Service',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _placedInServiceAt == null
                              ? 'Select Date'
                              : "${_placedInServiceAt!.day}/${_placedInServiceAt!.month}/${_placedInServiceAt!.year}",
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- Other ---
              TextFormField(
                controller: _sourceController,
                decoration: const InputDecoration(
                  labelText: 'Source (e.g. Purchase)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fiscalController,
                decoration: const InputDecoration(
                  labelText: 'Fiscal Group',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submitForm,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
