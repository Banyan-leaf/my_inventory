/// 模块：attachment / domain / ports
/// 职责：attachment 模块对外契约。
/// 依赖：同模块的 entities、dart:typed_data。
/// 约束：
///   1. 只暴露 Uint8List，不暴露 File/Directory 等 dart:io 类型。
///   2. 调用方不感知文件系统，换存储实现不影响调用方。
library;

import 'dart:typed_data';

import '../entities/attachment.dart';

/// attachment 模块对外端口。
abstract class AttachmentPort {
  /// 附加一个附件到指定物品。
  ///
  /// [itemId] 必须有效（>0）。
  /// [bytes] 非空。
  /// [mimeType] 可选，会作为元数据存储。
  /// [fileExtension] 可选，不带点。为 null 时从 mimeType 推导。
  ///
  /// 返回新附件 id。
  /// 抛出 [ValidationException] 当参数非法。
  Future<int> attach({
    required int itemId,
    required Uint8List bytes,
    String? mimeType,
    String? fileExtension,
  });

  /// 查询某物品的所有附件，按创建时间升序。
  Future<List<Attachment>> listByItem(int itemId);

  /// 读取附件字节。附件不存在或文件丢失返回 null。
  Future<Uint8List?> readBytes(int attachmentId);

  /// 删除附件（DB + 文件）。不存在时静默忽略。
  Future<void> remove(int attachmentId);

  /// 删除某物品的所有附件。物品软删除时调用。
  Future<void> removeAllByItem(int itemId);
}