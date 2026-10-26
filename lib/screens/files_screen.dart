import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:save_files_des/database/database_helper.dart';
import 'package:save_files_des/models/file_model.dart';
import 'package:save_files_des/models/category_model.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final _searchController = TextEditingController();
  final _categoryNameController = TextEditingController();
  List<FileModel> _files = [];
  List<FileModel> _filteredFiles = [];
  List<CategoryModel> _categories = [];
  int? _selectedCategoryId;
  bool _isLoading = false;
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
        'files',
      );
      final filesData = await DatabaseHelper.instance.getAllFiles(
        categoryId: _selectedCategoryId,
      );

      setState(() {
        _categories =
            categoriesData.map((map) => CategoryModel.fromMap(map)).toList();
        _files = filesData.map((map) => FileModel.fromMap(map)).toList();
        _filteredFiles = _files;
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
    _filterFiles();
  }

  void _filterFiles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFiles = _files;
      } else {
        _filteredFiles =
            _files
                .where((file) => file.name.toLowerCase().contains(query))
                .toList();
      }
    });
  }

  Future<void> _pickFile() async {
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
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final file = File(filePath);
        final fileSize = await file.length();
        final fileExtension = path.extension(fileName).toLowerCase();

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

        final filesDir = Directory(path.join(storagePath, 'files'));
        if (!await filesDir.exists()) {
          await filesDir.create(recursive: true);
        }

        final savedPath = path.join(filesDir.path, fileName);
        await file.copy(savedPath);

        await DatabaseHelper.instance.insertFile(
          fileName,
          savedPath,
          fileExtension,
          fileSize,
          categoryId: categoryId,
        );

        _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حفظ الملف: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الملف: $e'),
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
          'files',
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

  Future<void> _openFile(FileModel file) async {
    try {
      final fileObj = File(file.path);
      if (await fileObj.exists()) {
        // فتح الملف باستخدام Process مباشرة
        if (Platform.isWindows) {
          // على Windows، استخدم start مع المسار
          await Process.run('cmd', [
            '/c',
            'start',
            '',
            file.path,
          ], runInShell: false);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [file.path]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [file.path]);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم فتح الملف: ${file.name}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الملف غير موجود'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح الملف: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(FileModel file) async {
    try {
      final fileObj = File(file.path);
      if (!await fileObj.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الملف غير موجود'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // اختيار مكان التنزيل
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مكان حفظ الملف',
      );

      if (selectedDirectory != null) {
        final destinationPath = path.join(selectedDirectory, file.name);

        // نسخ الملف إلى المكان المختار
        await fileObj.copy(destinationPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تنزيل الملف إلى: $selectedDirectory'),
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
            content: Text('خطأ في تنزيل الملف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(FileModel file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل أنت متأكد من حذف الملف "${file.name}"؟'),
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
        final fileObj = File(file.path);
        if (await fileObj.exists()) {
          await fileObj.delete();
        }

        if (file.id != null) {
          await DatabaseHelper.instance.deleteFile(file.id!);
        }

        _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الملف بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حذف الملف: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getCategoryColor(CategoryModel? category) {
    if (category?.color == null) return Colors.grey;
    try {
      return Color(int.parse(category!.color!.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  String _getFileIcon(String type) {
    if (type == '.doc' || type == '.docx') return '📄';
    if (type == '.xls' || type == '.xlsx') return '📊';
    if (type == '.pdf') return '📕';
    if (type == '.txt') return '📝';
    if (type == '.jpg' || type == '.jpeg' || type == '.png') return '🖼️';
    return '📁';
  }

  String _formatFileSize(int? size) {
    if (size == null) return 'غير معروف';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryNameController.dispose();
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: ' بحث عن ملف...',
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
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
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
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('إضافة ملف'),
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
          // قائمة الملفات
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredFiles.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'لا توجد ملفات'
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
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredFiles.length,
                        itemBuilder: (context, index) {
                          final file = _filteredFiles[index];
                          final category =
                              _categories.isNotEmpty
                                  ? _categories.firstWhere(
                                    (c) => c.id == file.categoryId,
                                    orElse:
                                        () => CategoryModel(
                                          id: null,
                                          name: 'بلا قسم',
                                          type: 'files',
                                          color: '#9E9E9E',
                                          createdAt:
                                              DateTime.now().toIso8601String(),
                                        ),
                                  )
                                  : CategoryModel(
                                    id: null,
                                    name: 'بلا قسم',
                                    type: 'files',
                                    color: '#9E9E9E',
                                    createdAt: DateTime.now().toIso8601String(),
                                  );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(
                                    category,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    _getFileIcon(file.type),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              title: Text(
                                file.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.category,
                                          size: 14,
                                          color: _getCategoryColor(category),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          category.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _getCategoryColor(category),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.insert_drive_file,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          file.type,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
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
                                          _formatFileSize(file.size),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateTime.parse(file.createdAt)
                                              .toString()
                                              .split('.')[0]
                                              .split(' ')[0],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.download,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _downloadFile(file),
                                    tooltip: 'تنزيل الملف',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.open_in_new,
                                      color: Colors.green,
                                    ),
                                    onPressed: () => _openFile(file),
                                    tooltip: 'فتح الملف',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteFile(file),
                                    tooltip: 'حذف',
                                  ),
                                ],
                              ),
                              onTap: () => _openFile(file),
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
