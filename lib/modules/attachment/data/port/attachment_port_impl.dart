/// 模块：attachment / data / port
/// 职责：AttachmentPort 的实现。编排 Repo（元数据）与 Storage（文件）。
/// 依赖：同模块 domain、data/dao、data/storage。
/// 约束：
///   1. 不 import 其他模块的任何文件。
///   2. 文件写入失败时不写 DB；DB 写入失败时删文件回滚。
library;

import 'dart:typed_data';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/ports/attachment_port.dart';
import '../../domain/ports/attachment_repo.dart';
import '../storage/attachment_storage.dart';

/// AttachmentPort 默认实现。
class AttachmentPortImpl implements AttachmentPort {
  final AttachmentRepo _repo;
  final AttachmentStorage _storage;

  AttachmentPortImpl(this._repo, this._storage);

  @override
  Future<int> attach({
    required int itemId,
    required Uint8List bytes,
    String? mimeType,
    String? fileExtension,
  }) async {
    if (itemId <= 0) {
      throw const ValidationException('itemId 必须有效');
    }
    if (bytes.isEmpty) {
      throw const ValidationException('文件内容为空');
    }

    final ext = fileExtension ?? _guessExtension(mimeType) ?? 'bin';
    final filename = await _storage.write(bytes, ext);

    try {
      final id = await _repo.insert(Attachment(
        itemId: itemId,
        filePath: filename,
        mimeType: mimeType,
        fileSize: bytes.length,
      ));
      return id;
    } catch (e) {
      // DB 写失败：删掉刚写的文件，避免孤儿文件。
      await _storage.delete(filename);
      rethrow;
    }
  }

  @override
  Future<List<Attachment>> listByItem(int itemId) => _repo.findByItem(itemId);

  @override
  Future<Uint8List?> readBytes(int attachmentId) async {
    final att = await _repo.findById(attachmentId);
    if (att == null) return null;
    return _storage.read(att.filePath);
  }

  @override
  Future<void> remove(int attachmentId) async {
    final att = await _repo.findById(attachmentId);
    if (att == null) return;

    // 先删 DB 记录，再删文件。
    // 顺序原因：文件删除失败时（如被占用），DB 记录已清理，
    // 用户可重新上传；反之则留下无主记录。
    await _repo.delete(attachmentId);
    await _storage.delete(att.filePath);
  }

  @override
  Future<void> removeAllByItem(int itemId) async {
    final all = await _repo.findByItem(itemId);
    await _repo.deleteByItem(itemId);
    for (final att in all) {
      await _storage.delete(att.filePath);
    }
  }

  /// 从 MIME 推导扩展名。未识别返回 null。
  String? _guessExtension(String? mimeType) {
    if (mimeType == null) return null;
    switch (mimeType) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'application/pdf':
        return 'pdf';
      default:
        return null;
    }
  }
}