@Tags(['broken'])

import 'package:ardrive/blocs/blocs.dart';
import 'package:ardrive/entities/profile_types.dart';
import 'package:ardrive/l11n/l11n.dart';
import 'package:ardrive/models/models.dart';
import 'package:ardrive/services/authentication/biometric_authentication.dart';
import 'package:ardrive/services/services.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../test_utils/fakes.dart';
import '../test_utils/utils.dart';

void main() {
  group('ProfileUnlockCubit', () {
    late ProfileDao profileDao;
    late ProfileCubit profileCubit;
    late ProfileUnlockCubit profileUnlockCubit;
    late ArweaveService arweave;
    late BiometricAuthentication biometricAuthentication;

    const rightPassword = 'right-password';
    const wrongPassword = 'wrong-password';

    setUp(() {
      registerFallbackValue(ProfileStateFake());

      profileDao = MockProfileDao();
      profileCubit = MockProfileCubit();
      arweave = MockArweaveService();
      biometricAuthentication = MockBiometricAuthentication();

      when(() => profileDao.loadDefaultProfile(rightPassword))
          // TODO: check why we are not using the real profile here
          // ignore: null_argument_to_non_null_type
          .thenAnswer((_) => Future.value());
      when(() => profileDao.loadDefaultProfile(wrongPassword))
          .thenThrow(ProfilePasswordIncorrectException());

      profileUnlockCubit = ProfileUnlockCubit(
        profileCubit: profileCubit,
        profileDao: profileDao,
        arweave: arweave,
        biometricAuthentication: biometricAuthentication,
      );
    });

    blocTest<ProfileUnlockCubit, ProfileUnlockState>(
      'loads user profile when right password is used',
      build: () => profileUnlockCubit,
      act: (bloc) {
        bloc.form.value = {'password': rightPassword};
        bloc.submit();
      },
      verify: (bloc) => verify(() =>
          profileCubit.unlockDefaultProfile(rightPassword, ProfileType.json)),
    );

    blocTest<ProfileUnlockCubit, ProfileUnlockState>(
      'emits [] when submitted without valid form',
      build: () => profileUnlockCubit,
      act: (bloc) => bloc.submit(),
      expect: () => [],
    );

    blocTest<ProfileUnlockCubit, ProfileUnlockState>(
      'sets form "${AppValidationMessage.passwordIncorrect}" error when incorrect password is used',
      build: () => profileUnlockCubit,
      act: (bloc) {
        bloc.form.value = {'password': wrongPassword};
        bloc.submit();
      },
      verify: (bloc) => expect(
          bloc.form
              .control('password')
              .errors[AppValidationMessage.passwordIncorrect],
          isTrue),
    );
  });
}
