import 'dart:convert';

import 'package:ardrive_crypto/ardrive_crypto.dart';
import 'package:ardrive_io/ardrive_io.dart';
import 'package:ardrive_uploader/ardrive_uploader.dart';
import 'package:ardrive_utils/ardrive_utils.dart';
import 'package:arweave/arweave.dart';
import 'package:arweave/utils.dart';
import 'package:cryptography/cryptography.dart' hide Cipher;
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

abstract class DataBundler<T> {
  Future<DataItemResult> createDataBundle({
    required IOFile file,
    required T metadata,
    required Wallet wallet,
    SecretKey? driveKey,
    Function? onStartEncryption,
    Function? onStartBundling,
  });

  Future<TransactionResult> createBundleDataTransaction({
    required IOFile file,
    required T metadata,
    required Wallet wallet,
    SecretKey? driveKey,
    Function? onStartEncryption,
    Function? onStartBundling,
  });

  Future<List<DataResultWithContents>> createDataBundleForEntity({
    required IOEntity entity,
    required T metadata, // top level metadata
    required Wallet wallet,
    SecretKey? driveKey,
    required String driveId,
    Function(T metadata)? skipMetadata,
  });

  Future<List<DataResultWithContents>> createBundleDataTransactionForEntity({
    required IOEntity entity,
    required T metadata, // top level metadata
    required Wallet wallet,
    SecretKey? driveKey,
    required String driveId,
    Function(T metadata)? skipMetadata,
  });
}

// TODO: temporary solution to the issue with the data items
class ARFSDataBundlerStable implements DataBundler<ARFSUploadMetadata> {
  final ARFSUploadMetadataGenerator metadataGenerator;

  ARFSDataBundlerStable(this.metadataGenerator);

  @override
  Future<DataItemResult> createDataBundle({
    required IOFile file,
    required ARFSUploadMetadata metadata,
    required Wallet wallet,
    SecretKey? driveKey,
    Function? onStartEncryption,
    Function? onStartBundling,
  }) {
    return _createBundleStable(
      file: file,
      metadata: metadata,
      wallet: wallet,
      driveKey: driveKey,
      onStartBundling: onStartBundling,
      onStartEncryption: onStartEncryption,
    );
  }

  Future<DataItemResult> _createBundleStable({
    required IOFile file,
    required ARFSUploadMetadata metadata,
    required Wallet wallet,
    Function? onStartEncryption,
    Function? onStartBundling,
    SecretKey? driveKey,
  }) async {
    if (driveKey != null) {
      onStartEncryption?.call();
    } else {
      onStartBundling?.call();
    }

    // returns the encrypted or not file read stream and the cipherIv if it was encrypted
    final dataGenerator = await _dataGenerator(
      dataStream: file.openReadStream,
      fileLength: await file.length,
      metadata: metadata,
      wallet: wallet,
      driveKey: driveKey,
    );

    // print('Data item generated');

    // print('Starting to generate metadata data item');

    final metadataDataItem = await _generateMetadataDataItem(
      metadata: metadata,
      dataStream: dataGenerator.$1,
      fileLength: await file.length,
      wallet: wallet,
      driveKey: driveKey,
    );

    print('Metadata data item generated');
    print('metadata id: ${metadata.metadataTxId}');

    // print('Starting to generate file data item');

    final fileDataItem = _generateFileDataItem(
      metadata: metadata,
      dataStream: dataGenerator.$1,
      fileLength: await file.length,
      cipherIv: dataGenerator.$2,
    );

    // print('Starting to create bundled data item');

    final createBundledDataItem = createBundledDataItemTaskEither(
      dataItemFiles: [
        metadataDataItem,
        fileDataItem,
      ],
      wallet: wallet,
      tags: metadata.bundleTags.map((e) => createTag(e.name, e.value)).toList(),
    );

    final bundledDataItem = await createBundledDataItem.run();

    return bundledDataItem.match((l) {
      // TODO: handle error
      print('Error: $l');
      print(StackTrace.current);
      throw l;
    }, (bdi) async {
      // print('Bundled data item created. ID: ${bdi.id}');
      // print('Bundled data item size: ${bdi.dataItemSize} bytes');
      // print(
      //     'The creation of the bundled data item took ${stopwatch.elapsedMilliseconds} ms');
      return bdi;
    });
  }

  Future<DataItemFile> _generateMetadataDataItem({
    required ARFSUploadMetadata metadata,
    required Stream<Uint8List> Function() dataStream,
    required int fileLength,
    required Wallet wallet,
    SecretKey? driveKey,
  }) async {
    // print('Initializing metadata data item generator...');

    Stream<Uint8List> Function() metadataGenerator;

    // print('Creating DataItem...');
    final fileDataItemEither = createDataItemTaskEither(
        wallet: wallet,
        dataStream: dataStream,
        dataStreamSize: fileLength,
        tags: metadata.dataItemTags
            .map((e) => createTag(e.name, e.value))
            .toList());

    final fileDataItemResult = await fileDataItemEither.run();

    late String dataTxId;

    fileDataItemResult.match((l) {
      print('Error: $l');
      print(StackTrace.current);
    }, (fileDataItem) {
      dataTxId = fileDataItem.id;
      // print('fileDataItemResult lenght: ${fileDataItem.dataSize} bytes');
      // print('file length: $fileLength bytes');

      // print('Data item created. ID: ${fileDataItem.id}');
      // print('Data item size: ${fileDataItem.dataSize} bytes');

      metadata as ARFSFileUploadMetadata;
      metadata.setDataTxId = fileDataItem.id;
    });

    final metadataJson = metadata.toJson()
      ..putIfAbsent('dataTxId', () => dataTxId);

    final metadataBytes = utf8
        .encode(jsonEncode(metadataJson))
        .map((e) => Uint8List.fromList([e]));

    if (driveKey != null) {
      // print('DriveKey is not null. Starting metadata encryption...');

      final driveKeyData = Uint8List.fromList(await driveKey.extractBytes());

      final implMetadata = await cipherStreamEncryptImpl(Cipher.aes256ctr,
          keyData: driveKeyData);

      final encryptMetadataStreamResult =
          await implMetadata.encryptStreamGenerator(
        () => Stream.fromIterable(metadataBytes),
        metadataBytes.length,
      );

      // print('Metadata encryption complete');

      final metadataCipherIv = encryptMetadataStreamResult.nonce;

      metadataGenerator = encryptMetadataStreamResult.streamGenerator;

      metadata.entityMetadataTags
          .add(Tag(EntityTag.cipherIv, encodeBytesToBase64(metadataCipherIv)));
      metadata.entityMetadataTags.add(Tag(EntityTag.cipher, Cipher.aes256ctr));
    } else {
      // print('DriveKey is null. Skipping metadata encryption.');
      metadataGenerator = () => Stream.fromIterable(metadataBytes);
    }

    // TODO: remove this when we fix the issue with the method that returns the
    final metadataTask = createDataItemTaskEither(
      wallet: wallet,
      dataStream: () => Stream.fromIterable(metadataBytes),
      dataStreamSize: metadataBytes.length,
      tags: metadata.entityMetadataTags
          .map((e) => createTag(e.name, e.value))
          .toList(),
    ).flatMap((metadataDataItem) => TaskEither.of(metadataDataItem));

    final metadataTaskEither = await metadataTask.run();

    metadataTaskEither.match((l) {
      print('Error: $l');
      print(StackTrace.current);
      throw l;
    }, (metadataDataItem) {
      print('Metadata data item created. ID: ${metadataDataItem.id}');
      metadata.setMetadataTxId = metadataDataItem.id;
      return metadataDataItem;
    });

    // print('Metadata size: ${metadataBytes.length} bytes');

    final metadataFile = DataItemFile(
      dataSize: metadataBytes.length,
      streamGenerator: metadataGenerator,
      tags: metadata.entityMetadataTags
          .map((e) => createTag(e.name, e.value))
          .toList(),
    );

    // print(
    //     'Metadata data item generator complete. Elapsed time: ${stopwatch.elapsedMilliseconds} ms');

    return metadataFile;
  }

  @override
  Future<List<DataResultWithContents>> createDataBundleForEntity({
    required IOEntity entity,
    required ARFSUploadMetadata metadata, // top level metadata
    required Wallet wallet,
    SecretKey? driveKey,
    required String driveId,
    Function(ARFSUploadMetadata metadata)? skipMetadata,
  }) async {
    // TODO: implement createDataBundleForEntities
    // TODO: implement the creation of the data bundle for entities, onyl for folders by now.
    // Used for upload metadata

    if (entity is IOFile) {
      final fileMetadata = await metadataGenerator.generateMetadata(
        entity,
        ARFSUploadMetadataArgs(
          isPrivate: driveKey != null,
          driveId: driveId,
          parentFolderId: metadata.id,
        ),
      );

      return [
        DataResultWithContents(
          dataItemResult: await _createBundleStable(
            file: entity,
            metadata: fileMetadata,
            wallet: wallet,
            driveKey: driveKey,
          ),
          contents: [fileMetadata],
        ),
      ];
    }
    // Generates for folders and files inside the folders.

    else if (entity is IOFolder) {
      List<ARFSUploadMetadata> folderMetadatas = [];
      List<DataItemFile> folderDataItems = [];
      List<DataResultWithContents> dataItemsResult = [];

      /// Adds the Top level folder
      // TODO: REVIEW: on web it's not necessary to add the top level folder
      // if (!kIsWeb)
      if (skipMetadata != null && !skipMetadata(metadata)) {
        folderMetadatas.add(metadata);
      }

      await _iterateThroughFolderSubContent(
        folderDataItems: folderDataItems,
        foldersMetadatas: folderMetadatas,
        dataItemsResult: dataItemsResult,
        entites: await entity.listContent(),
        args: ARFSUploadMetadataArgs(
          isPrivate: driveKey != null,
          driveId: driveId,
          parentFolderId: metadata.id,
        ),
        wallet: wallet,
        driveKey: driveKey,
        topMetadata: metadata,
        skipMetadata: skipMetadata,
      );

      if (skipMetadata != null && skipMetadata(metadata)) {
        return dataItemsResult;
      }

      Stream<Uint8List> Function() metadataStreamGenerator;

      final metadataJson = metadata.toJson();

      final metadataBytes = utf8
          .encode(jsonEncode(metadataJson))
          .map((e) => Uint8List.fromList([e]));

      if (driveKey != null) {
        print('DriveKey is not null. Starting metadata encryption...');

        final driveKeyData = Uint8List.fromList(await driveKey.extractBytes());

        final implMetadata = await cipherStreamEncryptImpl(Cipher.aes256ctr,
            keyData: driveKeyData);

        final encryptMetadataStreamResult =
            await implMetadata.encryptStreamGenerator(
          () => Stream.fromIterable(metadataBytes),
          metadataBytes.length,
        );

        print('Metadata encryption complete');

        final metadataCipherIv = encryptMetadataStreamResult.nonce;

        metadataStreamGenerator = encryptMetadataStreamResult.streamGenerator;

        // TODO: REVIEW
        metadata.entityMetadataTags.add(
            Tag(EntityTag.cipherIv, encodeBytesToBase64(metadataCipherIv)));
        metadata.entityMetadataTags
            .add(Tag(EntityTag.cipher, Cipher.aes256ctr));
      } else {
        print('DriveKey is null. Skipping metadata encryption.');
        metadataStreamGenerator = () => Stream.fromIterable(metadataBytes);
      }

      final metadataFile = DataItemFile(
        dataSize: metadataBytes.length,
        streamGenerator: metadataStreamGenerator,
        tags: metadata.entityMetadataTags
            .map((e) => createTag(e.name, e.value))
            .toList(),
      );

      // TODO: Change it when update the arweave-dart package
      // Currently we need to create the data item for the metadata first
      // so we can get the tx id and add it to the metadata.
      final metadataDataTaskEither = createDataItemTaskEither(
          wallet: wallet,
          dataStream: metadataStreamGenerator,
          dataStreamSize: metadataBytes.length,
          tags: metadata.dataItemTags
              .map((e) => createTag(e.name, e.value))
              .toList());

      final metadataDataItemResult = await metadataDataTaskEither.run();

      metadataDataItemResult.match((l) {
        print('Error: $l');
        print(StackTrace.current);
        throw l;
      }, (metadataDataItem) {
        print('Metadata data item created. ID: ${metadataDataItem.id}');
        metadata.setMetadataTxId = metadataDataItem.id;
        return metadataDataItem;
      });

      /// List of folders DataItems
      folderDataItems.insert(0, metadataFile);

      for (var metadataFolder in folderDataItems) {
        print('Metadata folder size: ${metadataFolder.dataSize}');
        print('Metadata folder tags: ${metadataFolder.tags.length}');
      }

      final folderBDITask = await createBundledDataItemTaskEither(
        dataItemFiles: folderDataItems,
        wallet: wallet,
        tags:
            metadata.bundleTags.map((e) => createTag(e.name, e.value)).toList(),
      ).run();

      // folder bdi
      final folderBDIResult = await folderBDITask.match((l) {
        // TODO: handle error
        print('Error: $l');
        print(StackTrace.current);
        throw l;
      }, (bdi) async {
        print('Bundled data item created. ID: ${bdi.id}');
        print('Bundled data item size: ${bdi.dataItemSize} bytes');
        return bdi;
      });

      for (var folder in folderMetadatas) {
        print('Folder metadata: ${folder.name}');
      }

      /// All folders inside a single BDI, and the remaining files
      return [
        DataResultWithContents(
          dataItemResult: folderBDIResult,
          contents: folderMetadatas,
        ),
        ...dataItemsResult
      ];
    } else {
      throw Exception('Invalid entity type');
    }
  }

  // Recursive function to iterate through the folder subcontent and
  // create the data items for each file and folder.
  Future<void> _iterateThroughFolderSubContent({
    required List<DataItemFile> folderDataItems,
    required List<DataResultWithContents> dataItemsResult,
    required List<ARFSUploadMetadata> foldersMetadatas,
    required List<IOEntity> entites,
    required ARFSUploadMetadataArgs args,
    required Wallet wallet,
    SecretKey? driveKey,
    required ARFSUploadMetadata topMetadata,
    Function(ARFSUploadMetadata metadata)? skipMetadata,
  }) async {
    for (var entity in entites) {
      if (entity is IOFile) {
        final fileMetadata = await metadataGenerator.generateMetadata(
          entity,
          args,
        );

        if (skipMetadata != null && skipMetadata(fileMetadata)) {
          continue;
        }

        dataItemsResult.add(
          DataResultWithContents(
            dataItemResult: await _createBundleStable(
              file: entity,
              metadata: fileMetadata,
              wallet: wallet,
              // TODO: REVIEW
              driveKey: driveKey,
            ),
            contents: [fileMetadata],
          ),
        );
      } else if (entity is IOFolder) {
        final folderMetadata = await metadataGenerator.generateMetadata(
          entity,
          args,
        );

        if (skipMetadata != null && skipMetadata(folderMetadata)) {
          continue;
        }

        /// Add to the list of folders metadatas
        foldersMetadatas.add(folderMetadata);

        print('Folder metadata generated: ${entity.name}');

        folderDataItems.add(
          await _createDataItemFromFolder(
            folder: entity,
            metadata: folderMetadata,
            wallet: wallet,
            driveKey: driveKey,
          ),
        );

        final subContent = await entity.listContent();

        for (var item in subContent) {
          print(item.name);
        }

        await _iterateThroughFolderSubContent(
          folderDataItems: folderDataItems,
          dataItemsResult: dataItemsResult,
          foldersMetadatas: foldersMetadatas,
          entites: subContent,
          args: ARFSUploadMetadataArgs(
            isPrivate: args.isPrivate,
            driveId: args.driveId,
            parentFolderId: folderMetadata.id,
          ),
          wallet: wallet,
          driveKey: driveKey,
          topMetadata: topMetadata,
          skipMetadata: skipMetadata,
        );
      } else {
        throw Exception('Invalid entity type');
      }
    }
  }

  // TODO: We are duplicating the logic. Needs to refactor
  Future<void> _iterateThroughFolderSubContentForTransaction({
    required List<DataItemFile> folderDataItems,
    required List<DataResultWithContents> transactionResults,
    required List<ARFSUploadMetadata> foldersMetadatas,
    required List<IOEntity> entites,
    required ARFSUploadMetadataArgs args,
    required Wallet wallet,
    SecretKey? driveKey,
    required ARFSUploadMetadata topMetadata,
    Function(ARFSUploadMetadata metadata)? skipMetadata,
  }) async {
    for (var entity in entites) {
      if (entity is IOFile) {
        final fileMetadata = await metadataGenerator.generateMetadata(
          entity,
          args,
        );

        transactionResults.add(DataResultWithContents<TransactionResult>(
          dataItemResult: await createBundleDataTransaction(
            wallet: wallet,
            file: entity,
            metadata: fileMetadata,
            driveKey: driveKey,
          ),
          contents: [fileMetadata],
        ));
      } else if (entity is IOFolder) {
        final folderMetadata = await metadataGenerator.generateMetadata(
          entity,
          args,
        );

        // if (skipMetadata != null && skipMetadata(folderMetadata)) {
        //   continue;
        // }

        /// Add to the list of folders metadatas
        foldersMetadatas.add(folderMetadata);

        print('Folder metadata generated: ${entity.name}');

        folderDataItems.add(
          await _createDataItemFromFolder(
            folder: entity,
            metadata: folderMetadata,
            wallet: wallet,
            driveKey: driveKey,
          ),
        );

        final subContent = await entity.listContent();

        for (var item in subContent) {
          print(item.name);
        }

        await _iterateThroughFolderSubContentForTransaction(
          folderDataItems: folderDataItems,
          transactionResults: transactionResults,
          foldersMetadatas: foldersMetadatas,
          entites: subContent,
          args: ARFSUploadMetadataArgs(
            isPrivate: args.isPrivate,
            driveId: args.driveId,
            parentFolderId: folderMetadata.id,
          ),
          wallet: wallet,
          driveKey: driveKey,
          topMetadata: topMetadata,
          skipMetadata: skipMetadata,
        );
      } else {
        throw Exception('Invalid entity type');
      }
    }
  }

  Future<DataItemFile> _createDataItemFromFolder({
    required IOFolder folder,
    required ARFSUploadMetadata metadata,
    required Wallet wallet,
    SecretKey? driveKey,
  }) async {
    Stream<Uint8List> Function() metadataStreamGenerator;

    final metadataJson = metadata.toJson();

    final metadataBytes = utf8
        .encode(jsonEncode(metadataJson))
        .map((e) => Uint8List.fromList([e]));

    if (driveKey != null) {
      print('DriveKey is not null. Starting metadata encryption...');

      final driveKeyData = Uint8List.fromList(await driveKey.extractBytes());

      final implMetadata = await cipherStreamEncryptImpl(Cipher.aes256ctr,
          keyData: driveKeyData);

      final encryptMetadataStreamResult =
          await implMetadata.encryptStreamGenerator(
        () => Stream.fromIterable(metadataBytes),
        metadataBytes.length,
      );

      print('Metadata encryption complete');

      final metadataCipherIv = encryptMetadataStreamResult.nonce;

      metadataStreamGenerator = encryptMetadataStreamResult.streamGenerator;

      metadata.entityMetadataTags
          .add(Tag(EntityTag.cipherIv, encodeBytesToBase64(metadataCipherIv)));
      metadata.entityMetadataTags.add(Tag(EntityTag.cipher, Cipher.aes256ctr));
    } else {
      print('DriveKey is null. Skipping metadata encryption.');
      metadataStreamGenerator = () => Stream.fromIterable(metadataBytes);
    }

    // TODO: remove this when we fix the issue with the method that returns the
    //
    final metadataTask = createDataItemTaskEither(
      wallet: wallet,
      dataStream: () => Stream.fromIterable(metadataBytes),
      dataStreamSize: metadataBytes.length,
      tags: metadata.entityMetadataTags
          .map((e) => createTag(e.name, e.value))
          .toList(),
    ).flatMap((metadataDataItem) => TaskEither.of(metadataDataItem));

    final metadataTaskEither = await metadataTask.run();

    metadataTaskEither.match((l) {
      print('Error: $l');
      print(StackTrace.current);
      throw l;
    }, (metadataDataItem) {
      print('Metadata data item created. ID: ${metadataDataItem.id}');
      metadata.setMetadataTxId = metadataDataItem.id;
      return metadataDataItem;
    });

    print('Metadata size: ${metadataBytes.length} bytes');

    final metadataFile = DataItemFile(
      dataSize: metadataBytes.length,
      streamGenerator: metadataStreamGenerator,
      tags: metadata.entityMetadataTags
          .map((e) => createTag(e.name, e.value))
          .toList(),
    );

    return metadataFile;
  }

  Future<(Stream<Uint8List> Function() generator, Uint8List? cipherIv)>
      _dataGenerator({
    required ARFSUploadMetadata metadata,
    required Stream<Uint8List> Function() dataStream,
    required int fileLength,
    required Wallet wallet,
    SecretKey? driveKey,
  }) async {
    final stopwatch = Stopwatch()..start(); // Start timer

    print('Initializing data generator...');

    Stream<Uint8List> Function() dataGenerator;
    Uint8List? cipherIv;

    if (driveKey != null) {
      print('DriveKey is not null. Starting encryption...');

      // Derive a file key from the user's drive key and the file id.
      // We don't salt here since the file id is already random enough but
      // we can salt in the future in cases where the user might want to revoke a file key they shared.
      // TODO: We may want to have this abstracted on the ardrive_crypto package.
      final fileIdBytes = Uint8List.fromList(Uuid.parse(metadata.id));
      print('File ID bytes generated: ${fileIdBytes.length} bytes');

      final kdf = Hkdf(hmac: Hmac(Sha256()), outputLength: keyByteLength);
      print('KDF initialized');

      final fileKey = await kdf.deriveKey(
        secretKey: driveKey,
        info: fileIdBytes,
        nonce: Uint8List(1),
      );

      print('File key derived');

      final keyData = Uint8List.fromList(await fileKey.extractBytes());
      print('Key data extracted');

      final impl =
          await cipherStreamEncryptImpl(Cipher.aes256ctr, keyData: keyData);
      print('Cipher impl ready');

      final encryptStreamResult = await impl.encryptStreamGenerator(
        dataStream,
        fileLength,
      );

      print('Stream encryption complete');

      cipherIv = encryptStreamResult.nonce;
      dataGenerator = encryptStreamResult.streamGenerator;
    } else {
      print('DriveKey is null. Skipping encryption.');
      dataGenerator = dataStream;
    }

    print(
        'Data generator complete. Elapsed time: ${stopwatch.elapsedMilliseconds} ms');

    return (dataGenerator, cipherIv);
  }

  DataItemFile _generateFileDataItem({
    required ARFSUploadMetadata metadata,
    required Stream<Uint8List> Function() dataStream,
    required int fileLength,
    Uint8List? cipherIv,
  }) {
    final tags = metadata.dataItemTags;

    if (cipherIv != null) {
      // TODO: REVIEW THIS
      tags.add(Tag(EntityTag.cipher, encodeBytesToBase64(cipherIv)));
      tags.add(Tag(EntityTag.cipherIv, Cipher.aes256ctr));
    }

    final dataItemFile = DataItemFile(
      dataSize: fileLength,
      streamGenerator: dataStream,
      tags: tags.map((e) => createTag(e.name, e.value)).toList(),
    );

    return dataItemFile;
  }

  @override
  Future<TransactionResult> createBundleDataTransaction({
    required IOFile file,
    required ARFSUploadMetadata metadata,
    required Wallet wallet,
    SecretKey? driveKey,
    Function? onStartEncryption,
    Function? onStartBundling,
  }) async {
    if (driveKey != null) {
      onStartEncryption?.call();
    } else {
      onStartBundling?.call();
    }

    // returns the encrypted or not file read stream and the cipherIv if it was encrypted
    final dataGenerator = await _dataGenerator(
      dataStream: file.openReadStream,
      fileLength: await file.length,
      metadata: metadata,
      wallet: wallet,
      driveKey: driveKey,
    );

    print('Data item generated');

    print('Starting to generate metadata data item');

    final metadataDataItem = await _generateMetadataDataItem(
      metadata: metadata,
      dataStream: dataGenerator.$1,
      fileLength: await file.length,
      wallet: wallet,
      driveKey: driveKey,
    );

    print('Metadata data item generated');
    print('metadata id: ${metadata.metadataTxId}');

    print('Starting to generate file data item');

    final fileDataItem = _generateFileDataItem(
      metadata: metadata,
      dataStream: dataGenerator.$1,
      fileLength: await file.length,
      cipherIv: dataGenerator.$2,
    );

    print('Starting to create bundled data item');

    final transactionResult = await createDataBundleTransaction(
      dataItemFiles: [
        metadataDataItem,
        fileDataItem,
      ],
      wallet: wallet,
      tags: metadata.bundleTags.map((e) => createTag(e.name, e.value)).toList(),
    );

    return transactionResult;
  }

  Future<TransactionResult> createDataBundleTransaction({
    required final Wallet wallet,
    required final List<DataItemFile> dataItemFiles,
    required final List<Tag> tags,
  }) async {
    final List<DataItemResult> dataItemList = [];
    final dataItemCount = dataItemFiles.length;
    for (var i = 0; i < dataItemCount; i++) {
      final dataItem = dataItemFiles[i];
      await createDataItemTaskEither(
        wallet: wallet,
        dataStream: dataItem.streamGenerator,
        dataStreamSize: dataItem.dataSize,
        target: dataItem.target,
        anchor: dataItem.anchor,
        tags: dataItem.tags,
      ).map((dataItem) => dataItemList.add(dataItem)).run();
    }

    final dataBundleTaskEither =
        createDataBundleTaskEither(TaskEither.of(dataItemList));

    final bundledDataItemTags = [
      createTag('Bundle-Format', 'binary'),
      createTag('Bundle-Version', '2.0.0'),
      ...tags,
    ];

    final taskEither = await dataBundleTaskEither.run();
    final result = taskEither.match(
      (l) {
        throw l;
      },
      (r) async {
        int size = 0;

        await for (var chunk in r.stream()) {
          size += chunk.length;
        }

        print('Size of the bundled data item: $size bytes');

        return createTransactionTaskEither(
          wallet: wallet,
          dataStreamGenerator: r.stream,
          dataSize: size,
          tags: bundledDataItemTags,
        );
      },
    );

    return (await result).match(
      (l) {
        throw l;
      },
      (r) => r,
    ).run();
  }

  @override
  Future<List<DataResultWithContents>> createBundleDataTransactionForEntity({
    required IOEntity entity,
    required ARFSUploadMetadata metadata,
    required Wallet wallet,
    SecretKey? driveKey,
    required String driveId,
    Function(ARFSUploadMetadata metadata)? skipMetadata,
  }) async {
    // TODO: implement createDataBundleForEntities
    // TODO: implement the creation of the data bundle for entities, onyl for folders by now.
    // Used for upload metadata

    if (entity is IOFile) {
      final fileMetadata = await metadataGenerator.generateMetadata(
        entity,
        ARFSUploadMetadataArgs(
          isPrivate: driveKey != null,
          driveId: driveId,
          parentFolderId: metadata.id,
        ),
      );

      return [
        DataResultWithContents<TransactionResult>(
          dataItemResult: await createBundleDataTransaction(
            wallet: wallet,
            file: entity,
            metadata: metadata,
            driveKey: driveKey,
          ),
          contents: [fileMetadata],
        )
      ];
    }

    // Generates for folders and files inside the folders.
    else if (entity is IOFolder) {
      List<ARFSUploadMetadata> folderMetadatas = [];
      List<DataItemFile> folderDataItems = [];
      List<DataResultWithContents> dataItemsResult = [];

      /// Adds the Top level folder
      // TODO: REVIEW: on web it's not necessary to add the top level folder
      // if (!kIsWeb)
      // if (skipMetadata != null && !skipMetadata(metadata)) {
      folderMetadatas.add(metadata);
      // }

      await _iterateThroughFolderSubContentForTransaction(
        folderDataItems: folderDataItems,
        foldersMetadatas: folderMetadatas,
        transactionResults: dataItemsResult,
        entites: await entity.listContent(),
        args: ARFSUploadMetadataArgs(
          isPrivate: driveKey != null,
          driveId: driveId,
          parentFolderId: metadata.id,
        ),
        wallet: wallet,
        driveKey: driveKey,
        topMetadata: metadata,
        skipMetadata: skipMetadata,
      );

      Stream<Uint8List> Function() metadataStreamGenerator;

      final metadataJson = metadata.toJson();

      final metadataBytes = utf8
          .encode(jsonEncode(metadataJson))
          .map((e) => Uint8List.fromList([e]));

      if (driveKey != null) {
        print('DriveKey is not null. Starting metadata encryption...');

        final driveKeyData = Uint8List.fromList(await driveKey.extractBytes());

        final implMetadata = await cipherStreamEncryptImpl(Cipher.aes256ctr,
            keyData: driveKeyData);

        final encryptMetadataStreamResult =
            await implMetadata.encryptStreamGenerator(
          () => Stream.fromIterable(metadataBytes),
          metadataBytes.length,
        );

        print('Metadata encryption complete');

        final metadataCipherIv = encryptMetadataStreamResult.nonce;

        metadataStreamGenerator = encryptMetadataStreamResult.streamGenerator;

        // TODO: REVIEW
        metadata.entityMetadataTags.add(
            Tag(EntityTag.cipherIv, encodeBytesToBase64(metadataCipherIv)));
        metadata.entityMetadataTags
            .add(Tag(EntityTag.cipher, Cipher.aes256ctr));
      } else {
        print('DriveKey is null. Skipping metadata encryption.');
        metadataStreamGenerator = () => Stream.fromIterable(metadataBytes);
      }

      final metadataFile = DataItemFile(
        dataSize: metadataBytes.length,
        streamGenerator: metadataStreamGenerator,
        tags: metadata.entityMetadataTags
            .map((e) => createTag(e.name, e.value))
            .toList(),
      );

      // TODO: Change it when update the arweave-dart package
      // Currently we need to create the data item for the metadata first
      // so we can get the tx id and add it to the metadata.
      final metadataDataTaskEither = createDataItemTaskEither(
          wallet: wallet,
          dataStream: metadataStreamGenerator,
          dataStreamSize: metadataBytes.length,
          tags: metadata.dataItemTags
              .map((e) => createTag(e.name, e.value))
              .toList());

      final metadataDataItemResult = await metadataDataTaskEither.run();

      metadataDataItemResult.match((l) {
        print('Error: $l');
        print(StackTrace.current);
        throw l;
      }, (metadataDataItem) {
        print('Metadata data item created. ID: ${metadataDataItem.id}');
        metadata.setMetadataTxId = metadataDataItem.id;
        return metadataDataItem;
      });

      /// List of folders DataItems
      folderDataItems.insert(0, metadataFile);

      for (var metadataFolder in folderDataItems) {
        print('Metadata folder size: ${metadataFolder.dataSize}');
        print('Metadata folder tags: ${metadataFolder.tags.length}');
      }

      final folderTransaction = await createDataBundleTransaction(
        dataItemFiles: folderDataItems,
        wallet: wallet,
        tags:
            metadata.bundleTags.map((e) => createTag(e.name, e.value)).toList(),
      );

      /// All folders inside a single BDI, and the remaining files
      return [
        DataResultWithContents<TransactionResult>(
          dataItemResult: folderTransaction,
          contents: folderMetadatas,
        ),
        ...dataItemsResult
      ];
    } else {
      throw Exception('Invalid entity type');
    }
  }
}

// TODO: fix the issue on bundle creation. After this, this class should be the default.
class ARFSDataBundler implements DataBundler<ARFSUploadMetadata> {
  @override
  Future<DataItemResult> createDataBundle(
      {required IOFile file,
      required ARFSUploadMetadata metadata,
      required Wallet wallet,
      SecretKey? driveKey,
      Function? onStartEncryption,
      Function? onStartBundling}) {
    // TODO: implement createDataBundle
    throw UnimplementedError();
  }

  @override
  Future<List<DataResultWithContents>> createDataBundleForEntity({
    required IOEntity entity,
    required ARFSUploadMetadata metadata,
    required Wallet wallet,
    SecretKey? driveKey,
    Function(ARFSUploadMetadata metadata)? skipMetadata,
    required String driveId,
  }) {
    // TODO: implement createDataBundleForEntity
    throw UnimplementedError();
  }

  @override
  Future<TransactionResult> createBundleDataTransaction(
      {required IOFile file,
      required ARFSUploadMetadata metadata,
      required Wallet wallet,
      SecretKey? driveKey,
      Function? onStartEncryption,
      Function? onStartBundling}) {
    // TODO: implement createBundleDataTransaction
    throw UnimplementedError();
  }

  @override
  Future<List<DataResultWithContents>> createBundleDataTransactionForEntity(
      {required IOEntity entity,
      required ARFSUploadMetadata metadata,
      required Wallet wallet,
      SecretKey? driveKey,
      required String driveId,
      Function(ARFSUploadMetadata metadata)? skipMetadata}) {
    // TODO: implement createBundleDataTransactionForEntity
    throw UnimplementedError();
  }
}

@override
Future<List<DataResultWithContents>> createDataBundleForEntity({
  required IOEntity entity,
  required ARFSUploadMetadata metadata, // top level metadata
  required Wallet wallet,
  SecretKey? driveKey,
  required String driveId,
}) {
  // TODO: implement createDataBundleForEntities
  throw UnimplementedError();
}
