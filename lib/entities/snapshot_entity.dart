import 'package:ardrive/services/services.dart';
import 'package:arweave/arweave.dart';
import 'package:json_annotation/json_annotation.dart';

import 'entities.dart';

part 'snapshot_entity.g.dart';

@JsonSerializable()
class SnapshotEntity extends Entity {
  @JsonKey(ignore: true)
  String? id;
  @JsonKey(ignore: true)
  String? driveId;
  @JsonKey(ignore: true)
  int? blockStart;
  @JsonKey(ignore: true)
  int? blockEnd;
  @JsonKey(ignore: true)
  int? dataStart;
  @JsonKey(ignore: true)
  int? dataEnd;

  SnapshotEntity({
    this.id,
    this.driveId,
    this.blockStart,
    this.blockEnd,
    this.dataStart,
    this.dataEnd,
  });

  static Future<SnapshotEntity> fromTransaction(
    TransactionCommonMixin transaction,
  ) async {
    try {
      return SnapshotEntity()
        ..id = transaction.getTag(EntityTag.snapshotId)
        ..driveId = transaction.getTag(EntityTag.driveId)
        ..blockStart = int.parse(transaction.getTag(EntityTag.blockStart)!)
        ..blockEnd = int.parse(transaction.getTag(EntityTag.blockEnd)!)
        ..dataStart = int.parse(transaction.getTag(EntityTag.dataStart)!)
        ..dataEnd = int.parse(transaction.getTag(EntityTag.dataEnd)!)
        ..txId = transaction.id
        ..ownerAddress = transaction.owner.address
        ..createdAt = transaction.getCommitTime();
    } catch (_) {
      throw EntityTransactionParseException(transactionId: transaction.id);
    }
  }

  @override
  void addEntityTagsToTransaction<T extends TransactionBase>(T tx) {
    assert(id != null &&
        driveId != null &&
        blockStart != null &&
        blockEnd != null &&
        dataStart != null &&
        dataEnd != null);

    tx
      ..addArFsTag()
      ..addTag(EntityTag.entityType, EntityType.snapshot)
      ..addTag(EntityTag.driveId, driveId!)
      ..addTag(EntityTag.snapshotId, id!)
      ..addTag(EntityTag.blockStart, '$blockStart')
      ..addTag(EntityTag.blockEnd, '$blockEnd')
      ..addTag(EntityTag.dataStart, '$dataStart')
      ..addTag(EntityTag.dataEnd, '$dataEnd');
  }
}