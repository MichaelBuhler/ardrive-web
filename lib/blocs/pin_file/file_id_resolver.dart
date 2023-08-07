part of 'pin_file_bloc.dart';

class NetworkFileIdResolver implements FileIdResolver {
  // TODO: add a debouncer and a completer

  final ArweaveService arweave;
  final ConfigService configService;
  final Client httpClient;

  const NetworkFileIdResolver({
    required this.arweave,
    required this.httpClient,
    required this.configService,
  });

  @override
  Future<ResolveIdResult> requestForFileId(FileID fileId) async {
    FileEntity? fileEntity;
    try {
      fileEntity = await arweave.getLatestFileEntityWithId(fileId);
    } catch (_) {
      throw FileIdResolverException(
        id: fileId,
        cancelled: false,
        networkError: true,
        isArFsEntityValid: false,
        isArFsEntityPublic: false,
        doesDataTransactionExist: false,
      );
    }

    if (fileEntity == null) {
      // It either doesn't exist, is invalid, or private.

      logger.d('Failed to get file entity for $fileId');

      throw FileIdResolverException(
        id: fileId,
        cancelled: false,
        networkError: false,
        isArFsEntityValid: false,
        isArFsEntityPublic: false,
        doesDataTransactionExist: false,
      );
    }

    final _OwnerAndPrivacy ownerAndPrivacyOfData =
        await _getOwnerAndPrivacyOfDataTransaction(fileEntity.dataTxId!);

    final ResolveIdResult fileInfo = ResolveIdResult(
      privacy: ownerAndPrivacyOfData.privacy,
      maybeName: fileEntity.name,
      dataContentType: fileEntity.dataContentType!,
      maybeLastUpdated: fileEntity.lastModifiedDate,
      maybeLastModified: fileEntity.lastModifiedDate,
      dateCreated: fileEntity.lastModifiedDate!,
      size: fileEntity.size!,
      dataTxId: fileEntity.dataTxId!,
      pinnedDataOwnerAddress: ownerAndPrivacyOfData.ownerAddress,
    );

    return fileInfo;
  }

  @override
  Future<ResolveIdResult> requestForTransactionId(TxID dataTxId) async {
    final uri = Uri.parse(
      '${configService.config.defaultArweaveGatewayUrl}/$dataTxId',
    );
    final response = await httpClient.head(uri);

    final Map headers = response.headers;
    final String? contentTypeHeader = headers['content-type'];
    final int? contentLengthHeader =
        int.tryParse(headers['content-length'] ?? '');

    final isSucessStatusCode = response.statusCode == 200;
    final hasContentLengthHeader = contentLengthHeader != null;
    final hasContentTypeHeader = contentTypeHeader != null;

    if (!isSucessStatusCode) {
      logger.d('Failed to get data transaction details for $dataTxId'
          ' - isSucessStatusCode: $isSucessStatusCode,');

      throw FileIdResolverException(
        id: dataTxId,
        cancelled: false,
        networkError: false,
        isArFsEntityValid: false,
        isArFsEntityPublic: false,
        doesDataTransactionExist: false,
      );
    } else if (!hasContentLengthHeader || !hasContentTypeHeader) {
      logger.d(
        'Failed to get data transaction details for $dataTxId'
        ' hasSizeHeader: $hasContentLengthHeader,'
        ' hasContentTypeHeader: $hasContentTypeHeader',
      );

      throw FileIdResolverException(
        id: dataTxId,
        cancelled: false,
        networkError: false,
        isArFsEntityValid: false,
        isArFsEntityPublic: true,
        doesDataTransactionExist: true,
      );
    }

    final _OwnerAndPrivacy ownerAndPrivacyOfData =
        await _getOwnerAndPrivacyOfDataTransaction(dataTxId);

    final ResolveIdResult fileInfo = ResolveIdResult(
      privacy: ownerAndPrivacyOfData.privacy,
      maybeName: null,
      dataContentType: contentTypeHeader,
      maybeLastUpdated: null,
      maybeLastModified: null,
      dateCreated: DateTime.now(),
      size: contentLengthHeader,
      dataTxId: dataTxId,
      pinnedDataOwnerAddress: ownerAndPrivacyOfData.ownerAddress,
    );

    return fileInfo;
  }

  Future<_OwnerAndPrivacy> _getOwnerAndPrivacyOfDataTransaction(
    TxID dataTxId,
  ) async {
    final transactionDetails = await arweave.getTransactionDetails(dataTxId);

    if (transactionDetails == null) {
      throw FileIdResolverException(
        id: dataTxId,
        cancelled: false,
        networkError: false,
        isArFsEntityValid: false,
        isArFsEntityPublic: false,
        doesDataTransactionExist: false,
      );
    }

    final tags = transactionDetails.tags;
    final cipherIvTag = tags.firstWhereOrNull(
      (tag) => tag.name == 'Cipher-Iv' && tag.value.isNotEmpty,
    );

    return _OwnerAndPrivacy(
      ownerAddress: transactionDetails.owner.address,
      privacy: cipherIvTag == null ? DrivePrivacy.public : DrivePrivacy.private,
    );
  }
}

abstract class FileIdResolver {
  Future<ResolveIdResult> requestForTransactionId(TxID id);
  Future<ResolveIdResult> requestForFileId(FileID id);
}

class FileIdResolverException implements Exception {
  final String id;
  final bool cancelled;
  final bool networkError;
  final bool isArFsEntityValid;
  final bool isArFsEntityPublic;
  final bool doesDataTransactionExist;

  const FileIdResolverException({
    required this.id,
    required this.cancelled,
    required this.networkError,
    required this.isArFsEntityValid,
    required this.isArFsEntityPublic,
    required this.doesDataTransactionExist,
  });
}

class _OwnerAndPrivacy {
  final String ownerAddress;
  final DrivePrivacy privacy;

  const _OwnerAndPrivacy({
    required this.ownerAddress,
    required this.privacy,
  });
}
