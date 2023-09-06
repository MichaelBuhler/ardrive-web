import 'package:ardrive/turbo/topup/models/price_estimate.dart';
import 'package:ardrive/turbo/turbo.dart';
import 'package:ardrive/utils/logger/logger.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'payment_form_event.dart';
part 'payment_form_state.dart';

class PaymentFormBloc extends Bloc<PaymentFormEvent, PaymentFormState> {
  final Turbo turbo;
  // String _promoCode = '';
  // final TextEditingController _promoCodeController = TextEditingController();

  PaymentFormBloc(this.turbo, PriceEstimate initialPriceEstimation)
      : super(PaymentFormInitial(initialPriceEstimation,
            _expirationTimeInSeconds(turbo.maxQuoteExpirationDate))) {
    on<PaymentFormLoadSupportedCountries>(_handleLoadSupportedCountries);
    on<PaymentFormUpdateQuote>(_handleUpdateQuote);
    on<PaymentFormUpdatePromoCode>(_handleUpdatePromoCode);
  }

  Future<void> _handleLoadSupportedCountries(
    PaymentFormLoadSupportedCountries event,
    Emitter<PaymentFormState> emit,
  ) async {
    emit(PaymentFormLoading(
      state.priceEstimate,
      _expirationTimeInSeconds(turbo.maxQuoteExpirationDate),
    ));

    try {
      final supportedCountries = await turbo.getSupportedCountries();

      emit(
        PaymentFormLoaded(
          state.priceEstimate,
          _expirationTimeInSeconds(turbo.maxQuoteExpirationDate),
          supportedCountries,
        ),
      );
    } catch (e) {
      logger.e('Error loading the supported countries.', e);

      emit(
        PaymentFormError(
          state.priceEstimate,
          _expirationTimeInSeconds(turbo.maxQuoteExpirationDate),
        ),
      );
    }
  }

  Future<void> _handleUpdateQuote(
    PaymentFormUpdateQuote event,
    Emitter<PaymentFormState> emit,
  ) async {
    emit(
      PaymentFormLoadingQuote(
        state.priceEstimate,
        _expirationTimeInSeconds(
          turbo.maxQuoteExpirationDate,
        ),
        (state as PaymentFormLoaded).supportedCountries,
      ),
    );

    try {
      final priceEstimate = await turbo.refreshPriceEstimate();

      emit(
        PaymentFormQuoteLoaded(
          priceEstimate,
          _expirationTimeInSeconds(turbo.maxQuoteExpirationDate),
          (state as PaymentFormLoaded).supportedCountries,
        ),
      );
    } catch (e, s) {
      logger.e('Error upading the quote.', e, s);

      emit(
        PaymentFormQuoteLoadFailure(
          state.priceEstimate,
          _expirationTimeInSeconds(turbo.maxQuoteExpirationDate),
        ),
      );
    }
  }

  void _handleUpdatePromoCode(
    PaymentFormUpdatePromoCode event,
    Emitter<PaymentFormState> emit,
  ) async {
    final promoCode = event.promoCode;

    logger.d('Updating promo code to $promoCode.');

    emit(
      PaymentFormLoaded(
        state.priceEstimate,
        _expirationTimeInSeconds(turbo.maxQuoteExpirationDate),
        (state as PaymentFormLoaded).supportedCountries,
        isFetchingPromoCode: true,
      ),
    );

    try {
      final promoDiscountFactor = await turbo.getPromoDiscountFactor(promoCode);
      final isInvalid = promoDiscountFactor == null;

      logger.d('Promo code $promoCode is ${isInvalid ? 'in' : ''}'
          'valid: $promoDiscountFactor.');

      emit(
        PaymentFormLoaded(
          state.priceEstimate,
          _expirationTimeInSeconds(turbo.maxQuoteExpirationDate),
          (state as PaymentFormLoaded).supportedCountries,
          promoDiscountFactor: promoDiscountFactor,
          isPromoCodeInvalid: isInvalid,
          isFetchingPromoCode: false,
        ),
      );
    } catch (e) {
      logger.e('Error fetching the promo code.', e);

      emit(
        PaymentFormLoaded(
          state.priceEstimate,
          _expirationTimeInSeconds(turbo.maxQuoteExpirationDate),
          (state as PaymentFormLoaded).supportedCountries,
          isPromoCodeInvalid: false,
          isFetchingPromoCode: false,
          errorFetchingPromoCode: true,
        ),
      );
    }
  }
}

int _expirationTimeInSeconds(DateTime d) =>
    d.difference(DateTime.now()).inSeconds;
