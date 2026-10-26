import 'dart:io';
import 'package:flutter/material.dart';
import 'package:save_files_des/screens/files_screen.dart';
import 'package:save_files_des/screens/images_screen.dart';
import 'package:save_files_des/screens/login_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:save_files_des/database/database_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [const FilesScreen(), const ImagesScreen()];

  Future<void> _createBackup(BuildContext context) async {
    // إغلاق نافذة الإعدادات أولاً
    Navigator.pop(context);

    // متغير لحفظ سياق النافذة
    BuildContext? dialogContext;
    bool isDialogOpen = false;

    // عرض نافذة التقدم
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        isDialogOpen = true;
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'جاري إنشاء النسخة الاحتياطية...',
                      style: GoogleFonts.cairo(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'يرجى الانتظار، قد تستغرق العملية بعض الوقت',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final storagePath = prefs.getString('storage_path');

      if (storagePath == null || storagePath.isEmpty) {
        if (context.mounted) {
          if (isDialogOpen && dialogContext != null) {
            try {
              Navigator.of(dialogContext!, rootNavigator: true).pop();
              isDialogOpen = false;
            } catch (e) {
              // تجاهل الأخطاء
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى اختيار مسار الحفظ أولاً'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // اختيار مكان حفظ النسخة الاحتياطية
      String? backupDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
      );

      if (backupDirectory == null) {
        if (context.mounted) {
          if (isDialogOpen && dialogContext != null) {
            try {
              Navigator.of(dialogContext!, rootNavigator: true).pop();
              isDialogOpen = false;
            } catch (e) {
              // تجاهل الأخطاء
            }
          }
        }
        return;
      }

      // إنشاء ملف zip
      final archive = Archive();
      final timestamp =
          DateTime.now().toString().replaceAll(':', '-').split('.')[0];
      final backupFileName = 'backup_$timestamp.zip';
      final backupPath = path.join(backupDirectory, backupFileName);

      int filesCount = 0;
      int imagesCount = 0;

      // إضافة الملفات
      final filesDir = Directory(path.join(storagePath, 'files'));
      if (await filesDir.exists()) {
        await for (var entity in filesDir.list(recursive: true)) {
          if (entity is File) {
            try {
              final fileData = await entity.readAsBytes();
              final relativePath = path.relative(
                entity.path,
                from: storagePath,
              );
              archive.addFile(
                ArchiveFile(relativePath, fileData.length, fileData),
              );
              filesCount++;
            } catch (e) {
              // تخطي الملفات التي لا يمكن قراءتها
              continue;
            }
          }
        }
      }

      // إضافة الصور
      final imagesDir = Directory(path.join(storagePath, 'images'));
      if (await imagesDir.exists()) {
        await for (var entity in imagesDir.list(recursive: true)) {
          if (entity is File) {
            try {
              final fileData = await entity.readAsBytes();
              final relativePath = path.relative(
                entity.path,
                from: storagePath,
              );
              archive.addFile(
                ArchiveFile(relativePath, fileData.length, fileData),
              );
              imagesCount++;
            } catch (e) {
              // تخطي الملفات التي لا يمكن قراءتها
              continue;
            }
          }
        }
      }

      // إضافة قاعدة البيانات
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(appDir.path, 'database', 'files_database.db');
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final dbData = await dbFile.readAsBytes();
        archive.addFile(
          ArchiveFile('database/files_database.db', dbData.length, dbData),
        );
      }

      // حفظ ملف zip (بدون ضغط لتسريع العملية)
      final zipEncoder = ZipEncoder();
      // استخدام Store method (بدون ضغط) لتسريع العملية
      final zipData = zipEncoder.encode(archive);
      if (zipData != null) {
        final backupFile = File(backupPath);
        await backupFile.writeAsBytes(zipData);
      }

      // حساب حجم الملف
      final backupFile = File(backupPath);
      final fileSize = await backupFile.length();
      String fileSizeText;
      if (fileSize < 1024) {
        fileSizeText = '$fileSize B';
      } else if (fileSize < 1024 * 1024) {
        fileSizeText = '${(fileSize / 1024).toStringAsFixed(2)} KB';
      } else {
        fileSizeText = '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
      }

      if (context.mounted) {
        // إغلاق نافذة التقدم أولاً
        if (isDialogOpen && dialogContext != null) {
          try {
            Navigator.of(dialogContext!, rootNavigator: true).pop();
            isDialogOpen = false;
          } catch (e) {
            // تجاهل الأخطاء
          }
        }

        // عرض نافذة النجاح مباشرة بعد إغلاق نافذة التقدم
        if (context.mounted) {
          // عرض نافذة النجاح
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text(
                    'تم إنشاء النسخة الاحتياطية',
                    style: GoogleFonts.cairo(),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اسم الملف:',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        backupFileName,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'المسار:',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        backupDirectory,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.storage,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'الحجم: $fileSizeText',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.insert_drive_file,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'الملفات: $filesCount',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.image,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'الصور: $imagesCount',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ملاحظة: الملف المضغوط يحتوي على جميع الملفات والصور وقاعدة البيانات. استخدم برنامج فك الضغط (مثل WinRAR أو 7-Zip) لاستخراج المحتويات.',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('حسناً', style: GoogleFonts.cairo()),
                    ),
                  ],
                ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        // إغلاق نافذة التقدم في حالة الخطأ
        if (isDialogOpen && dialogContext != null) {
          try {
            Navigator.of(dialogContext!, rootNavigator: true).pop();
            isDialogOpen = false;
          } catch (e) {
            // تجاهل الأخطاء
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في إنشاء النسخة الاحتياطية: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteAllFiles(BuildContext context) async {
    // إغلاق نافذة الإعدادات أولاً
    Navigator.pop(context);

    // تأكيد الحذف
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تأكيد الحذف', style: GoogleFonts.cairo()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هل أنت متأكد من حذف جميع الملفات والصور؟',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تحذير: هذه العملية لا يمكن التراجع عنها! سيتم حذف جميع الملفات والصور من قاعدة البيانات والملفات الفعلية.',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text('حذف الكل', style: GoogleFonts.cairo()),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    // عرض نافذة التقدم
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'جاري حذف جميع الملفات...',
                      style: GoogleFonts.cairo(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final storagePath = prefs.getString('storage_path');

      // حذف جميع السجلات من قاعدة البيانات أولاً (أسرع)
      await DatabaseHelper.instance.deleteAllFiles();
      await DatabaseHelper.instance.deleteAllImages();

      // حذف الملفات الفعلية (حذف المجلدات بالكامل أسرع من حذف كل ملف)
      if (storagePath != null && storagePath.isNotEmpty) {
        final filesDir = Directory(path.join(storagePath, 'files'));
        if (await filesDir.exists()) {
          try {
            await filesDir.delete(recursive: true);
            // إعادة إنشاء المجلد الفارغ
            await filesDir.create(recursive: true);
          } catch (e) {
            // إذا فشل حذف المجلد، حاول حذف الملفات واحداً تلو الآخر
            try {
              await for (var entity in filesDir.list(recursive: true)) {
                if (entity is File) {
                  try {
                    await entity.delete();
                  } catch (e) {
                    continue;
                  }
                }
              }
            } catch (e) {
              // تجاهل الأخطاء
            }
          }
        }

        final imagesDir = Directory(path.join(storagePath, 'images'));
        if (await imagesDir.exists()) {
          try {
            await imagesDir.delete(recursive: true);
            // إعادة إنشاء المجلد الفارغ
            await imagesDir.create(recursive: true);
          } catch (e) {
            // إذا فشل حذف المجلد، حاول حذف الملفات واحداً تلو الآخر
            try {
              await for (var entity in imagesDir.list(recursive: true)) {
                if (entity is File) {
                  try {
                    await entity.delete();
                  } catch (e) {
                    continue;
                  }
                }
              }
            } catch (e) {
              // تجاهل الأخطاء
            }
          }
        }
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حذف جميع الملفات والصور بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حذف الملفات: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _changeUserCredentials(BuildContext context) async {
    // إغلاق نافذة الإعدادات أولاً
    Navigator.pop(context);

    final currentPasswordController = TextEditingController();
    final newUsernameController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    // الحصول على بيانات المستخدم الحالي
    final currentUser = await DatabaseHelper.instance.getCurrentUser();
    if (currentUser != null) {
      newUsernameController.text = currentUser['username'] ?? '';
    }

    final formKey = GlobalKey<FormState>();

    if (context.mounted) {
      await showDialog(
        context: context,
        builder:
            (context) => StatefulBuilder(
              builder:
                  (context, setDialogState) => AlertDialog(
                    title: Text(
                      'تغيير بيانات المستخدم',
                      style: GoogleFonts.cairo(),
                    ),
                    content: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'كلمة المرور الحالية:',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: currentPasswordController,
                              obscureText: obscureCurrentPassword,
                              decoration: InputDecoration(
                                hintText: 'أدخل كلمة المرور الحالية',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureCurrentPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      obscureCurrentPassword =
                                          !obscureCurrentPassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إدخال كلمة المرور الحالية';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'اسم المستخدم الجديد:',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: newUsernameController,
                              decoration: InputDecoration(
                                hintText: 'أدخل اسم المستخدم الجديد',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إدخال اسم المستخدم';
                                }
                                if (value.length < 3) {
                                  return 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'كلمة المرور الجديدة:',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: newPasswordController,
                              obscureText: obscureNewPassword,
                              decoration: InputDecoration(
                                hintText: 'أدخل كلمة المرور الجديدة',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureNewPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      obscureNewPassword = !obscureNewPassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إدخال كلمة المرور الجديدة';
                                }
                                if (value.length < 6) {
                                  return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'تأكيد كلمة المرور:',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: confirmPasswordController,
                              obscureText: obscureConfirmPassword,
                              decoration: InputDecoration(
                                hintText: 'أعد إدخال كلمة المرور الجديدة',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureConfirmPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      obscureConfirmPassword =
                                          !obscureConfirmPassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى تأكيد كلمة المرور';
                                }
                                if (value != newPasswordController.text) {
                                  return 'كلمة المرور غير متطابقة';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'ملاحظة: بعد تغيير بيانات المستخدم، ستحتاج إلى تسجيل الدخول مرة أخرى باستخدام البيانات الجديدة.',
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          currentPasswordController.dispose();
                          newUsernameController.dispose();
                          newPasswordController.dispose();
                          confirmPasswordController.dispose();
                          Navigator.pop(context);
                        },
                        child: Text('إلغاء', style: GoogleFonts.cairo()),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context);

                            // عرض نافذة التحميل
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder:
                                  (ctx) => Center(
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const CircularProgressIndicator(),
                                            const SizedBox(height: 16),
                                            Text(
                                              'جاري تحديث بيانات المستخدم...',
                                              style: GoogleFonts.cairo(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                            );

                            try {
                              final success = await DatabaseHelper.instance
                                  .updateUser(
                                    currentPasswordController.text.trim(),
                                    newUsernameController.text.trim(),
                                    newPasswordController.text.trim(),
                                  );

                              if (context.mounted) {
                                Navigator.pop(context); // إغلاق نافذة التحميل

                                if (success) {
                                  // إغلاق النوافذ وإعادة توجيه إلى شاشة تسجيل الدخول
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تم تحديث بيانات المستخدم بنجاح. يرجى تسجيل الدخول مرة أخرى.',
                                          style: GoogleFonts.cairo(),
                                        ),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'فشل التحديث. تأكد من كلمة المرور الحالية أو أن اسم المستخدم الجديد غير مستخدم.',
                                        style: GoogleFonts.cairo(),
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }

                              currentPasswordController.dispose();
                              newUsernameController.dispose();
                              newPasswordController.dispose();
                              confirmPasswordController.dispose();
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.pop(context); // إغلاق نافذة التحميل
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'حدث خطأ: $e',
                                      style: GoogleFonts.cairo(),
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('حفظ', style: GoogleFonts.cairo()),
                      ),
                    ],
                  ),
            ),
      );
    }
  }

  void _showSettings(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final currentPath = prefs.getString('storage_path') ?? 'غير محدد';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('الإعدادات', style: GoogleFonts.cairo()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المسار الحالي:',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currentPath,
                    style: GoogleFonts.cairo(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      String? selectedDirectory = await FilePicker.platform
                          .getDirectoryPath(
                            dialogTitle: 'اختر مسار جديد لحفظ الملفات',
                          );
                      if (selectedDirectory != null) {
                        await prefs.setString(
                          'storage_path',
                          selectedDirectory,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تم تحديث مسار الحفظ: $selectedDirectory',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.folder, color: Colors.white),
                    label: const Text('تغيير مسار الحفظ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _changeUserCredentials(context),
                    icon: const Icon(Icons.person, color: Colors.white),
                    label: const Text('تغيير بيانات المستخدم'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _createBackup(context),
                    icon: const Icon(Icons.backup, color: Colors.white),
                    label: const Text('إنشاء نسخة احتياطية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteAllFiles(context),
                    icon: const Icon(Icons.delete_forever, color: Colors.white),
                    label: const Text('حذف جميع الملفات'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              _currentIndex == 0 ? Icons.folder : Icons.image,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              _currentIndex == 0 ? 'إدارة الملفات' : 'إدارة الصور',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات',
            onPressed: () => _showSettings(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _screens[_currentIndex]),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Center(
              child: Text(
                'By ENG/Hedra Naguib',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: Colors.green.shade700,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 14,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.folder),
              activeIcon: Icon(Icons.folder),
              label: 'الملفات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.image),
              activeIcon: Icon(Icons.image),
              label: 'الصور',
            ),
          ],
        ),
      ),
    );
  }
}
