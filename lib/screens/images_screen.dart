import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:save_files_des/database/database_helper.dart';
import 'package:save_files_des/models/image_model.dart';
import 'package:save_files_des/models/category_model.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key});

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  final _categoryNameController = TextEditingController();
  final _searchController = TextEditingController();
  List<ImageModel> _images = [];
  List<ImageModel> _filteredImages = [];
  List<CategoryModel> _categories = [];
  int? _selectedCategoryId;
  bool _isLoading = false;
  bool _isGridView = true;
  Color _selectedColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categoriesData = await DatabaseHelper.instance.getAllCategories(
        'images',
      );
      
      List<Map<String, dynamic>> imagesData;
      if (_searchController.text.isNotEmpty) {
        imagesData = await DatabaseHelper.instance.searchImages(
          _searchController.text.trim(),
          categoryId: _selectedCategoryId,
        );
      } else {
        imagesData = await DatabaseHelper.instance.getAllImages(
          categoryId: _selectedCategoryId,
        );
      }

      setState(() {
        _categories =
            categoriesData.map((map) => CategoryModel.fromMap(map)).toList();
        _images = imagesData.map((map) => ImageModel.fromMap(map)).toList();
        _filteredImages = _images;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تحميل البيانات: $e')));
      }
    }
  }

  void _onSearchChanged() {
    // البحث من قاعدة البيانات عند تغيير النص
    _loadData();
  }

  Future<void> _pickImage() async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى إضافة قسم أولاً')));
      return;
    }

    int? categoryId = _selectedCategoryId;
    if (categoryId == null && _categories.isNotEmpty) {
      categoryId = _categories.first.id;
    } else if (categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى إضافة قسم أولاً')));
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // الحصول على المسار المختار من الإعدادات
        final prefs = await SharedPreferences.getInstance();
        final storagePath = prefs.getString('storage_path');

        if (storagePath == null || storagePath.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('يرجى اختيار مسار الحفظ من الإعدادات'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final imagesDir = Directory(path.join(storagePath, 'images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        int savedCount = 0;
        for (var file in result.files) {
          if (file.path != null) {
            final filePath = file.path!;
            final fileName = file.name;
            final fileObj = File(filePath);
            final fileSize = await fileObj.length();

            final savedPath = path.join(imagesDir.path, fileName);
            await fileObj.copy(savedPath);

            await DatabaseHelper.instance.insertImage(
              fileName,
              savedPath,
              fileSize,
              categoryId: categoryId,
            );
            savedCount++;
          }
        }

        _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حفظ $savedCount صورة'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الصور: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addCategory() async {
    _categoryNameController.clear();
    _selectedColor = Colors.green;

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('إضافة قسم جديد'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _categoryNameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم القسم',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'اختر اللون:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children:
                            [
                              Colors.green,
                              Colors.blue,
                              Colors.orange,
                              Colors.purple,
                              Colors.red,
                              Colors.teal,
                              Colors.pink,
                              Colors.indigo,
                            ].map((color) {
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    _selectedColor = color;
                                  });
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          _selectedColor == color
                                              ? Colors.black
                                              : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (_categoryNameController.text.isNotEmpty) {
                          Navigator.pop(context, true);
                        }
                      },
                      child: const Text('إضافة'),
                    ),
                  ],
                ),
          ),
    );

    if (result == true && _categoryNameController.text.isNotEmpty) {
      try {
        await DatabaseHelper.instance.insertCategory(
          _categoryNameController.text.trim(),
          'images',
          '#${_selectedColor.value.toRadixString(16).substring(2)}',
        );
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة القسم بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في إضافة القسم: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _downloadImage(ImageModel image) async {
    try {
      final fileObj = File(image.path);
      if (!await fileObj.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الصورة غير موجودة'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // اختيار مكان التنزيل
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مكان حفظ الصورة',
      );

      if (selectedDirectory != null) {
        final destinationPath = path.join(selectedDirectory, image.name);

        // نسخ الصورة إلى المكان المختار
        await fileObj.copy(destinationPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تنزيل الصورة إلى: $selectedDirectory'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تنزيل الصورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteImage(ImageModel image) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل أنت متأكد من حذف الصورة "${image.name}"؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        final fileObj = File(image.path);
        if (await fileObj.exists()) {
          await fileObj.delete();
        }

        if (image.id != null) {
          await DatabaseHelper.instance.deleteImage(image.id!);
        }

        _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الصورة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حذف الصورة: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showImageDialog(ImageModel image) {
    final category =
        _categories.isNotEmpty
            ? _categories.firstWhere(
              (c) => c.id == image.categoryId,
              orElse:
                  () => CategoryModel(
                    id: null,
                    name: 'بلا قسم',
                    type: 'images',
                    color: '#9E9E9E',
                    createdAt: DateTime.now().toIso8601String(),
                  ),
            )
            : CategoryModel(
              id: null,
              name: 'بلا قسم',
              type: 'images',
              color: '#9E9E9E',
              createdAt: DateTime.now().toIso8601String(),
            );

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(image.name),
                  backgroundColor: _getCategoryColor(category),
                  foregroundColor: Colors.white,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteImage(image);
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.file(File(image.path), fit: BoxFit.contain),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoItem(
                            Icons.category,
                            category.name,
                            _getCategoryColor(category),
                          ),
                          _buildInfoItem(
                            Icons.storage,
                            _formatFileSize(image.size),
                            Colors.grey,
                          ),
                          _buildInfoItem(
                            Icons.access_time,
                            DateTime.parse(
                              image.createdAt,
                            ).toString().split('.')[0].split(' ')[0],
                            Colors.grey,
                          ),
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

  Widget _buildInfoItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Color _getCategoryColor(CategoryModel? category) {
    if (category?.color == null) return Colors.grey;
    try {
      return Color(int.parse(category!.color!.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  String _formatFileSize(int? size) {
    if (size == null) return 'غير معروف';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // شريط البحث والأزرار
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // حقل البحث
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '...بحث عن صورة',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // الأزرار
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.folder, color: Colors.white),
                        label: const Text('قسم جديد'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(
                          Icons.add_photo_alternate,
                          color: Colors.white,
                        ),
                        label: const Text('إضافة صور'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
                      onPressed: () {
                        setState(() {
                          _isGridView = !_isGridView;
                        });
                      },
                      tooltip: _isGridView ? 'عرض قائمة' : 'عرض شبكة',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // قائمة الأقسام
          if (_categories.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('الكل'),
                        selected: _selectedCategoryId == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategoryId = null;
                          });
                          _loadData();
                        },
                        selectedColor: Colors.green.shade100,
                        checkmarkColor: Colors.green.shade700,
                      ),
                    );
                  }
                  final category = _categories[index - 1];
                  final isSelected = _selectedCategoryId == category.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: CircleAvatar(
                        backgroundColor: _getCategoryColor(category),
                        radius: 10,
                      ),
                      label: Text(category.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategoryId = selected ? category.id : null;
                        });
                        _loadData();
                      },
                      selectedColor: _getCategoryColor(
                        category,
                      ).withOpacity(0.2),
                      checkmarkColor: _getCategoryColor(category),
                    ),
                  );
                },
              ),
            ),
          // عرض الصور
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredImages.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'لا توجد صور'
                                : 'لا توجد نتائج للبحث',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadData,
                      child:
                          _isGridView
                              ? GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1,
                                    ),
                                itemCount: _filteredImages.length,
                                itemBuilder: (context, index) {
                                  final image = _filteredImages[index];
                                  final category =
                                      _categories.isNotEmpty
                                          ? _categories.firstWhere(
                                            (c) => c.id == image.categoryId,
                                            orElse:
                                                () => CategoryModel(
                                                  id: null,
                                                  name: 'بلا قسم',
                                                  type: 'images',
                                                  color: '#9E9E9E',
                                                  createdAt:
                                                      DateTime.now()
                                                          .toIso8601String(),
                                                ),
                                          )
                                          : CategoryModel(
                                            id: null,
                                            name: 'بلا قسم',
                                            type: 'images',
                                            color: '#9E9E9E',
                                            createdAt:
                                                DateTime.now()
                                                    .toIso8601String(),
                                          );
                                  return GestureDetector(
                                    onTap: () => _showImageDialog(image),
                                    child: Card(
                                      elevation: 2,
                                      clipBehavior: Clip.antiAlias,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.file(
                                            File(image.path),
                                            fit: BoxFit.cover,
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return Container(
                                                color: Colors.grey.shade200,
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  size: 50,
                                                ),
                                              );
                                            },
                                          ),
                                          // Gradient overlay
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black.withOpacity(
                                                      0.7,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      image.name,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: _getCategoryColor(
                                                        category,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      category.name,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // Action buttons
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.download,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                    onPressed:
                                                        () => _downloadImage(
                                                          image,
                                                        ),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    tooltip: 'تنزيل',
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                    onPressed:
                                                        () =>
                                                            _deleteImage(image),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    tooltip: 'حذف',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredImages.length,
                                itemBuilder: (context, index) {
                                  final image = _filteredImages[index];
                                  final category =
                                      _categories.isNotEmpty
                                          ? _categories.firstWhere(
                                            (c) => c.id == image.categoryId,
                                            orElse:
                                                () => CategoryModel(
                                                  id: null,
                                                  name: 'بلا قسم',
                                                  type: 'images',
                                                  color: '#9E9E9E',
                                                  createdAt:
                                                      DateTime.now()
                                                          .toIso8601String(),
                                                ),
                                          )
                                          : CategoryModel(
                                            id: null,
                                            name: 'بلا قسم',
                                            type: 'images',
                                            color: '#9E9E9E',
                                            createdAt:
                                                DateTime.now()
                                                    .toIso8601String(),
                                          );
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(8),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(image.path),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              width: 80,
                                              height: 80,
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                Icons.broken_image,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      title: Text(
                                        image.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.category,
                                                size: 14,
                                                color: _getCategoryColor(
                                                  category,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                category.name,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: _getCategoryColor(
                                                    category,
                                                  ),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.storage,
                                                size: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatFileSize(image.size),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.download,
                                              color: Colors.blue,
                                            ),
                                            onPressed:
                                                () => _downloadImage(image),
                                            tooltip: 'تنزيل الصورة',
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            onPressed:
                                                () => _deleteImage(image),
                                            tooltip: 'حذف',
                                          ),
                                        ],
                                      ),
                                      onTap: () => _showImageDialog(image),
                                    ),
                                  );
                                },
                              ),
                    ),
          ),
        ],
      ),
    );
  }
}
