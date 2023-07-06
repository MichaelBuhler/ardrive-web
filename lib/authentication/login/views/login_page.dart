import 'dart:async';
import 'dart:convert';

import 'package:animations/animations.dart';
import 'package:ardrive/authentication/ardrive_auth.dart';
import 'package:ardrive/authentication/login/blocs/login_bloc.dart';
import 'package:ardrive/blocs/profile/profile_cubit.dart';
import 'package:ardrive/misc/resources.dart';
import 'package:ardrive/pages/drive_detail/components/hover_widget.dart';
import 'package:ardrive/pages/profile_auth/components/profile_auth_add_screen.dart';
import 'package:ardrive/services/arconnect/arconnect.dart';
import 'package:ardrive/services/authentication/biometric_authentication.dart';
import 'package:ardrive/services/authentication/biometric_permission_dialog.dart';
import 'package:ardrive/services/config/config_service.dart';
import 'package:ardrive/utils/app_localizations_wrapper.dart';
import 'package:ardrive/utils/app_platform.dart';
import 'package:ardrive/utils/open_url.dart';
import 'package:ardrive/utils/pre_cache_assets.dart';
import 'package:ardrive/utils/split_localizations.dart';
import 'package:ardrive_io/ardrive_io.dart';
import 'package:ardrive_ui/ardrive_ui.dart';
import 'package:arweave/arweave.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_builder/responsive_builder.dart';

import '../blocs/memory_check_item.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginBloc>(
      create: (context) => LoginBloc(
        arConnectService: ArConnectService(),
        arDriveAuth: context.read<ArDriveAuth>(),
      )..add(const CheckIfUserIsLoggedIn()),
      child: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state is LoginOnBoarding) {
            preCacheOnBoardingAssets(context);
          }
        },
        builder: (context, state) {
          return _FadeThroughTransitionSwitcher(
            fillColor: Colors.transparent,
            child: state is LoginOnBoarding
                ? OnBoardingView(wallet: state.walletFile)
                : const LoginPageScaffold(),
          );
        },
      ),
    );
  }
}

class LoginPageScaffold extends StatefulWidget {
  const LoginPageScaffold({
    super.key,
  });

  @override
  State<LoginPageScaffold> createState() => _LoginPageScaffoldState();
}

class _LoginPageScaffoldState extends State<LoginPageScaffold> {
  final globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout(
      desktop: Material(
        color: ArDriveTheme.of(context).themeData.backgroundColor,
        child: Row(
          children: [
            Expanded(
              child: _buildIllustration(
                  context,
                  // verify theme light
                  Resources.images.login.gridImage),
            ),
            Expanded(
              child: FractionallySizedBox(
                widthFactor: 0.75,
                child: Center(
                  child: _buildContent(context),
                ),
              ),
            ),
          ],
        ),
      ),
      mobile: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Center(child: _buildContent(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration(BuildContext context, String image) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ArDriveImage(
                key: const Key('loginPageIllustration'),
                image: AssetImage(
                  image,
                ),
                height: 600,
                width: 600,
                fit: BoxFit.cover,
              ),
              Container(
                color: ArDriveTheme.of(context)
                    .themeData
                    .colors
                    .themeBgCanvas
                    .withOpacity(0.8),
              ),
            ],
          ),
        ),
        Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ArDriveImage(
                image: AssetImage(
                  ArDriveTheme.of(context).themeData.name == 'light'
                      ? Resources.images.brand.blackLogo2
                      : Resources.images.brand.whiteLogo2,
                ),
                height: 65,
                fit: BoxFit.contain,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 42),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.32,
                  child: Text(
                    appLocalizationsOf(context)
                        .yourPrivateSecureAndPermanentDrive,
                    textAlign: TextAlign.start,
                    style: ArDriveTypography.headline.headline3Regular(
                      color: ArDriveTheme.of(context)
                          .themeData
                          .colors
                          .themeFgDefault,
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final enableSeedPhraseLogin =
        context.read<ConfigService>().config.enableSeedPhraseLogin;
    return BlocConsumer<LoginBloc, LoginState>(
      key: globalKey,
      buildWhen: (previous, current) =>
          current is! LoginFailure &&
          current is! LoginSuccess &&
          current is! LoginOnBoarding,
      listener: (context, state) {
        if (state is LoginFailure) {
          // TODO: Verify if the error is `NoConnectionException` and show an appropriate message after validating with UI/UX

          if (state.error is WalletMismatchException) {
            showAnimatedDialog(
              context,
              content: ArDriveIconModal(
                title: appLocalizationsOf(context).loginFailed,
                content: appLocalizationsOf(context)
                    .arConnectWalletDoestNotMatchArDriveWallet,
                icon: ArDriveIcons.triangle(
                  size: 88,
                  color:
                      ArDriveTheme.of(context).themeData.colors.themeErrorMuted,
                ),
              ),
            );
            return;
          } else if (state.error is BiometricException) {
            showBiometricExceptionDialogForException(
                context, state.error as BiometricException, () {});
            return;
          }

          showAnimatedDialog(
            context,
            content: ArDriveIconModal(
              title: appLocalizationsOf(context).loginFailed,
              content: appLocalizationsOf(context).pleaseTryAgain,
              icon: ArDriveIcons.triangle(
                size: 88,
                color:
                    ArDriveTheme.of(context).themeData.colors.themeErrorMuted,
              ),
            ),
          );
        } else if (state is LoginSuccess) {
          context.read<ProfileCubit>().unlockDefaultProfile(
              state.user.password, state.user.profileType);
        }
      },
      builder: (context, state) {
        late Widget content;

        // content = DownloadWalletView(mnemonic: 'test', wallet: null);

        if (state is PromptPassword) {
          content = PromptPasswordView(
            wallet: state.walletFile,
          );
        } else if (state is CreatingNewPassword) {
          content = CreatePasswordView(
            wallet: state.walletFile,
          );
        } else if (state is LoginLoading) {
          content = const MaxDeviceSizesConstrainedBox(
            child: _LoginCard(
              content: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        } else if (enableSeedPhraseLogin && state is LoginEnterSeedPhrase) {
          content = const EnterSeedPhraseView();
        } else if (enableSeedPhraseLogin && state is LoginGenerateWallet) {
          content = GenerateWalletView(mnemonic: state.mnemonic);
        } else if (enableSeedPhraseLogin &&
            state is LoginDownloadGeneratedWallet) {
          content = DownloadWalletView(
              mnemonic: state.mnemonic, wallet: state.walletFile);
        } else if (enableSeedPhraseLogin && state is LoginConfirmMnemonic) {
          content = MemoryCheckView(
              mnemonic: state.mnemonic, wallet: state.walletFile);
        } else {
          content = PromptWalletView(
            key: const Key('promptWalletView'),
            isArConnectAvailable: (state as LoginInitial).isArConnectAvailable,
          );
        }

        return SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              content,
            ],
          ),
        );
      },
    );
  }
}

class PromptWalletView extends StatefulWidget {
  const PromptWalletView({
    super.key,
    required this.isArConnectAvailable,
  });

  final bool isArConnectAvailable;

  @override
  State<PromptWalletView> createState() => _PromptWalletViewState();
}

class _PromptWalletViewState extends State<PromptWalletView> {
  late ArDriveDropAreaSingleInputController _dropAreaController;

  @override
  void initState() {
    _dropAreaController = ArDriveDropAreaSingleInputController(
      onFileAdded: (file) {
        context.read<LoginBloc>().add(AddWalletFile(file));
      },
      validateFile: (file) async {
        final wallet =
            await context.read<LoginBloc>().validateAndReturnWalletFile(file);

        return wallet != null;
      },
      onDragEntered: () {},
      onDragExited: () {},
      onError: (Object e) {},
    );

    super.initState();
  }

  bool _showSecurityOverlay = false;

  @override
  Widget build(BuildContext context) {
    return MaxDeviceSizesConstrainedBox(
      defaultMaxWidth: 512,
      defaultMaxHeight: 798,
      maxHeightPercent: 0.9,
      child: _LoginCard(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ScreenTypeLayout(
              desktop: const SizedBox.shrink(),
              mobile: ArDriveImage(
                image: AssetImage(Resources.images.brand.logo1),
                height: 50,
              ),
            ),
            heightSpacing(),
            Align(
              alignment: Alignment.topCenter,
              child: Text(
                appLocalizationsOf(context).login,
                style: ArDriveTypography.headline.headline4Regular(),
              ),
            ),
            heightSpacing(),
            Column(
              children: [
                if (context
                    .read<ConfigService>()
                    .config
                    .enableSeedPhraseLogin) ...[
                  ArDriveButton(
                    key: const Key('loginWithSeedPhraseButton'),
                    text: "Enter Seed Phrase",
                    onPressed: () {
                      context.read<LoginBloc>().add(EnterSeedPhrase());
                    },
                    style: ArDriveButtonStyle.secondary,
                    fontStyle: ArDriveTypography.body
                        .smallBold700(color: Colors.white),
                    maxWidth: double.maxFinite,
                  ),
                  const SizedBox(height: 16),
                ],
                ArDriveDropAreaSingleInput(
                  controller: _dropAreaController,
                  keepButtonVisible: true,
                  width: double.maxFinite,
                  dragAndDropDescription: "Select a KeyFile",
                  // dragAndDropButtonTitle:
                  //     appLocalizationsOf(context).dragAndDropButtonTitle,
                  dragAndDropButtonTitle: "Select a KeyFile",
                  errorDescription: appLocalizationsOf(context).invalidKeyFile,
                  validateFile: (file) async {
                    final wallet = await context
                        .read<LoginBloc>()
                        .validateAndReturnWalletFile(file);

                    return wallet != null;
                  },
                  platformSupportsDragAndDrop: !AppPlatform.isMobile,
                ),
                const SizedBox(height: 24),
                ArDriveOverlay(
                  visible: _showSecurityOverlay,
                  content: ArDriveCard(
                    boxShadow: BoxShadowCard.shadow100,
                    contentPadding: const EdgeInsets.all(16),
                    width: 300,
                    content: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: appLocalizationsOf(context)
                                .securityWalletOverlay,
                            style: ArDriveTypography.body.smallBold(),
                          ),
                          TextSpan(
                            text: ' ',
                            style: ArDriveTypography.body.buttonNormalRegular(
                              color: ArDriveTheme.of(context)
                                  .themeData
                                  .colors
                                  .themeFgOnAccent,
                            ),
                          ),
                          TextSpan(
                            text: appLocalizationsOf(context).learnMore,
                            style: ArDriveTypography.body
                                .buttonNormalRegular(
                                  color: ArDriveTheme.of(context)
                                      .themeData
                                      .colors
                                      .themeFgOnAccent,
                                )
                                .copyWith(
                                  decoration: TextDecoration.underline,
                                ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => openUrl(
                                    url: Resources.howDoesKeyFileLoginWork,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  anchor: const Aligned(
                    follower: Alignment.bottomCenter,
                    target: Alignment.topCenter,
                    offset: Offset(0, 4),
                  ),
                  onVisibleChange: (visible) {
                    setState(() {
                      _showSecurityOverlay = visible;
                    });
                  },
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSecurityOverlay = !_showSecurityOverlay;
                      });
                    },
                    child: HoverWidget(
                      hoverScale: 1,
                      child: Text(
                          appLocalizationsOf(context).howDoesKeyfileLoginWork,
                          style: ArDriveTypography.body.smallBold().copyWith(
                                decoration: TextDecoration.underline,
                                fontSize: 14,
                                height: 1.5,
                              )),
                    ),
                  ),
                ),
                if (widget.isArConnectAvailable) ...[
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                          child: Container(
                        decoration: const ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              width: 0.50,
                              strokeAlign: BorderSide.strokeAlignCenter,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                      )),
                      Padding(
                          padding: const EdgeInsets.only(left: 25, right: 25),
                          child: Text(
                            'OR',
                            textAlign: TextAlign.center,
                            style: ArDriveTypography.body
                                .smallBold(color: Color(0xFF9E9E9E)),
                          )),
                      Expanded(
                          child: Container(
                        decoration: const ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              width: 0.50,
                              strokeAlign: BorderSide.strokeAlignCenter,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                      )),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: ArDriveButton(
                            icon: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: ArDriveIcons.arconnectIcon1(
                                  color: Colors.white,
                                )),
                            style: ArDriveButtonStyle.secondary,
                            fontStyle: ArDriveTypography.body.smallBold700(
                                color: ArDriveTheme.of(context)
                                    .themeData
                                    .colors
                                    .themeFgDefault),
                            onPressed: () {
                              context
                                  .read<LoginBloc>()
                                  .add(const AddWalletFromArConnect());
                            },
                            text: 'Login with ArConnect',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(
                  height: 72,
                ),
              ],
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                      // text: appLocalizationsOf(context).dontHaveAWallet1Part,
                      text: "New User? Get started ",
                      style: ArDriveTypography.body.smallBold(
                        color: ArDriveTheme.of(context)
                            .themeData
                            .colors
                            .themeFgMuted,
                      )),
                  TextSpan(
                    text: appLocalizationsOf(context).dontHaveAWallet2Part,
                    style: ArDriveTypography.body.smallBold().copyWith(
                          decoration: TextDecoration.underline,
                        ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        context.read<LoginBloc>().add(GenerateWallet());
                        // openUrl(url: Resources.getWalletLink);
                      },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SizedBox heightSpacing() {
    return SizedBox(
        height: MediaQuery.of(context).size.height < 700 ? 8.0 : 24.0);
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      double horizontalPadding = 72;

      final deviceType = getDeviceType(MediaQuery.of(context).size);

      switch (deviceType) {
        case DeviceScreenType.desktop:
          if (constraints.maxWidth >= 512) {
            horizontalPadding = 72;
          } else {
            horizontalPadding = constraints.maxWidth * 0.15 >= 72
                ? 72
                : constraints.maxWidth * 0.15;
          }
          break;
        case DeviceScreenType.tablet:
          horizontalPadding = 32;
          break;
        case DeviceScreenType.mobile:
          horizontalPadding = 16;
          break;
        default:
          horizontalPadding = 72;
      }

      return ArDriveCard(
        backgroundColor:
            ArDriveTheme.of(context).themeData.colors.themeBgSurface,
        borderRadius: 24,
        boxShadow: BoxShadowCard.shadow80,
        contentPadding: EdgeInsets.fromLTRB(
          horizontalPadding,
          _topPadding(context),
          horizontalPadding,
          _bottomPadding(context),
        ),
        content: content,
      );
    });
  }

  double _topPadding(BuildContext context) {
    if (MediaQuery.of(context).size.height * 0.05 > 53) {
      return 53;
    } else {
      return MediaQuery.of(context).size.height * 0.05;
    }
  }

  double _bottomPadding(BuildContext context) {
    if (MediaQuery.of(context).size.height * 0.05 > 43) {
      return 43;
    } else {
      return MediaQuery.of(context).size.height * 0.05;
    }
  }
}

class PromptPasswordView extends StatefulWidget {
  const PromptPasswordView({super.key, this.wallet});

  final Wallet? wallet;

  @override
  State<PromptPasswordView> createState() => _PromptPasswordViewState();
}

class _PromptPasswordViewState extends State<PromptPasswordView> {
  final _passwordController = TextEditingController();

  bool _isPasswordValid = false;

  @override
  Widget build(BuildContext context) {
    return MaxDeviceSizesConstrainedBox(
      child: _LoginCard(
        content: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                appLocalizationsOf(context).welcomeBackEmphasized,
                textAlign: TextAlign.center,
                style: ArDriveTypography.headline.headline4Bold(),
              ),
              Column(
                children: [
                  ArDriveTextField(
                      showObfuscationToggle: true,
                      controller: _passwordController,
                      obscureText: true,
                      autofocus: true,
                      autofillHints: const [AutofillHints.password],
                      hintText: appLocalizationsOf(context).enterPassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          setState(() {
                            _isPasswordValid = false;
                          });
                          return appLocalizationsOf(context).validationRequired;
                        }

                        setState(() {
                          _isPasswordValid = true;
                        });

                        return null;
                      },
                      onFieldSubmitted: (_) async {
                        if (_isPasswordValid) {
                          _onSubmit();
                        }
                      }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ArDriveButton(
                      isDisabled: !_isPasswordValid,
                      onPressed: () {
                        _onSubmit();
                      },
                      text: appLocalizationsOf(context).proceed,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BiometricToggle(
                    onEnableBiometric: () {
                      /// Biometrics was enabled
                      context
                          .read<LoginBloc>()
                          .add(const UnLockWithBiometrics());
                    },
                  ),
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ArDriveButton(
                  onPressed: () {
                    _forgetWallet(context);
                  },
                  style: ArDriveButtonStyle.tertiary,
                  text: appLocalizationsOf(context).forgetWallet,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSubmit() {
    if (widget.wallet == null) {
      context.read<LoginBloc>().add(
            UnlockUserWithPassword(
              password: _passwordController.text,
            ),
          );
    } else {
      context.read<LoginBloc>().add(
            LoginWithPassword(
              password: _passwordController.text,
              wallet: widget.wallet!,
            ),
          );
    }
  }
}

class CreatePasswordView extends StatefulWidget {
  const CreatePasswordView({super.key, required this.wallet});

  final Wallet wallet;

  @override
  State<CreatePasswordView> createState() => _CreatePasswordViewState();
}

class _CreatePasswordViewState extends State<CreatePasswordView> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<ArDriveFormState>();

  bool _isTermsChecked = false;

  bool _passwordIsValid = false;
  bool _confirmPasswordIsValid = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaxDeviceSizesConstrainedBox(
      defaultMaxHeight: 798,
      maxHeightPercent: 1,
      child: _LoginCard(
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ScreenTypeLayout(
                desktop: const SizedBox.shrink(),
                mobile: ArDriveImage(
                  image: AssetImage(Resources.images.brand.logo1),
                  height: 50,
                ),
              ),
              Text(
                appLocalizationsOf(context).createAndConfirmPassword,
                textAlign: TextAlign.center,
                style: ArDriveTypography.headline.headline5Regular(),
              ),
              const SizedBox(height: 16),
              _createPasswordForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createPasswordForm() {
    return ArDriveForm(
      key: _formKey,
      child: Column(
        children: [
          ArDriveTextField(
            autofocus: true,
            controller: _passwordController,
            showObfuscationToggle: true,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            hintText: appLocalizationsOf(context).enterPassword,
            onChanged: (s) {
              _formKey.currentState?.validate();
            },
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                setState(() {
                  _passwordIsValid = false;
                });
                return appLocalizationsOf(context).validationRequired;
              }

              setState(() {
                _passwordIsValid = true;
              });

              return null;
            },
          ),
          const SizedBox(height: 16),
          ArDriveTextField(
            controller: _confirmPasswordController,
            showObfuscationToggle: true,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            hintText: appLocalizationsOf(context).confirmPassword,
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.isEmpty) {
                setState(() {
                  _confirmPasswordIsValid = false;
                });
                return appLocalizationsOf(context).validationRequired;
              } else if (value != _passwordController.text) {
                setState(() {
                  _confirmPasswordIsValid = false;
                });
                return appLocalizationsOf(context).passwordMismatch;
              }
              setState(() {
                _confirmPasswordIsValid = true;
              });

              return null;
            },
            onFieldSubmitted: (_) {
              if (_passwordIsValid &&
                  _confirmPasswordIsValid &&
                  _isTermsChecked) {
                _onSubmit();
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ArDriveCheckBox(
                title: '',
                checked: _isTermsChecked,
                onChange: ((value) {
                  setState(() => _isTermsChecked = value);
                }),
              ),
              Flexible(
                child: GestureDetector(
                  onTap: () => openUrl(
                    url: Resources.agreementLink,
                  ),
                  child: ArDriveClickArea(
                    child: Text.rich(
                      TextSpan(
                        children:
                            splitTranslationsWithMultipleStyles<InlineSpan>(
                          originalText:
                              appLocalizationsOf(context).aggreeToTerms_body,
                          defaultMapper: (text) => TextSpan(text: text),
                          parts: {
                            appLocalizationsOf(context).aggreeToTerms_link:
                                (text) => TextSpan(
                                      text: text,
                                      style: const TextStyle(
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ArDriveButton(
              isDisabled: !_isTermsChecked ||
                  _passwordIsValid == false ||
                  _confirmPasswordIsValid == false,
              onPressed: _onSubmit,
              text: appLocalizationsOf(context).proceed,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ArDriveButton(
              onPressed: () {
                _forgetWallet(context);
              },
              style: ArDriveButtonStyle.tertiary,
              text: appLocalizationsOf(context).forgetWallet,
            ),
          ),
        ],
      ),
    );
  }

  void _onSubmit() {
    final isValid = _formKey.currentState!.validateSync();

    if (!isValid) {
      showAnimatedDialog(context,
          content: ArDriveIconModal(
            icon: ArDriveIcons.triangle(
              size: 88,
              color: ArDriveTheme.of(context).themeData.colors.themeErrorMuted,
            ),
            title: appLocalizationsOf(context).passwordCannotBeEmpty,
            content: appLocalizationsOf(context).pleaseTryAgain,
            actions: [
              ModalAction(
                action: () {
                  Navigator.pop(context);
                },
                title: appLocalizationsOf(context).ok,
              )
            ],
          ));
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      showAnimatedDialog(context,
          content: ArDriveIconModal(
            icon: ArDriveIcons.triangle(
              size: 88,
              color: ArDriveTheme.of(context).themeData.colors.themeErrorMuted,
            ),
            title: appLocalizationsOf(context).passwordDoNotMatch,
            content: appLocalizationsOf(context).pleaseTryAgain,
            actions: [
              ModalAction(
                action: () {
                  Navigator.pop(context);
                },
                title: appLocalizationsOf(context).ok,
              )
            ],
          ));
      return;
    }

    context.read<LoginBloc>().add(
          CreatePassword(
            password: _passwordController.text,
            wallet: widget.wallet,
          ),
        );
  }
}

class OnBoardingView extends StatefulWidget {
  const OnBoardingView({
    super.key,
    required this.wallet,
  });
  final Wallet wallet;

  @override
  State<OnBoardingView> createState() => OnBoardingViewState();
}

class OnBoardingViewState extends State<OnBoardingView> {
  int _currentPage = 0;

  List<_OnBoarding> get _list => [
        _OnBoarding(
          primaryButtonText: appLocalizationsOf(context).next,
          primaryButtonAction: () {
            setState(() {
              _currentPage++;
            });
          },
          secundaryButtonHasIcon: false,
          secundaryButtonText: appLocalizationsOf(context).skip,
          secundaryButtonAction: () {
            context.read<LoginBloc>().add(
                  FinishOnboarding(
                    wallet: widget.wallet,
                  ),
                );
          },
          title: appLocalizationsOf(context).onboarding1Title,
          description: appLocalizationsOf(context).onboarding1Description,
          illustration: AssetImage(Resources.images.login.gridImage),
        ),
        _OnBoarding(
          primaryButtonText: appLocalizationsOf(context).next,
          primaryButtonAction: () {
            setState(() {
              _currentPage++;
            });
          },
          secundaryButtonText: appLocalizationsOf(context).backButtonOnboarding,
          secundaryButtonAction: () {
            setState(() {
              _currentPage--;
            });
          },
          title: appLocalizationsOf(context).onboarding2Title,
          description: appLocalizationsOf(context).onboarding2Description,
          illustration: AssetImage(Resources.images.login.gridImage),
        ),
        _OnBoarding(
          primaryButtonText: appLocalizationsOf(context).diveInButtonOnboarding,
          primaryButtonAction: () {
            context.read<LoginBloc>().add(
                  FinishOnboarding(
                    wallet: widget.wallet,
                  ),
                );
          },
          secundaryButtonText: appLocalizationsOf(context).backButtonOnboarding,
          secundaryButtonAction: () {
            setState(() {
              _currentPage--;
            });
          },
          title: appLocalizationsOf(context).onboarding3Title,
          description: appLocalizationsOf(context).onboarding3Description,
          illustration: AssetImage(Resources.images.login.gridImage),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout(
      desktop: Material(
        color: ArDriveTheme.of(context).themeData.colors.themeBgCanvas,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                color: ArDriveTheme.of(context).themeData.colors.themeBgSurface,
                child: Align(
                  child: MaxDeviceSizesConstrainedBox(
                    child: _FadeThroughTransitionSwitcher(
                      fillColor: ArDriveTheme.of(context)
                          .themeData
                          .colors
                          .themeBgSurface,
                      child: _buildOnBoardingContent(),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FractionallySizedBox(
                heightFactor: 1,
                child: _buildOnBoardingIllustration(_currentPage),
              ),
            ),
          ],
        ),
      ),
      mobile: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          color: ArDriveTheme.of(context).themeData.colors.themeBgCanvas,
          child: Align(
            child: MaxDeviceSizesConstrainedBox(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildOnBoardingContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnBoardingIllustration(int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.25,
          child: ArDriveImage(
            image: _list[_currentPage].illustration,
            fit: BoxFit.cover,
            height: double.maxFinite,
            width: double.maxFinite,
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ArDriveImage(
                image: AssetImage(
                  Resources.images.login.ardriveLogoOnboarding,
                ),
                fit: BoxFit.contain,
                height: 240,
                width: 240,
              ),
              const SizedBox(
                height: 48,
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ArDrivePaginationDots(
                  currentPage: _currentPage,
                  numberOfPages: _list.length,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOnBoardingContent() {
    return _OnBoardingContent(
      key: ValueKey(_currentPage),
      onBoarding: _list[_currentPage],
    );
  }
}

class _OnBoardingContent extends StatelessWidget {
  const _OnBoardingContent({
    super.key,
    required this.onBoarding,
  });

  final _OnBoarding onBoarding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Text(
          onBoarding.title,
          style: ArDriveTypography.headline.headline3Bold(),
        ),
        Text(
          onBoarding.description,
          style: ArDriveTypography.body.buttonXLargeBold(),
        ),
        Row(
          key: const ValueKey('buttons'),
          children: [
            ArDriveButton(
              icon: onBoarding.secundaryButtonHasIcon
                  ? ArDriveIcons.arrowLeftOutline()
                  : null,
              style: ArDriveButtonStyle.secondary,
              text: onBoarding.secundaryButtonText,
              onPressed: () => onBoarding.secundaryButtonAction(),
            ),
            const SizedBox(width: 32),
            ArDriveButton(
              iconAlignment: IconButtonAlignment.right,
              icon: ArDriveIcons.arrowRightOutline(
                color: Colors.white,
              ),
              text: onBoarding.primaryButtonText,
              onPressed: () => onBoarding.primaryButtonAction(),
            ),
          ],
        ),
      ],
    );
  }
}

class _OnBoarding {
  final String title;
  final String description;
  final String primaryButtonText;
  final String secundaryButtonText;
  final Function primaryButtonAction;
  final Function secundaryButtonAction;
  final bool secundaryButtonHasIcon;
  final ImageProvider illustration;

  _OnBoarding({
    required this.title,
    required this.description,
    required this.primaryButtonText,
    required this.secundaryButtonText,
    required this.illustration,
    required this.primaryButtonAction,
    required this.secundaryButtonAction,
    this.secundaryButtonHasIcon = true,
  });
}

class _FadeThroughTransitionSwitcher extends StatelessWidget {
  const _FadeThroughTransitionSwitcher({
    required this.fillColor,
    required this.child,
    Key? key,
  }) : super(key: key);

  final Widget child;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      transitionBuilder: (child, animation, secondaryAnimation) {
        return FadeThroughTransition(
          fillColor: ArDriveTheme.of(context).themeData.colors.themeBgSurface,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
      child: child,
    );
  }
}

void _forgetWallet(
  BuildContext context,
) {
  final actions = [
    ModalAction(
      action: () {
        Navigator.pop(context);
      },
      title: appLocalizationsOf(context).cancel,
    ),
    ModalAction(
      action: () {
        Navigator.pop(context);

        context.read<LoginBloc>().add(const ForgetWallet());
      },
      title: appLocalizationsOf(context).ok,
    )
  ];
  showStandardDialog(
    context,
    title: appLocalizationsOf(context).forgetWalletTitle,
    description: appLocalizationsOf(context).forgetWalletDescription,
    actions: actions,
  );
}

class MaxDeviceSizesConstrainedBox extends StatelessWidget {
  final double maxHeightPercent;
  final double defaultMaxHeight;
  final double defaultMaxWidth;
  final Widget child;

  const MaxDeviceSizesConstrainedBox({
    Key? key,
    this.maxHeightPercent = 0.8,
    this.defaultMaxWidth = _defaultLoginCardMaxWidth,
    this.defaultMaxHeight = _defaultLoginCardMaxHeight,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * maxHeightPercent;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: defaultMaxWidth,
        maxHeight: defaultMaxHeight > maxHeight ? maxHeight : defaultMaxHeight,
      ),
      child: child,
    );
  }
}

const double _defaultLoginCardMaxWidth = 512;
const double _defaultLoginCardMaxHeight = 489;

class EnterSeedPhraseView extends StatefulWidget {
  const EnterSeedPhraseView();

  // final Wallet wallet;

  @override
  State<EnterSeedPhraseView> createState() => _EnterSeedPhraseViewState();
}

class _EnterSeedPhraseViewState extends State<EnterSeedPhraseView> {
  final _seedPhraseController = ArDriveMultlineObscureTextController();
  final _formKey = GlobalKey<ArDriveFormState>();

  bool _seedPhraseFormatIsValid = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaxDeviceSizesConstrainedBox(
      defaultMaxHeight: 798,
      maxHeightPercent: 1,
      child: _LoginCard(
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ScreenTypeLayout(
                desktop: const SizedBox.shrink(),
                mobile: ArDriveImage(
                  image: AssetImage(Resources.images.brand.logo1),
                  height: 50,
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Text(
                  'Enter Seed Phrase',
                  style: ArDriveTypography.headline.headline4Regular(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                // appLocalizationsOf(context).createAndConfirmPassword,
                'Please enter your 12 word seed phrase and separate each word with a space.',
                textAlign: TextAlign.center,
                style: ArDriveTypography.body.smallBold(),
              ),
              const SizedBox(height: 50),
              _createSeedPhraseForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createSeedPhraseForm() {
    return ArDriveForm(
      key: _formKey,
      child: Column(
        children: [
          Align(
              alignment: Alignment.topLeft,
              child: Text(
                "Seed Phrase",
                style:
                    ArDriveTypography.body.smallBold().copyWith(fontSize: 14),
              )),
          const SizedBox(height: 8),
          ArDriveTextField(
            autofocus: true,
            controller: _seedPhraseController,
            showObfuscationToggle: true,
            obscureText: true,
            // autofillHints: const [AutofillHints.password],
            // hintText: appLocalizationsOf(context).enterPassword,
            hintText: 'Enter Seed Phrase',
            onChanged: (s) {
              _formKey.currentState?.validate();
            },
            textInputAction: TextInputAction.next,
            minLines: 3,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                setState(() {
                  _seedPhraseFormatIsValid = false;
                });
                return appLocalizationsOf(context).validationRequired;
              } else if (!bip39.validateMnemonic(value)) {
                setState(() {
                  _seedPhraseFormatIsValid = false;
                });
                // FIXME - localize
                return 'Please enter a valid 12-word mnemonic.';
                // return appLocalizationsOf(context).validationRequired;
              }

              setState(() {
                _seedPhraseFormatIsValid = true;
              });

              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ArDriveButton(
              isDisabled: !_seedPhraseFormatIsValid,
              onPressed: _onSubmit,
              // text: appLocalizationsOf(context).proceed,
              text: 'Continue',
              fontStyle:
                  ArDriveTypography.body.smallBold700(color: Colors.white),
            ),
          ),
          const SizedBox(height: 56),
          Align(
              alignment: Alignment.bottomLeft,
              child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      _forgetWallet(context);
                    },
                    child: Row(children: [
                      ArDriveIcons.carretLeft(
                          size: 16,
                          color: ArDriveTheme.of(context)
                              .themeData
                              .colors
                              .themeFgDefault),
                      Text(appLocalizationsOf(context).back),
                    ]),
                  ))),
        ],
      ),
    );
  }

  void _onSubmit() async {
    final isValid = await _formKey.currentState!.validate();

    if (!isValid) {
      showAnimatedDialog(context,
          content: ArDriveIconModal(
            icon: ArDriveIcons.triangle(
              size: 88,
              color: ArDriveTheme.of(context).themeData.colors.themeErrorMuted,
            ),
            title: appLocalizationsOf(context).passwordCannotBeEmpty,
            content: appLocalizationsOf(context).pleaseTryAgain,
            actions: [
              ModalAction(
                action: () {
                  Navigator.pop(context);
                },
                title: appLocalizationsOf(context).ok,
              )
            ],
          ));
      return;
    }

    context
        .read<LoginBloc>()
        .add(AddWalletFromMnemonic(_seedPhraseController.text));
  }
}

class GenerateWalletView extends StatefulWidget {
  const GenerateWalletView({super.key, required this.mnemonic, this.wallet});

  final String mnemonic;
  final Wallet? wallet;

  @override
  State<GenerateWalletView> createState() => _GenerateWalletViewState();
}

class _GenerateWalletViewState extends State<GenerateWalletView> {
  late Timer _periodicTimer;
  int _index = 0;
  final _messages = [
    'ArDrive helps you upload your data to the permaweb and keep it safe for generations to come!',
    'With Turbo you can pay with a credit card and increase the reliability of your uploads!',
    'You can download a copy of your keyfile from the Profile menu.',
    'If you have large drives, you can take a Snapshot to speed up the syncing time.'
  ];
  late String _message;

  @override
  void initState() {
    super.initState();
    _message = 'Did you know?\n\n${_messages[0]}';

    _periodicTimer = Timer.periodic(Duration(seconds: 7), (Timer t) {
      setState(() {
        _index = (_index + 1) % _messages.length;
        _message = 'Did you know?\n\n${_messages[_index]}';
      });
    });
  }

  @override
  void dispose() {
    _periodicTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaxDeviceSizesConstrainedBox(
      defaultMaxHeight: 798,
      maxHeightPercent: 1,
      child: _LoginCard(
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ScreenTypeLayout(
                desktop: const SizedBox.shrink(),
                mobile: ArDriveImage(
                  image: AssetImage(Resources.images.brand.logo1),
                  height: 50,
                ),
              ),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Generating Wallet...',
                textAlign: TextAlign.center,
                style: ArDriveTypography.headline
                    .headline4Regular(
                        color: ArDriveTheme.of(context)
                            .themeData
                            .colors
                            .themeFgMuted)
                    .copyWith(fontSize: 32),
              ),
              const SizedBox(height: 74),
              // Did you Know box
              Container(
                width: 227,
                height: 150,
                child: Text(
                  _message,
                  textAlign: TextAlign.right,
                  style: ArDriveTypography.body.smallBold700(
                      color: ArDriveTheme.of(context)
                          .themeData
                          .colors
                          .themeFgMuted),
                ),
              ),
              const SizedBox(height: 79),
              // Info Box
              Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: ArDriveTheme.of(context)
                              .themeData
                              .colors
                              .themeBorderDefault,
                          width: 1),
                      color: ArDriveTheme.of(context)
                          .themeData
                          .colors
                          .themeBgSurface,
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ArDriveIcons.info(
                          size: 24,
                          color: ArDriveTheme.of(context)
                              .themeData
                              .colors
                              .themeFgSubtle),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                            'Nobody (including the ArDrive core team) can help you recover your wallet if the keyfile is lost. So, remember to keep it safe!',
                            style: ArDriveTypography.body.buttonNormalBold(
                                color: ArDriveTheme.of(context)
                                    .themeData
                                    .colors
                                    .themeFgSubtle)),
                      ),
                    ],
                  ))
            ],
          ),
        ),
      ),
    );
  }
}

class DownloadWalletView extends StatefulWidget {
  const DownloadWalletView(
      {super.key, required this.mnemonic, required this.wallet});

  final String mnemonic;
  final Wallet wallet;

  @override
  State<DownloadWalletView> createState() => _DownloadWalletViewState();
}

class _DownloadWalletViewState extends State<DownloadWalletView> {
  @override
  Widget build(BuildContext context) {
    return MaxDeviceSizesConstrainedBox(
      defaultMaxHeight: 798,
      maxHeightPercent: 1,
      child: _LoginCard(
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ScreenTypeLayout(
                desktop: const SizedBox.shrink(),
                mobile: ArDriveImage(
                  image: AssetImage(Resources.images.brand.logo1),
                  height: 50,
                ),
              ),
              ArDriveIcons.checkmark(
                  size: 32,
                  color: ArDriveTheme.of(context)
                      .themeData
                      .colors
                      .themeSuccessDefault),
              const SizedBox(height: 16),
              Text(
                'Wallet Created',
                textAlign: TextAlign.center,
                style: ArDriveTypography.headline
                    .headline4Regular(
                        color: ArDriveTheme.of(context)
                            .themeData
                            .colors
                            .themeFgMuted)
                    .copyWith(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                'Download your keyfile. You can also find it under the profile menu.',
                textAlign: TextAlign.center,
                style: ArDriveTypography.body.smallBold(
                    color: ArDriveTheme.of(context)
                        .themeData
                        .colors
                        .themeFgSubtle),
              ),
              const SizedBox(height: 56),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                    onTap: () {
                      _onDownload();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: ArDriveTheme.of(context)
                                  .themeData
                                  .colors
                                  .themeBorderDefault,
                              width: 1),
                          color: ArDriveTheme.of(context)
                              .themeData
                              .colors
                              .themeBgSurface),
                      padding: const EdgeInsets.all(6),
                      child: Container(
                          width: double.maxFinite,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              // border: Border.all(color: ArDriveTheme.of(context).themeData.colors.themeBorderDefault, width: 1),
                              color: ArDriveTheme.of(context)
                                  .themeData
                                  .colors
                                  .themeBgSubtle),
                          padding: const EdgeInsets.all(44),
                          child: Column(
                            children: [
                              ArDriveIcons.download(size: 40),
                              const SizedBox(height: 4),
                              Text('Download Keyfile',
                                  style: ArDriveTypography.body.smallBold700(
                                      color: ArDriveTheme.of(context)
                                          .themeData
                                          .colors
                                          .themeFgDefault))
                            ],
                          )),
                    )),
              ),
              const SizedBox(height: 56),
              SizedBox(
                width: double.infinity,
                child: ArDriveButton(
                  onPressed: () {
                    context
                        .read<LoginBloc>()
                        .add(CompleteWalletGeneration(widget.wallet));
                  },
                  // text: appLocalizationsOf(context).proceed,
                  text: 'Continue',
                  fontStyle:
                      ArDriveTypography.body.smallBold700(color: Colors.white),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _onDownload() async {
    if (widget.wallet != null) {
      final jsonTxt = jsonEncode(widget.wallet!.toJwk());

      final ArDriveIO io = ArDriveIO();
      final bytes = Uint8List.fromList(utf8.encode(jsonTxt));

      await io.saveFile(await IOFile.fromData(bytes,
          name: "ardrive-wallet.json", lastModifiedDate: DateTime.now()));
    }
  }
}

class MemoryCheckView extends StatefulWidget {
  MemoryCheckView({super.key, required this.mnemonic, required this.wallet});

  final String mnemonic;
  final Wallet wallet;
  final List<MemoryCheckItem> memoryCheckItems = [];
  final List<int> selectedWords = [-1, -1, -1, -1];
  bool allWordsCorrect = false;

  @override
  State<MemoryCheckView> createState() => _MemoryCheckViewState();
}

class _MemoryCheckViewState extends State<MemoryCheckView> {
  @override
  void initState() {
    super.initState();
    _resetMemoryCheckItems();
  }

  @override
  Widget build(BuildContext context) {
    return MaxDeviceSizesConstrainedBox(
      defaultMaxHeight: 798,
      maxHeightPercent: 1,
      child: _LoginCard(
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ScreenTypeLayout(
                desktop: const SizedBox.shrink(),
                mobile: ArDriveImage(
                  image: AssetImage(Resources.images.brand.logo1),
                  height: 50,
                ),
              ),
              Text(
                // appLocalizationsOf(context).createAndConfirmPassword,
                'Select the correct words to verify your mnemonic seed phrase.',
                textAlign: TextAlign.center,
                style: ArDriveTypography.headline.headline5Regular(),
              ),
              const SizedBox(height: 16),
              ...widget.memoryCheckItems.asMap().entries.map((entry) {
                final index = entry.key;
                final selectedIndex = widget.selectedWords[index];
                final memoryCheckItem = entry.value;
                return Column(
                  children: [
                    Text(
                      'Select Word ${memoryCheckItem.mnemonicWordIndex + 1}',
                      textAlign: TextAlign.center,
                      style: ArDriveTypography.headline.headline5Regular(),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: memoryCheckItem.wordOptions
                          .asMap()
                          .entries
                          .map((entry) {
                        final wordIndex = entry.key;
                        final word = entry.value;
                        return ArDriveButton(
                          style: selectedIndex == wordIndex
                              ? ArDriveButtonStyle.primary
                              : ArDriveButtonStyle.secondary,
                          onPressed: () {
                            setState(() {
                              widget.selectedWords[index] = wordIndex;
                              _validate();
                            });
                          },
                          text: word,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              }),
              const SizedBox(height: 16),
              ArDriveButton(
                isDisabled: !widget.allWordsCorrect,
                onPressed: () {
                  showAnimatedDialog(context,
                      content: ArDriveIconModal(
                        icon: ArDriveIcons.triangle(
                          size: 88,
                          color: ArDriveTheme.of(context)
                              .themeData
                              .colors
                              .themeErrorMuted,
                        ),
                        title:
                            "You've successfully verified your mnemonic seed phrase!",
                        content:
                            "If you lose my seed phrase it cannot be retrieved but you can always use your JSON file to login. If you have not downloaded your Wallet file, please do so below, or select OK to continue.",
                        actions: [
                          ModalAction(
                            action: () {
                              _onDownload();
                            },
                            title: "Download Wallet",
                          ),
                          ModalAction(
                            action: () {
                              Navigator.pop(context);
                              context
                                  .read<LoginBloc>()
                                  .add(CompleteWalletGeneration(widget.wallet));
                            },
                            title: appLocalizationsOf(context).ok,
                          )
                        ],
                      ));

                  // context.read<LoginBloc>().add(
                  //     VerifyWalletMnemonic(widget.mnemonic, widget.wallet));
                },
                text: appLocalizationsOf(context).proceed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetMemoryCheckItems() {
    final words = widget.mnemonic.split(' ');
    final indices = List<int>.generate(words.length, (i) => i);
    indices.shuffle();

    widget.memoryCheckItems.clear();

    for (var i = 0; i < 4; i++) {
      final index = indices[i];
      final word = words[index];

      final options = [word];
      var optionsIndex = 1;
      while (optionsIndex < 3) {
        for (var randWord in bip39.generateMnemonic().split(' ')) {
          if (randWord != word) {
            options.add(randWord);
            optionsIndex++;
            if (optionsIndex >= 3) {
              break;
            }
          }
        }
      }
      options.shuffle();
      final correctIndex = options.indexOf(word);

      widget.memoryCheckItems.add(MemoryCheckItem(
          mnemonicWordIndex: index,
          wordOptions: options,
          correctWordIndex: correctIndex));
    }

    widget.selectedWords.setRange(0, 4, List<int>.generate(4, (i) => -1));
  }

  void _validate() {
    if (widget.selectedWords.every((element) => element >= 0)) {
      for (var i = 0; i < widget.selectedWords.length; i++) {
        if (widget.selectedWords[i] !=
            widget.memoryCheckItems[i].correctWordIndex) {
          setState(() {
            widget.allWordsCorrect = false;
            _resetMemoryCheckItems();
          });
          return;
        }
      }
      setState(() {
        widget.allWordsCorrect = true;
      });
    }
  }

  void _onDownload() async {
    final jsonTxt = jsonEncode(widget.wallet!.toJwk());

    final ArDriveIO io = ArDriveIO();
    final bytes = Uint8List.fromList(utf8.encode(jsonTxt));

    await io.saveFile(await IOFile.fromData(bytes,
        name: "ardrive-wallet.json", lastModifiedDate: DateTime.now()));
  }
}
