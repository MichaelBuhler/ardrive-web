part of 'multiple_download_bloc.dart';

abstract class MultipleDownloadEvent extends Equatable {
  const MultipleDownloadEvent();

  @override
  List<Object> get props => [];
}

class StartDownload extends MultipleDownloadEvent {
  final List<ARFSFileEntity> items;
  final String? folderName;

  const StartDownload(this.items, {this.folderName});

  @override
  List<Object> get props => [items];
}

class ResumeDownload extends MultipleDownloadEvent {
  const ResumeDownload();
}

class SkipFileAndResumeDownload extends MultipleDownloadEvent {
  const SkipFileAndResumeDownload();
}

class CancelDownload extends MultipleDownloadEvent {
  const CancelDownload();
}
