import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

String orderFailureMessage(Object error, {required String fallback}) =>
    switch (error) {
      ExV2RequestFailure failure when failure.code == 'MARKET_CLOSED' =>
        'Thị trường đang đóng cửa',
      ExV2RequestFailure failure => failure.safeDisplayMessage,
      ExV2ClientFailure failure => failure.message,
      _ => fallback,
    };
