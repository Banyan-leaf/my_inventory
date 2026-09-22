/// 模块：attachment / domain / ports
/// 职责：附件仓储契约，仅本模块内部使用。
library;

import '../entities/attachment.dart';

abstract class AttachmentRepo {
  Future<Attachment?> findById(int id);
  Future<List<Attachment>> findByItem(int itemId);
  Future<int> insert(Attachment attachment);
  Future<void> delete(int id);
  Future<void> deleteByItem(int itemId);
}