import '../license_types.dart';

final udlLicenseInfo = LicenseInfo(
  licenseTxId: 'yRj4a5KMctX_uOmKWCFJIjmY8DeJcusVk6-HzLiM_t8',
  name: 'Universal Data License',
  shortName: 'UDL',
  version: '1.0',
);

class UdlLicenseParams {
  final String? derivations;
  final String? commercialUse;

  UdlLicenseParams({this.derivations, this.commercialUse});

  Map<String, String> toTags() {
    // Null keys should be filtered
    final tags = {
      'Derivation': derivations,
      'Commerical-Use': commercialUse,
    };
    tags.removeWhere((key, value) => value == null);
    return tags as Map<String, String>;
  }

  static UdlLicenseParams fromTags<T>(
    Map<String, String> additionalTags,
  ) {
    return UdlLicenseParams(
      derivations: additionalTags['Derivation'],
      commercialUse: additionalTags['Commerical-Use'],
    );
  }
}
