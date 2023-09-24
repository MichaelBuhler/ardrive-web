import 'package:arweave/arweave.dart';

abstract class UploadMetadata {}

class ARFSDriveUploadMetadata extends ARFSUploadMetadata {
  ARFSDriveUploadMetadata({
    required super.entityMetadataTags,
    required super.name,
    required super.id,
    required super.isPrivate,
    required super.dataItemTags,
    required super.bundleTags,
  });

  // TODO: implement toJson
  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }
}

class ARFSFolderUploadMetatadata extends ARFSUploadMetadata {
  final String driveId;
  final String? parentFolderId;

  ARFSFolderUploadMetatadata({
    required this.driveId,
    this.parentFolderId,
    required super.entityMetadataTags,
    required super.name,
    required super.id,
    required super.isPrivate,
    required super.dataItemTags,
    required super.bundleTags,
  });

  // TODO: implement toJson
  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }
}

class ARFSFileUploadMetadata extends ARFSUploadMetadata {
  final int size;
  final DateTime lastModifiedDate;
  final String dataContentType;
  final String driveId;
  final String parentFolderId;

  ARFSFileUploadMetadata({
    required this.size,
    required this.lastModifiedDate,
    required this.dataContentType,
    required this.driveId,
    required this.parentFolderId,
    required super.entityMetadataTags,
    required super.name,
    required super.id,
    required super.isPrivate,
    required super.dataItemTags,
    required super.bundleTags,
  });

  String? _dataTxId;

  set setDataTxId(String dataTxId) => _dataTxId = dataTxId;

  String? get dataTxId => _dataTxId;

  // without dataTxId
  // TODO: validate dataTxId
  @override
  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
        'lastModifiedDate': lastModifiedDate.millisecondsSinceEpoch,
        'dataContentType': dataContentType,
        'dataTxId': dataTxId,
      };
}

abstract class ARFSUploadMetadata extends UploadMetadata {
  final String id;
  final String name;
  final List<Tag> entityMetadataTags;
  final List<Tag> dataItemTags;
  final List<Tag> bundleTags;
  final bool isPrivate;
  String? _metadataTxId;

  ARFSUploadMetadata({
    required this.name,
    required this.entityMetadataTags,
    required this.dataItemTags,
    required this.bundleTags,
    required this.id,
    required this.isPrivate,
  });

  set setMetadataTxId(String metadataTxId) => _metadataTxId = metadataTxId;
  String? get metadataTxId => _metadataTxId;

  Map<String, dynamic> toJson();

  @override
  String toString() => toJson().toString();
}
