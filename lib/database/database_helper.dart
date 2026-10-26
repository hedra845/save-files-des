import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init() {
    // تهيئة sqflite_common_ffi لسطح المكتب
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('files_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = join(appDir.path, 'database');
    final dbDir = Directory(dbPath);
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    final path = join(dbPath, filePath);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // جدول الأقسام
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL,
        color TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // جدول الملفات
    await db.execute('''
      CREATE TABLE files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        type TEXT NOT NULL,
        size INTEGER,
        category_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // جدول الصور
    await db.execute('''
      CREATE TABLE images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        size INTEGER,
        category_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // جدول المستخدمين
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    // إضافة مستخدم افتراضي
    await db.insert('users', {'username': 'admin', 'password': 'admin123'});

    // إضافة أقسام افتراضية
    await db.insert('categories', {
      'name': 'عام',
      'type': 'files',
      'color': '#4CAF50',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('categories', {
      'name': 'عام',
      'type': 'images',
      'color': '#4CAF50',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // إضافة جدول الأقسام
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          type TEXT NOT NULL,
          color TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      // إضافة عمود category_id للجداول الموجودة
      try {
        await db.execute('ALTER TABLE files ADD COLUMN category_id INTEGER');
        await db.execute('ALTER TABLE images ADD COLUMN category_id INTEGER');
      } catch (e) {
        // العمود موجود بالفعل
      }

      // التأكد من وجود جدول المستخدمين
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL
          )
        ''');
      } catch (e) {
        // الجدول موجود بالفعل
      }

      // التأكد من وجود المستخدم الافتراضي
      try {
        final existingUser = await db.query(
          'users',
          where: 'username = ?',
          whereArgs: ['admin'],
        );
        if (existingUser.isEmpty) {
          await db.insert('users', {
            'username': 'admin',
            'password': 'admin123',
          });
        }
      } catch (e) {
        // خطأ في إضافة المستخدم
      }

      // إضافة أقسام افتراضية
      try {
        final existingCategories = await db.query('categories');
        if (existingCategories.isEmpty) {
          await db.insert('categories', {
            'name': 'عام',
            'type': 'files',
            'color': '#4CAF50',
            'created_at': DateTime.now().toIso8601String(),
          });
          await db.insert('categories', {
            'name': 'عام',
            'type': 'images',
            'color': '#4CAF50',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        // خطأ في إضافة الأقسام
      }
    }
  }

  // إدارة الأقسام
  Future<int> insertCategory(String name, String type, String color) async {
    final db = await database;
    return await db.insert('categories', {
      'name': name,
      'type': type,
      'color': color,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllCategories(String type) async {
    final db = await database;
    return await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'name ASC',
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // إدارة الملفات
  Future<int> insertFile(
    String name,
    String path,
    String type,
    int size, {
    int? categoryId,
  }) async {
    final db = await database;
    return await db.insert('files', {
      'name': name,
      'path': path,
      'type': type,
      'size': size,
      'category_id': categoryId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllFiles({int? categoryId}) async {
    final db = await database;
    if (categoryId != null) {
      return await db.query(
        'files',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'created_at DESC',
      );
    }
    return await db.query('files', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> searchFiles(
    String query, {
    int? categoryId,
  }) async {
    final db = await database;
    if (categoryId != null) {
      return await db.query(
        'files',
        where: 'name LIKE ? AND category_id = ?',
        whereArgs: ['%$query%', categoryId],
        orderBy: 'created_at DESC',
      );
    }
    return await db.query(
      'files',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> updateFileCategory(int fileId, int? categoryId) async {
    final db = await database;
    return await db.update(
      'files',
      {'category_id': categoryId},
      where: 'id = ?',
      whereArgs: [fileId],
    );
  }

  Future<int> deleteFile(int id) async {
    final db = await database;
    return await db.delete('files', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllFiles() async {
    final db = await database;
    return await db.delete('files');
  }

  // إدارة الصور
  Future<int> insertImage(
    String name,
    String path,
    int size, {
    int? categoryId,
  }) async {
    final db = await database;
    return await db.insert('images', {
      'name': name,
      'path': path,
      'size': size,
      'category_id': categoryId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllImages({int? categoryId}) async {
    final db = await database;
    if (categoryId != null) {
      return await db.query(
        'images',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'created_at DESC',
      );
    }
    return await db.query('images', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> searchImages(
    String query, {
    int? categoryId,
  }) async {
    final db = await database;
    if (categoryId != null) {
      return await db.query(
        'images',
        where: 'name LIKE ? AND category_id = ?',
        whereArgs: ['%$query%', categoryId],
        orderBy: 'created_at DESC',
      );
    }
    return await db.query(
      'images',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> updateImageCategory(int imageId, int? categoryId) async {
    final db = await database;
    return await db.update(
      'images',
      {'category_id': categoryId},
      where: 'id = ?',
      whereArgs: [imageId],
    );
  }

  Future<int> deleteImage(int id) async {
    final db = await database;
    return await db.delete('images', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllImages() async {
    final db = await database;
    return await db.delete('images');
  }

  // إدارة المستخدمين
  Future<Map<String, dynamic>?> getUser(
    String username,
    String password,
  ) async {
    try {
      final db = await database;

      // التأكد من وجود المستخدم الافتراضي
      final existingUser = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: ['admin'],
      );
      if (existingUser.isEmpty) {
        await db.insert('users', {'username': 'admin', 'password': 'admin123'});
      }

      final result = await db.query(
        'users',
        where: 'username = ? AND password = ?',
        whereArgs: [username, password],
      );
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      // في حالة الخطأ، إرجاع null
      return null;
    }
  }

  // الحصول على المستخدم الحالي (أول مستخدم في قاعدة البيانات)
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final db = await database;
      final result = await db.query('users', limit: 1);
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // تحديث اسم المستخدم وكلمة المرور
  Future<bool> updateUser(
    String currentPassword,
    String newUsername,
    String newPassword,
  ) async {
    try {
      final db = await database;
      
      // التحقق من كلمة المرور الحالية
      final currentUser = await db.query('users', limit: 1);
      if (currentUser.isEmpty) {
        return false;
      }
      
      final user = currentUser.first;
      if (user['password'] != currentPassword) {
        return false; // كلمة المرور الحالية غير صحيحة
      }

      // التحقق من أن اسم المستخدم الجديد غير مستخدم (إذا كان مختلفاً)
      if (newUsername != user['username']) {
        final existingUser = await db.query(
          'users',
          where: 'username = ?',
          whereArgs: [newUsername],
        );
        if (existingUser.isNotEmpty) {
          return false; // اسم المستخدم موجود بالفعل
        }
      }

      // تحديث بيانات المستخدم
      await db.update(
        'users',
        {
          'username': newUsername,
          'password': newPassword,
        },
        where: 'id = ?',
        whereArgs: [user['id']],
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
