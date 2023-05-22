part of 'login_bloc.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object> get props => [];
}

class AddWalletFile extends LoginEvent {
  const AddWalletFile(this.walletFile);

  final IOFile walletFile;

  @override
  List<Object> get props => [walletFile];
}

class AddWalletFromArConnect extends LoginEvent {
  const AddWalletFromArConnect();

  @override
  List<Object> get props => [];
}

class CheckIfUserIsLoggedIn extends LoginEvent {
  const CheckIfUserIsLoggedIn();

  @override
  List<Object> get props => [];
}

class LoginWithPassword extends LoginEvent {
  final String password;
  final Wallet wallet;

  const LoginWithPassword({
    required this.password,
    required this.wallet,
  });

  @override
  List<Object> get props => [password];
}

class UnlockUserWithPassword extends LoginEvent {
  final String password;

  const UnlockUserWithPassword({
    required this.password,
  });

  @override
  List<Object> get props => [password];
}

class CreatePassword extends LoginEvent {
  final String password;
  final Wallet wallet;

  const CreatePassword({required this.password, required this.wallet});

  @override
  List<Object> get props => [password];
}

class ForgetWallet extends LoginEvent {
  const ForgetWallet();
}

class FinishOnboarding extends LoginEvent {
  const FinishOnboarding({required this.wallet});

  final Wallet wallet;
}

class UnLockWithBiometrics extends LoginEvent {
  const UnLockWithBiometrics();
}

class EnterSeedPhrase extends LoginEvent {
  const EnterSeedPhrase();
}

class AddWalletFromMnemonic extends LoginEvent {
  const AddWalletFromMnemonic(this.mnemonic);

  final String mnemonic;

  @override
  List<Object> get props => [mnemonic];
}

class CreateWallet extends LoginEvent {
  const CreateWallet();
}

class ConfirmWalletMnemonic extends LoginEvent {
  const ConfirmWalletMnemonic();
}

class VerifyWalletMnemonic extends LoginEvent {
  const VerifyWalletMnemonic();
}

class SaveWalletToDisk extends LoginEvent {
  const SaveWalletToDisk(this.wallet);

  final Wallet wallet;

  @override
  List<Object> get props => [wallet];
}
