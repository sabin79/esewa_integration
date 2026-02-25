import 'dart:convert';

class PaymentInitiateRequest {
  final double amount;
  final double? taxAmount;
  final double? productServiceCharge;
  final double? productDeliveryCharge;

  PaymentInitiateRequest({
    required this.amount,
    this.taxAmount,
    this.productServiceCharge,
    this.productDeliveryCharge,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount.toStringAsFixed(2),
      if (taxAmount != null) 'tax_amount': taxAmount!.toStringAsFixed(2),
      if (productServiceCharge != null) 'product_service_charge': productServiceCharge!.toStringAsFixed(2),
      if (productDeliveryCharge != null) 'product_delivery_charge': productDeliveryCharge!.toStringAsFixed(2),
    };
  }
}

class EsewaFormData {
  final String amount;
  final String taxAmount;
  final String totalAmount;
  final String transactionUuid;
  final String productCode;
  final String productServiceCharge;
  final String productDeliveryCharge;
  final String successUrl;
  final String failureUrl;
  final String signedFieldNames;
  final String signature;

  EsewaFormData({
    required this.amount,
    required this.taxAmount,
    required this.totalAmount,
    required this.transactionUuid,
    required this.productCode,
    required this.productServiceCharge,
    required this.productDeliveryCharge,
    required this.successUrl,
    required this.failureUrl,
    required this.signedFieldNames,
    required this.signature,
  });

  factory EsewaFormData.fromJson(Map<String, dynamic> json) {
    return EsewaFormData(
      amount: json['amount'] ?? '',
      taxAmount: json['tax_amount'] ?? '',
      totalAmount: json['total_amount'] ?? '',
      transactionUuid: json['transaction_uuid'] ?? '',
      productCode: json['product_code'] ?? '',
      productServiceCharge: json['product_service_charge'] ?? '',
      productDeliveryCharge: json['product_delivery_charge'] ?? '',
      successUrl: json['success_url'] ?? '',
      failureUrl: json['failure_url'] ?? '',
      signedFieldNames: json['signed_field_names'] ?? '',
      signature: json['signature'] ?? '',
    );
  }

  Map<String, String> toFormParams() {
    return {
      'amount': amount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'transaction_uuid': transactionUuid,
      'product_code': productCode,
      'product_service_charge': productServiceCharge,
      'product_delivery_charge': productDeliveryCharge,
      'success_url': successUrl,
      'failure_url': failureUrl,
      'signed_field_names': signedFieldNames,
      'signature': signature,
    };
  }
}

class PaymentDetails {
  final String id;
  final String transactionUuid;
  final String amount;
  final String taxAmount;
  final String productServiceCharge;
  final String productDeliveryCharge;
  final String totalAmount;
  final String productCode;
  final String status;
  final String? transactionCode;
  final String? refId;
  final String createdAt;
  final String updatedAt;
  final String userEmail;

  PaymentDetails({
    required this.id,
    required this.transactionUuid,
    required this.amount,
    required this.taxAmount,
    required this.productServiceCharge,
    required this.productDeliveryCharge,
    required this.totalAmount,
    required this.productCode,
    required this.status,
    this.transactionCode,
    this.refId,
    required this.createdAt,
    required this.updatedAt,
    required this.userEmail,
  });

  factory PaymentDetails.fromJson(Map<String, dynamic> json) {
    return PaymentDetails(
      id: json['id'] ?? '',
      transactionUuid: json['transaction_uuid'] ?? '',
      amount: json['amount']?.toString() ?? '',
      taxAmount: json['tax_amount']?.toString() ?? '',
      productServiceCharge: json['product_service_charge']?.toString() ?? '',
      productDeliveryCharge: json['product_delivery_charge']?.toString() ?? '',
      totalAmount: json['total_amount']?.toString() ?? '',
      productCode: json['product_code'] ?? '',
      status: json['status'] ?? '',
      transactionCode: json['transaction_code'],
      refId: json['ref_id'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      userEmail: json['user_email'] ?? '',
    );
  }
}

class PaymentInitiateResponse {
  final String paymentId;
  final String transactionUuid;
  final String esewaPaymentUrl;
  final EsewaFormData esewaFormData;
  final PaymentDetails paymentDetails;
  final String environment;
  final Map<String, dynamic>? testCredentials;

  PaymentInitiateResponse({
    required this.paymentId,
    required this.transactionUuid,
    required this.esewaPaymentUrl,
    required this.esewaFormData,
    required this.paymentDetails,
    required this.environment,
    this.testCredentials,
  });

  factory PaymentInitiateResponse.fromJson(Map<String, dynamic> json) {
    return PaymentInitiateResponse(
      paymentId: json['payment_id'] ?? '',
      transactionUuid: json['transaction_uuid'] ?? '',
      esewaPaymentUrl: json['esewa_payment_url'] ?? '',
      esewaFormData: EsewaFormData.fromJson(json['esewa_form_data'] ?? {}),
      paymentDetails: PaymentDetails.fromJson(json['payment_details'] ?? {}),
      environment: json['environment'] ?? 'testing',
      testCredentials: json['test_credentials'],
    );
  }
}

class TestCredentials {
  final List<String> esewaIds;
  final String password;
  final String mpin;
  final String token;

  TestCredentials({
    required this.esewaIds,
    required this.password,
    required this.mpin,
    required this.token,
  });

  factory TestCredentials.fromJson(Map<String, dynamic> json) {
    return TestCredentials(
      esewaIds: List<String>.from(json['esewa_ids'] ?? []),
      password: json['password'] ?? '',
      mpin: json['mpin'] ?? '',
      token: json['token'] ?? '',
    );
  }
}
