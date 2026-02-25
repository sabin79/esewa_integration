
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/esewa_models.dart';

class EsewaService {
  static const String baseUrl = 'http://116.203.47.221:8000/api/payment';
  
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> setAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<PaymentInitiateResponse> initiatePayment(PaymentInitiateRequest request) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/initiate/'),
        headers: headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return PaymentInitiateResponse.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['message'] ?? 'Payment initiation failed');
        }
      } else if (response.statusCode == 400) {
        final responseData = jsonDecode(response.body);
        throw Exception(responseData['message'] ?? 'Invalid payment data');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized. Please check your access token.');
      } else if (response.statusCode == 404) {
        throw Exception('Payment endpoint not found. Check your backend URL.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('NetworkException')) {
        throw Exception('Cannot connect to backend. Make sure Django server is running.');
      }
      rethrow;
    }
  }

  static Future<PaymentDetails> checkPaymentStatus(String transactionUuid) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/status/$transactionUuid/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return PaymentDetails.fromJson(responseData['data']['payment']);
        } else {
          throw Exception(responseData['message'] ?? 'Failed to check payment status');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Payment not found or endpoint not available.');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized. Please check your access token.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('NetworkException')) {
        throw Exception('Cannot connect to backend. Make sure Django server is running.');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> callDjangoSuccessEndpoint(String encodedData) async {
    try {
      final headers = await _getHeaders();
      
      // Call the existing Django success endpoint with the data parameter
      final response = await http.get(
        Uri.parse('$baseUrl/success/?data=$encodedData'),
        headers: headers,
      );

      print('🔍 Django success endpoint response status: ${response.statusCode}');
      print('🔍 Django success endpoint response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return responseData['data'];
        } else {
          throw Exception(responseData['message'] ?? 'Django success processing failed');
        }
      } else {
        throw Exception('Django success endpoint error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('NetworkException')) {
        throw Exception('Cannot connect to Django backend.');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> triggerBalanceUpdate(String transactionUuid) async {
    try {
      final headers = await _getHeaders();
      
      // First get the payment details
      final statusResponse = await http.get(
        Uri.parse('$baseUrl/status/$transactionUuid/'),
        headers: headers,
      );

      if (statusResponse.statusCode == 200) {
        final statusData = jsonDecode(statusResponse.body);
        if (statusData['status'] == 'success') {
          final paymentDetails = PaymentDetails.fromJson(statusData['data']['payment']);
          
          // If payment is COMPLETE, we need to ensure the success endpoint was called
          if (paymentDetails.status.toUpperCase() == 'COMPLETE') {
            print('💡 Payment is COMPLETE, checking if balance was updated...');
            
            // The issue is that Django success endpoint wasn't called
            // We need to somehow trigger it, but since we don't have the eSewa data,
            // let's check if there's another way
            
            return {
              'payment_details': paymentDetails,
              'needs_manual_check': true,
              'message': 'Payment is complete but balance update status unknown'
            };
          }
          
          return {
            'payment_details': paymentDetails,
            'needs_manual_check': false,
          };
        } else {
          throw Exception(statusData['message'] ?? 'Failed to get payment status');
        }
      } else {
        throw Exception('Status check failed: ${statusResponse.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<TestCredentials> getTestCredentials() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/test-credentials/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          final credentialsData = responseData['data']['credentials'];
          return TestCredentials.fromJson(credentialsData);
        } else {
          throw Exception(responseData['message'] ?? 'Failed to get test credentials');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Test credentials endpoint not found. Check your backend URL.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Check your authentication token.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('NetworkException')) {
        throw Exception('Cannot connect to backend. Make sure Django server is running.');
      }
      rethrow;
    }
  }
}