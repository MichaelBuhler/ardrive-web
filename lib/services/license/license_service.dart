import 'dart:convert';

import 'package:ardrive/entities/license_assertion.dart';
import 'package:drift/drift.dart';

import '../../models/models.dart';
import 'license_types.dart';
import 'licenses/udl.dart';

class LicenseService {
  LicenseType? licenseTypeByTxId(String txId) {
    return licenseInfo.entries
        .firstWhere((element) => element.value.licenseTxId == txId)
        .key;
  }

  LicenseInfo licenseInfoByType(LicenseType licenseType) {
    return licenseInfo[licenseType]!;
  }

  LicenseParams paramsFromAdditionalTags({
    required LicenseType licenseType,
    required Map<String, String> additionalTags,
  }) {
    switch (licenseType) {
      case LicenseType.udl:
        return UdlLicenseParams.fromAdditionalTags(additionalTags);
      default:
        throw ArgumentError('Unknown license type: $licenseType');
    }
  }

  LicenseParams paramsFromEntity(
      LicenseAssertionEntity licenseAssertionEntity) {
    final licenseType = licenseTypeByTxId(licenseAssertionEntity.licenseTxId)!;
    final additionalTags = licenseAssertionEntity.additionalTags;

    return paramsFromAdditionalTags(
      licenseType: licenseType,
      additionalTags: additionalTags,
    );
  }

  LicenseParams paramsFromCompanion(
      LicenseAssertionsCompanion licenseAssertionsCompanion) {
    final licenseType = LicenseType.values.firstWhere(
      (element) => element.name == licenseAssertionsCompanion.licenseType.value,
    );
    final additionalTags = licenseAssertionsCompanion.customGQLTags.present
        ? jsonDecode(licenseAssertionsCompanion.customGQLTags.value ?? '{}')
        : {};

    return paramsFromAdditionalTags(
      licenseType: licenseType,
      additionalTags: additionalTags,
    );
  }

  LicenseAssertionEntity toEntity({
    required String dataTxId,
    required LicenseInfo licenseInfo,
    LicenseParams? licenseParams,
  }) {
    return LicenseAssertionEntity(
      dataTxId: dataTxId,
      licenseTxId: licenseInfo.licenseTxId,
      additionalTags: licenseParams?.toAdditionalTags() ?? {},
    );
  }

  LicenseAssertionsCompanion toCompanion({
    required String dataTxId,
    required LicenseInfo licenseInfo,
    LicenseParams? licenseParams,
  }) {
    return LicenseAssertionsCompanion(
      dataTxId: Value(dataTxId),
      licenseType: Value(licenseInfo.licenseType.name),
      customGQLTags: licenseParams != null
          ? Value(jsonEncode(licenseParams.toAdditionalTags()))
          : const Value.absent(),
    );
  }
}
