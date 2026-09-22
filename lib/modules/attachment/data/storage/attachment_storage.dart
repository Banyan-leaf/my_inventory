/// 模块：attachment / data / storage
/// 职责：附件的物理文件读写。
/// 依赖：dart:io、dart:math、path、path_provider。
/// 约束：
///   1. 只被 AttachmentPortImpl 调用，不对外暴露。
///   2. 存储根目录：{documents}/my_inventory_photos/。
///   3. 文件名格式：{毫秒时间戳}_{4位随机数}.{ext}。
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 附件文件存储。
///
/// 生命周期：由 AttachmentModule 创建，注入 AttachmentPortImpl。
/// 线程模型：无状态，方法可并发（文件系统本身串行化写）。
class AttachmentStorage {
  /// 存储子目录名。
  static const String _subDir = 'my_inventory_photos';

  /// 确保目录存在，返回目录句柄。
  Future<Directory> _ensureDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _subDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 写入字节，返回文件名（不含目录）。
  Future<String> write(Uint8List bytes, String extension) async {
    final dir = await _ensureDir();
    final filename = _generateFilename(extension);
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return filename;
  }

  /// 读取文件字节。文件不存在返回 null。
  Future<Uint8List?> read(String filename) async {
    final dir = await _ensureDir();
    final file = File(p.join(dir.path, filename));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// 删除文件。不存在时静默忽略。
  Future<void> delete(String filename) async {
    final dir = await _ensureDir();
    final file = File(p.join(dir.path, filename));
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 生成唯一文件名。
  String _generateFilename(String extension) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(9999).toString().padLeft(4, '0');
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    return '${ts}_$rand.$ext';
  }
}