import 'dart:async';

import 'package:ardrive/blocs/drive_detail/selected_item.dart';
import 'package:ardrive/blocs/profile/profile_cubit.dart';
import 'package:ardrive/entities/entities.dart';
import 'package:ardrive/models/models.dart';
import 'package:ardrive/services/config/app_config.dart';
import 'package:ardrive/services/services.dart';
import 'package:bloc/bloc.dart';
import 'package:cryptography/cryptography.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:moor/moor.dart';

part 'fs_entry_preview_state.dart';

class FsEntryPreviewCubit extends Cubit<FsEntryPreviewState> {
  final String driveId;
  final SelectedItem? maybeSelectedItem;

  final DriveDao _driveDao;
  final AppConfig _config;
  final ArweaveService _arweave;
  final ProfileCubit _profileCubit;

  StreamSubscription? _entrySubscription;

  final previewMaxFileSize = 1024 * 1024 * 100;
  final allowedPreviewContentTypes = [];

  FsEntryPreviewCubit({
    required this.driveId,
    this.maybeSelectedItem,
    required DriveDao driveDao,
    required AppConfig config,
    required ArweaveService arweave,
    required ProfileCubit profileCubit,
  })  : _driveDao = driveDao,
        _config = config,
        _arweave = arweave,
        _profileCubit = profileCubit,
        super(FsEntryPreviewInitial()) {
    preview();
  }

  Future<void> preview() async {
    final selectedItem = maybeSelectedItem;
    if (selectedItem != null) {
      switch (selectedItem.runtimeType) {
        case SelectedFile:
          _entrySubscription = _driveDao
              .fileById(driveId: driveId, fileId: selectedItem.id)
              .watchSingle()
              .listen((file) {
            if (file.size <= previewMaxFileSize) {
              final contentType =
                  file.dataContentType ?? lookupMimeType(file.name);
              final previewType = contentType?.split('/').first;
              final previewUrl =
                  '${_config.defaultArweaveGatewayUrl}/${file.dataTxId}';
              switch (previewType) {
                case 'image':
                  emitImagePreview(file.id, previewUrl);

                  break;

                ///TODO Enable more previews in the future after dealing
                /// with state and widget disposal
                // case 'audio':
                //   emit(FsEntryPreviewAudio(previewUrl: previewUrl));
                //   break;
                // case 'video':
                //   emit(FsEntryPreviewVideo(previewUrl: previewUrl));
                //   break;
                // case 'text':
                //   emit(FsEntryPreviewText(previewUrl: previewUrl));
                //   break;
                default:
                  emit(FsEntryPreviewUnavailable());
              }
            } else {
              emit(FsEntryPreviewUnavailable());
            }
          });
          break;

        default:
      }
    } else {
      emit(FsEntryPreviewUnavailable());
    }
  }

  Future<void> emitImagePreview(String fileId, String dataUrl) async {
    try {
      final drive = await _driveDao.driveById(driveId: driveId).getSingle();
      final file = await _driveDao
          .fileById(driveId: driveId, fileId: fileId)
          .getSingle();

      late Uint8List dataBytes;

      switch (drive.privacy) {
        case DrivePrivacy.public:
          emit(FsEntryPreviewImage(previewUrl: dataUrl));
          break;
        case DrivePrivacy.private:
          emit(FsEntryPreviewLoading());
          final profile = _profileCubit.state;
          SecretKey? driveKey;

          if (profile is ProfileLoggedIn) {
            driveKey = await _driveDao.getDriveKey(
              drive.id,
              profile.cipherKey,
            );
          } else {
            driveKey = await _driveDao.getDriveKeyFromMemory(driveId);
          }

          if (driveKey == null) {
            throw StateError('Drive Key not found');
          }

          final fileKey = await _driveDao.getFileKey(fileId, driveKey);
          final dataTx = await (_arweave.getTransactionDetails(file.dataTxId));

          if (dataTx != null) {
            final dataRes = await http.get(Uri.parse(dataUrl));
            dataBytes = await decryptTransactionData(
              dataTx,
              dataRes.bodyBytes,
              fileKey,
            );
          }
          emit(
            FsEntryPreviewPrivateImage(
              imageBytes: dataBytes,
              previewUrl: dataUrl,
            ),
          );
          break;

        default:
          emit(FsEntryPreviewFailure());
      }
    } catch (err) {
      addError(err);
    }
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    emit(FsEntryPreviewFailure());
    super.onError(error, stackTrace);

    print('Failed to load entity activity: $error $stackTrace');
  }

  @override
  Future<void> close() {
    _entrySubscription?.cancel();
    return super.close();
  }
}
