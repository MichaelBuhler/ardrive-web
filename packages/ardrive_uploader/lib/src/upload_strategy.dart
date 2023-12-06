import 'dart:async';

import 'package:ardrive_uploader/ardrive_uploader.dart';
import 'package:ardrive_uploader/src/data_bundler.dart';
import 'package:ardrive_uploader/src/exceptions.dart';
import 'package:ardrive_uploader/src/utils/data_bundler_utils.dart';
import 'package:arweave/arweave.dart';
import 'package:flutter/foundation.dart';

abstract class UploadFileStrategy {
  Future<void> upload({
    required List<DataItemFile> dataItems,
    required FileUploadTask task,
    required Wallet wallet,
    required UploadController controller,
    required bool Function() verifyCancel,
  });
}

abstract class UploadFolderStructureStrategy {
  Future<void> upload({
    required FolderUploadTask task,
    required Wallet wallet,
    required UploadController controller,
    required bool Function() verifyCancel,
  });
}

class UploadFileUsingDataItemFiles extends UploadFileStrategy {
  final StreamedUploadFactory _streamedUploadFactory;

  UploadFileUsingDataItemFiles({
    required StreamedUploadFactory streamedUploadFactory,
  }) : _streamedUploadFactory = streamedUploadFactory;

  @override
  Future<void> upload({
    required List<DataItemFile> dataItems,
    required FileUploadTask task,
    required Wallet wallet,
    required UploadController controller,
    required bool Function() verifyCancel,
  }) async {
    /// sends the metadata item first
    final dataItemResults = await createDataItemResultFromDataItemFiles(
      dataItems,
      wallet,
    );

    if (!task.metadataUploaded) {
      debugPrint('uploading metadata for the file');

      final metadataItem = dataItemResults[0];

      /// The upload can be canceled while the bundle is being created
      if (verifyCancel()) {
        debugPrint('Upload canceled while data item was being created');
        throw UploadCanceledException(
          'Upload canceled while metadata item was being created',
        );
      }

      final metadataStreamedUpload =
          _streamedUploadFactory.fromUploadType(task.type);

      final uploadResult = await metadataStreamedUpload.send(
          DataItemUploadItem(
            size: metadataItem.dataItemSize,
            data: metadataItem,
          ),
          wallet, (progress) {
        // we don't need to update the progress of the metadata item
      });

      debugPrint('metadata upload result: $uploadResult');

      if (!uploadResult.success) {
        throw MetadataUploadException(
          message: 'Failed to upload metadata item. DataItem won\'t be sent',
          error: uploadResult.error,
        );
      }
    }

    final dataItem = dataItemResults[1];

    await _sendDataItem(
      controller: controller,
      dataItem: dataItem,
      task: task,
      verifyCancel: verifyCancel,
      wallet: wallet,
    );
  }

  Future<void> _sendDataItem({
    required FileUploadTask task,
    required DataItemResult dataItem,
    required UploadController controller,
    required bool Function() verifyCancel,
    required Wallet wallet,
  }) async {
    /// sends the data item
    var dataItemTask = task.copyWith(
      uploadItem: DataItemUploadItem(
        size: dataItem.dataItemSize,
        data: dataItem,
      ),
    );

    controller.updateProgress(
      task: task.copyWith(
        uploadItem: DataItemUploadItem(
          size: dataItem.dataItemSize,
          data: dataItem,
        ),
      ),
    );

    /// The upload can be canceled while the bundle is being created
    if (verifyCancel()) {
      debugPrint('Upload canceled while data item was being created');
      throw UploadCanceledException(
        'Upload canceled while data data item was being created',
      );
    }

    final streamedUpload = _streamedUploadFactory.fromUploadType(task.type);

    dataItemTask = dataItemTask.copyWith(
      status: UploadStatus.inProgress,
      cancelToken: UploadTaskCancelToken(
        cancel: () => streamedUpload.cancel(dataItemTask.uploadItem!),
      ),
    );

    /// adds the cancel token to the task
    controller.updateProgress(task: dataItemTask);

    final result = await streamedUpload.send(
      dataItemTask.uploadItem!,
      wallet,
      (progress) {
        controller.updateProgress(
          task: dataItemTask.copyWith(
            progress: progress,
          ),
        );
      },
    );

    if (!result.success) {
      debugPrint('Failed to upload data item. Error: ${result.error}');
      throw DataUploadException(
        message: 'Failed to upload data item. Error: ${result.error}',
        error: result.error,
      );
    }

    final updatedTask = controller.tasks[task.id]!;

    controller.updateProgress(
      task: updatedTask.copyWith(
        status: UploadStatus.complete,
      ),
    );
  }
}

class UploadFileUsingBundleStrategy extends UploadFileStrategy {
  final DataBundler _dataBundler;
  final StreamedUploadFactory _streamedUploadFactory;

  UploadFileUsingBundleStrategy({
    required DataBundler dataBundler,
    required StreamedUploadFactory streamedUploadFactory,
  })  : _dataBundler = dataBundler,
        _streamedUploadFactory = streamedUploadFactory;

  @override
  Future<void> upload({
    required List<DataItemFile> dataItems,
    required FileUploadTask task,
    required Wallet wallet,
    required UploadController controller,
    required bool Function() verifyCancel,
  }) async {
    final bundle = await _dataBundler.createDataBundle(
      file: task.file,
      metadata: task.metadata,
      wallet: wallet,
      driveKey: task.encryptionKey,
      onStartBundleCreation: () {
        controller.updateProgress(
          task: task.copyWith(
            status: UploadStatus.creatingBundle,
          ),
        );
      },
      onStartMetadataCreation: () {
        controller.updateProgress(
          task: task.copyWith(
            status: UploadStatus.creatingMetadata,
          ),
        );
      },
    );

    if (bundle is TransactionResult) {
      controller.updateProgress(
        task: task.copyWith(
          uploadItem: TransactionUploadItem(
            size: bundle.dataSize,
            data: bundle,
          ),
        ),
      );
    } else if (bundle is DataItemResult) {
      task = task.copyWith(
        uploadItem: DataItemUploadItem(
          size: bundle.dataItemSize,
          data: bundle,
        ),
      );

      controller.updateProgress(
        task: task,
      );
    } else {
      throw Exception('Unknown bundle type');
    }

    /// The upload can be canceled while the bundle is being created
    if (verifyCancel()) {
      debugPrint('Upload canceled while bundle was being created');
      throw UploadCanceledException('Upload canceled');
    }

    final streamedUpload = _streamedUploadFactory.fromUploadType(task.type);

    final result =
        await streamedUpload.send(task.uploadItem!, wallet, (progress) {
      controller.updateProgress(
        task: task.copyWith(
          progress: progress,
        ),
      );
    });

    if (!result.success) {
      throw BundleUploadException(
        message: 'Failed to upload bundle',
        error: result.error,
      );
    }

    controller.updateProgress(
      task: task.copyWith(
        status: UploadStatus.complete,
      ),
    );
  }
}

class UploadFolderStructureAsBundleStrategy
    extends UploadFolderStructureStrategy {
  final DataBundler _dataBundler;
  final StreamedUploadFactory _streamedUploadFactory;

  UploadFolderStructureAsBundleStrategy({
    required DataBundler dataBundler,
    required StreamedUploadFactory streamedUploadFactory,
  })  : _dataBundler = dataBundler,
        _streamedUploadFactory = streamedUploadFactory;

  @override
  Future<void> upload({
    required FolderUploadTask task,
    required Wallet wallet,
    required UploadController controller,
    required bool Function() verifyCancel,
  }) async {
    // creates the bundle for folders
    final bundle = await _dataBundler.createDataBundleForEntities(
      entities: task.folders,
      wallet: wallet,
      driveKey: task.encryptionKey,
    );

    final folderBundle = (bundle).first.dataItemResult;

    FolderUploadTask folderTask = task;

    if (folderBundle is TransactionResult) {
      folderTask = folderTask.copyWith(
        uploadItem: TransactionUploadItem(
          size: folderBundle.dataSize,
          data: folderBundle,
        ),
      );

      controller.updateProgress(task: folderTask);
    } else if (folderBundle is DataItemResult) {
      folderTask = folderTask.copyWith(
        uploadItem: DataItemUploadItem(
          size: folderBundle.dataSize,
          data: folderBundle,
        ),
      );
      controller.updateProgress(task: folderTask);
    } else {
      throw Exception('Unknown bundle type');
    }

    if (verifyCancel()) {
      debugPrint('Upload canceled after bundle creation and before upload');
      throw UploadCanceledException('Upload canceled on bundle creation');
    }

    final streamedUpload =
        _streamedUploadFactory.fromUploadType(folderTask.type);

    final result =
        await streamedUpload.send(folderTask.uploadItem!, wallet, (progress) {
      folderTask = folderTask.copyWith(
        progress: progress,
      );
      controller.updateProgress(task: folderTask);
    });

    if (!result.success) {
      throw BundleUploadException(message: 'Failed to upload bundle');
    }

    controller.updateProgress(
      task: folderTask.copyWith(
        status: UploadStatus.complete,
      ),
    );
  }
}

void _checkForCancellation(bool Function() verifyCancel) {
  if (verifyCancel()) {
    throw Exception('Upload canceled');
  }
}
