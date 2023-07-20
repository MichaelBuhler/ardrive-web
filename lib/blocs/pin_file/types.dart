part of 'pin_file_bloc.dart';

enum NameValidationResult {
  required,
  invalid,
  valid,
}

enum IdValidationResult {
  required,
  invalid,
  validFileId,
  validTransactionId,
}

class FileInfo {
  final bool isPrivate; // TODO: use an enum
  final String? maybeName;
  final String dataContentType; // TODO: use an enum
  final DateTime? maybeLastUpdated;
  final DateTime? maybeLastModified;
  final DateTime dateCreated;
  final int size;
  final String dataTxId;

  const FileInfo({
    required this.isPrivate,
    this.maybeName,
    required this.dataContentType,
    this.maybeLastUpdated,
    this.maybeLastModified,
    required this.dateCreated,
    required this.size,
    required this.dataTxId,
  });
}
