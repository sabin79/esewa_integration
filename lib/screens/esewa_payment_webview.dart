import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../models/esewa_models.dart';
import '../services/esewa_service.dart';
import 'payment_status_screen.dart';

class EsewaPaymentWebView extends StatefulWidget {
  final PaymentInitiateResponse paymentResponse;
  final Function(bool success, String? transactionUuid) onPaymentComplete;

  const EsewaPaymentWebView({
    Key? key,
    required this.paymentResponse,
    required this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<EsewaPaymentWebView> createState() => _EsewaPaymentWebViewState();
}

class _EsewaPaymentWebViewState extends State<EsewaPaymentWebView> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _webViewError = false;
  String? _errorMessage;
  bool _isLinux = Platform.isLinux;

  @override
  void initState() {
    super.initState();
    if (_isLinux) {
      setState(() {
        _webViewError = true;
        _errorMessage = 'WebView is not fully supported on Linux desktop';
        _isLoading = false;
      });
    } else {
      _initializeWebView();
    }
  }

  void _initializeWebView() {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() => _isLoading = true);
            },
            onPageFinished: (String url) {
              setState(() => _isLoading = false);
              _checkPaymentResult(url);
            },
            onNavigationRequest: (NavigationRequest request) {
              _checkPaymentResult(request.url);
              return NavigationDecision.navigate;
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _webViewError = true;
                _errorMessage = error.description;
                _isLoading = false;
              });
            },
          ),
        );
      
      _loadPaymentPage();
    } catch (e) {
      setState(() {
        _webViewError = true;
        _errorMessage = 'WebView not supported on this platform';
        _isLoading = false;
      });
    }
  }

  void _loadPaymentPage() {
    if (_controller != null) {
      try {
        final formData = widget.paymentResponse.esewaFormData;
        final params = formData.toFormParams();
        
        final postData = params.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        
        _controller!.loadRequest(
          Uri.parse(widget.paymentResponse.esewaPaymentUrl),
          method: LoadRequestMethod.post,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: utf8.encode(postData),
        );
      } catch (e) {
        setState(() {
          _webViewError = true;
          _errorMessage = 'Failed to load payment page';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    try {
      final formData = widget.paymentResponse.esewaFormData;
      
      final htmlForm = '''
<!DOCTYPE html>
<html>
<head>
    <title>eSewa Payment</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .loading { margin: 20px; }
    </style>
</head>
<body>
    <h2>Redirecting to eSewa Payment...</h2>
    <div class="loading">Please wait while we redirect you to eSewa.</div>
    <form id="esewaForm" action="${widget.paymentResponse.esewaPaymentUrl}" method="POST">
        <input type="hidden" name="amount" value="${formData.amount}">
        <input type="hidden" name="tax_amount" value="${formData.taxAmount}">
        <input type="hidden" name="total_amount" value="${formData.totalAmount}">
        <input type="hidden" name="transaction_uuid" value="${formData.transactionUuid}">
        <input type="hidden" name="product_code" value="${formData.productCode}">
        <input type="hidden" name="product_service_charge" value="${formData.productServiceCharge}">
        <input type="hidden" name="product_delivery_charge" value="${formData.productDeliveryCharge}">
        <input type="hidden" name="success_url" value="${formData.successUrl}">
        <input type="hidden" name="failure_url" value="${formData.failureUrl}">
        <input type="hidden" name="signed_field_names" value="${formData.signedFieldNames}">
        <input type="hidden" name="signature" value="${formData.signature}">
        <input type="submit" value="Continue to eSewa" style="background: #60A85F; color: white; padding: 15px 30px; border: none; border-radius: 5px; font-size: 16px; cursor: pointer;">
    </form>
    <script>
        setTimeout(function() {
            document.getElementById('esewaForm').submit();
        }, 3000);
    </script>
</body>
</html>
      ''';
      
      final dataUrl = Uri.dataFromString(
        htmlForm,
        mimeType: 'text/html',
        encoding: Encoding.getByName('utf-8'),
      );
      
      if (await canLaunchUrl(dataUrl)) {
        await launchUrl(dataUrl, mode: LaunchMode.externalApplication);
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Payment Opened in Browser'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_browser, size: 48, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'eSewa payment page has been opened in your browser.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        const Text('Transaction UUID:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        SelectableText(
                          formData.transactionUuid,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Save this UUID to check payment status later!',
                          style: TextStyle(fontSize: 11, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'After payment completion, return to this app to check status.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showPaymentTrackingDialog();
                  },
                  child: const Text('Track Payment'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Return to App'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Could not launch payment URL');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open payment page: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPaymentTrackingDialog() {
    showDialog(
      context: context,
      builder: (context) => PaymentTrackingDialog(
        transactionUuid: widget.paymentResponse.esewaFormData.transactionUuid,
        onPaymentComplete: widget.onPaymentComplete,
      ),
    );
  }

  void _checkPaymentResult(String url) {
    final formData = widget.paymentResponse.esewaFormData;
    
    print('🔍 Checking URL: $url');
    print('🔍 Success URL: ${formData.successUrl}');
    print('🔍 Failure URL: ${formData.failureUrl}');
    
    // Parse the current URL
    final currentUri = Uri.tryParse(url);
    final successUri = Uri.tryParse(formData.successUrl);
    final failureUri = Uri.tryParse(formData.failureUrl);
    
    if (currentUri != null && successUri != null && failureUri != null) {
      // Check if we're on the success URL
      if (_isUrlMatch(currentUri, successUri)) {
        print('✅ SUCCESS URL detected!');
        
        // Extract query parameters to get the eSewa data
        final queryParams = currentUri.queryParameters;
        print('🔍 Success URL params: $queryParams');
        
        // Check if we have the encoded data from eSewa
        if (queryParams.containsKey('data')) {
          print('📦 Found eSewa data parameter - calling Django success endpoint...');
          _callDjangoSuccessEndpoint(queryParams['data']!);
          return;
        } else {
          print('⚠️ No data parameter found - checking payment status...');
          _checkFinalPaymentStatus(true);
          return;
        }
      }
      
      // Check if we're on the failure URL
      if (_isUrlMatch(currentUri, failureUri)) {
        print('❌ FAILURE URL detected!');
        widget.onPaymentComplete(false, formData.transactionUuid);
        return;
      }
    }
    
    // Fallback: check if URL contains success/failure indicators
    final urlLower = url.toLowerCase();
    if (urlLower.contains('success') || urlLower.contains('complete')) {
      print('✅ SUCCESS keyword detected in URL');
      _checkFinalPaymentStatus(true);
    } else if (urlLower.contains('failure') || urlLower.contains('cancel') || urlLower.contains('error')) {
      print('❌ FAILURE keyword detected in URL');
      widget.onPaymentComplete(false, formData.transactionUuid);
    }
  }

  Future<void> _callDjangoSuccessEndpoint(String encodedData) async {
    try {
      print('🚀 Calling Django success endpoint with eSewa data...');
      
      // This will trigger your existing Django PaymentSuccessAPIView.get() method
      // which processes the payment and updates the balance
      final result = await EsewaService.callDjangoSuccessEndpoint(encodedData);
      
      print('✅ Django success endpoint called successfully!');
      print('🔍 Result: $result');
      
      // Payment should now be processed and balance updated
      widget.onPaymentComplete(true, widget.paymentResponse.esewaFormData.transactionUuid);
      
    } catch (e) {
      print('❌ Error calling Django success endpoint: $e');
      
      // Fallback: still mark as success but let user check status manually
      widget.onPaymentComplete(true, widget.paymentResponse.esewaFormData.transactionUuid);
    }
  }

  Future<void> _checkFinalPaymentStatus(bool expectedSuccess) async {
    try {
      print('🔍 Checking final payment status...');
      
      final result = await EsewaService.triggerBalanceUpdate(
        widget.paymentResponse.esewaFormData.transactionUuid
      );
      
      final paymentDetails = result['payment_details'] as PaymentDetails;
      bool actualSuccess = paymentDetails.status.toUpperCase() == 'COMPLETE';
      
      print('✅ Payment status check complete');
      print('🔍 Status: ${paymentDetails.status}');
      print('🔍 Actual success: $actualSuccess');
      
      if (actualSuccess && result['needs_manual_check'] == true) {
        // Show a warning that balance might not be updated
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Payment completed but please verify your balance'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      widget.onPaymentComplete(actualSuccess, paymentDetails.transactionUuid);
      
    } catch (e) {
      print('❌ Error checking payment status: $e');
      widget.onPaymentComplete(expectedSuccess, widget.paymentResponse.esewaFormData.transactionUuid);
    }
  }

  bool _isUrlMatch(Uri current, Uri target) {
    // Check if scheme, host, and path match
    return current.scheme == target.scheme &&
           current.host == target.host &&
           current.path == target.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eSewa Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => widget.onPaymentComplete(false, null),
        ),
        actions: [
          if (_webViewError)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              onPressed: _openInBrowser,
              tooltip: 'Open in Browser',
            ),
        ],
      ),
      body: _webViewError ? _buildErrorView() : _buildWebView(),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
        if (_isLoading)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading eSewa payment page...'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isLinux ? Icons.desktop_windows : Icons.error_outline,
              size: 64,
              color: _isLinux ? Colors.blue : Colors.orange,
            ),
            const SizedBox(height: 24),
            Text(
              _isLinux ? 'Desktop Payment' : 'WebView Not Available',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              _isLinux 
                ? 'On Linux desktop, payments work best in your default browser.'
                : (_errorMessage ?? 'WebView is not supported on this platform.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'Complete your eSewa payment securely in your browser.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_browser),
                label: Text(_isLinux ? 'Open eSewa Payment' : 'Open Payment in Browser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel Payment'),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  const Icon(Icons.info, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    _isLinux 
                      ? 'After completing payment in your browser, return here to check payment status in the app.'
                      : 'After completing payment in browser, you can check the payment status in the app.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
            ),
            if (_isLinux) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.desktop_windows, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This works perfectly on Linux desktop!',
                        style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Payment Tracking Dialog for browser payments
class PaymentTrackingDialog extends StatefulWidget {
  final String transactionUuid;
  final Function(bool success, String? transactionUuid) onPaymentComplete;

  const PaymentTrackingDialog({
    Key? key,
    required this.transactionUuid,
    required this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<PaymentTrackingDialog> createState() => _PaymentTrackingDialogState();
}

class _PaymentTrackingDialogState extends State<PaymentTrackingDialog> {
  bool _isChecking = false;
  String? _currentStatus;
  int _checkCount = 0;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    _startAutoCheck();
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  void _startAutoCheck() {
    // Check immediately
    _checkPaymentStatus();
    
    // Then check every 10 seconds for up to 5 minutes
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkCount++;
      if (_checkCount >= 30) { // 5 minutes
        timer.cancel();
        return;
      }
      _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_isChecking) return;
    
    setState(() => _isChecking = true);
    
    try {
      // Check payment status using the simplified approach
      final result = await EsewaService.triggerBalanceUpdate(widget.transactionUuid);
      
      final paymentDetails = result['payment_details'] as PaymentDetails;
      final needsManualCheck = result['needs_manual_check'] as bool;
      
      setState(() {
        _currentStatus = needsManualCheck 
          ? '${paymentDetails.status} (Check Balance)'
          : paymentDetails.status;
        _isChecking = false;
      });
      
      print('🔍 Payment status: ${paymentDetails.status}');
      print('🔍 Needs manual check: $needsManualCheck');
      
      // If payment is complete, stop checking and notify
      if (paymentDetails.status.toUpperCase() == 'COMPLETE') {
        _autoCheckTimer?.cancel();
        Navigator.of(context).pop();
        widget.onPaymentComplete(true, widget.transactionUuid);
      } else if (paymentDetails.status.toUpperCase() == 'CANCELED' || 
                 paymentDetails.status.toUpperCase() == 'NOT_FOUND') {
        _autoCheckTimer?.cancel();
        Navigator.of(context).pop();
        widget.onPaymentComplete(false, widget.transactionUuid);
      }
    } catch (e) {
      setState(() => _isChecking = false);
      print('Error checking payment status: $e');
      
      // Fallback to basic status check
      try {
        final details = await EsewaService.checkPaymentStatus(widget.transactionUuid);
        setState(() => _currentStatus = details.status);
        
        if (details.status.toUpperCase() == 'COMPLETE') {
          _autoCheckTimer?.cancel();
          Navigator.of(context).pop();
          widget.onPaymentComplete(true, widget.transactionUuid);
        }
      } catch (fallbackError) {
        print('Fallback status check also failed: $fallbackError');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Payment Tracking'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.track_changes, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Tracking your payment...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text('Transaction UUID:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                SelectableText(
                  widget.transactionUuid,
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isChecking) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                _currentStatus != null 
                  ? 'Status: ${_currentStatus!.toUpperCase()}'
                  : 'Checking payment status...',
                style: TextStyle(
                  color: _getStatusColor(_currentStatus ?? 'PENDING'),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Complete your payment in the browser, then return here. We\'ll automatically detect when it\'s done!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _checkPaymentStatus(),
          child: const Text('Check Now'),
        ),
        TextButton(
          onPressed: () {
            _autoCheckTimer?.cancel();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETE':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'CANCELED':
      case 'NOT_FOUND':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}