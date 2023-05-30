import 'package:ardrive/blocs/turbo_balance/turbo_balance_cubit.dart';
import 'package:ardrive/misc/resources.dart';
import 'package:ardrive/services/turbo/payment_service.dart';
import 'package:ardrive/utils/app_localizations_wrapper.dart';
import 'package:ardrive/utils/winston_to_ar.dart';
import 'package:ardrive_ui/ardrive_ui.dart';
import 'package:arweave/arweave.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'top_up_dialog.dart';

class TurboBalance extends StatelessWidget {
  const TurboBalance({
    Key? key,
    required this.paymentService,
    required this.wallet,
  }) : super(key: key);

  final Wallet wallet;
  final PaymentService paymentService;

  TurboBalanceCubit get _turboBalanceCubit => TurboBalanceCubit(
        paymentService: paymentService,
        wallet: wallet,
      )..getBalance();

  addButton(BuildContext context) => SizedBox(
        height: 23,
        child: ArDriveButton(
          style: ArDriveButtonStyle.secondary,
          text: appLocalizationsOf(context).addButtonTurbo,
          fontStyle: TextStyle(
            fontSize: 13,
            color: ArDriveTheme.of(context).themeData.colors.themeFgDefault,
            fontWeight: FontWeight.w700,
          ),
          borderRadius: 20,
          onPressed: () {
            showAnimatedDialog(context, content: const TopUpDialog());
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            Resources.images.brand.turbo,
            height: 15,
            color: ArDriveTheme.of(context).themeData.colors.themeFgDefault,
            colorBlendMode: BlendMode.srcIn,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 4),
          BlocBuilder<TurboBalanceCubit, TurboBalanceState>(
              bloc: _turboBalanceCubit,
              builder: (context, state) {
                if (state is NewTurboUserState) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        flex: 3,
                        child: Text(
                          appLocalizationsOf(context).turboAddCreditsBlurb,
                          style:
                              ArDriveTypography.body.captionRegular().copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: ArDriveTheme.of(context)
                                        .themeData
                                        .colors
                                        .themeFgMuted,
                                  ),
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        child: addButton(context),
                      )
                    ],
                  );
                } else if (state is TurboBalanceSuccessState) {
                  final balance = state.balance;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${winstonToAr(balance).toStringAsFixed(5)} ${appLocalizationsOf(context).creditsTurbo}',
                        style: ArDriveTypography.body.captionRegular().copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: ArDriveTheme.of(context)
                                  .themeData
                                  .colors
                                  .themeFgSubtle,
                            ),
                      ),
                      addButton(context),
                    ],
                  );
                } else if (state is TurboBalanceLoading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  );
                } else if (state is TurboBalanceErrorState) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        appLocalizationsOf(context).error,
                        style: ArDriveTypography.body.captionRegular().copyWith(
                              fontWeight: FontWeight.w600,
                              color: ArDriveTheme.of(context)
                                  .themeData
                                  .colors
                                  .themeErrorDefault,
                            ),
                      ),
                      IconButton(
                        onPressed: () {
                          _turboBalanceCubit.getBalance();
                        },
                        icon: const Icon(Icons.refresh),
                      )
                    ],
                  );
                }
                return const SizedBox();
              }),
        ],
      ),
    );
  }
}
