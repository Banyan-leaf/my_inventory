/// 模块：attachment / domain / entities
/// 职责：附件实体，对应 attachment 表一行。
/// 依赖：无。
/// 约束：不可变；不 import dart:io，文件字节由 Port 层负责。
library;

/// 附件实体。
///
/// filePath 只存文件名，物理路径由 AttachmentStorage 决定。
class Attachment {
  final int? id;
  final int itemId;

  /// 关联事件 id。null 表示直接挂在物品上。
  final int? eventId;

  /// 文件名。不含目录。
  final String filePath;

  final String? mimeType;
  final int? fileSize;
  final DateTime? createdAt;

  const Attachment({
    this.id,
    required this.itemId,
    this.eventId,
    required this.filePath,
    this.mimeType,
    this.fileSize,
    this.createdAt,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'item_id': itemId,
        'event_id': eventId,
        'file_path': filePath,
        'mime_type': mimeType,
        'file_size': fileSize,
      };

  factory Attachment.fromMap(Map<String, Object?> map) => Attachment(
        id: map['id'] as int?,
        itemId: map['item_id'] as int,
        eventId: map['event_id'] as int?,
        filePath: map['file_path'] as String,
        mimeType: map['mime_type'] as String?,
        fileSize: map['file_size'] as int?,
        createdAt: map['created_at'] == null
            ? null
            : DateTime.parse(map['created_at'] as String),
      );

  @override
  String toString() =>
      'Attachment(id: $id, itemId: $itemId, filePath: $filePath)';
}