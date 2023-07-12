import 'package:ardrive/cookie_policy_consent/cookie_policy_consent.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'cookie_policy_consent_event.dart';
part 'cookie_policy_consent_state.dart';

class CookiePolicyConsentBloc
    extends Bloc<CookiePolicyConsentEvent, CookiePolicyConsentState> {
  final ArDriveCookiePolicyConsent cookiePolicyConsent;

  CookiePolicyConsentBloc(
    this.cookiePolicyConsent,
  ) : super(CookiePolicyConsentInitial()) {
    on<CookiePolicyConsentEvent>((event, emit) async {
      if (event is VerifyCookiePolicyConsent) {
        emit(VerifyingCookieConsent());

        final hasAcceptedCookiePolicyConsent =
            await cookiePolicyConsent.hasAcceptedCookiePolicy();

        if (hasAcceptedCookiePolicyConsent) {
          emit(CookiePolicyConsentAccepted());
        } else {
          emit(CookiePolicyConsentRejected());
        }
      } else if (event is AcceptCookiePolicyConsent) {
        cookiePolicyConsent.acceptCookiePolicy();
        emit(CookiePolicyConsentAccepted());
      }
    });
  }
}
