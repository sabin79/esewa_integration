import 'dart:developer';

import 'package:flutter/material.dart';
import '../models/esewa_models.dart';
import '../services/esewa_service.dart';
import 'esewa_payment_webview.dart';
import 'payment_status_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _taxAmountController = TextEditingController();
  final _serviceChargeController = TextEditingController();
  final _deliveryChargeController = TextEditingController();
  final _tokenController = TextEditingController();
  
  bool _isLoading = false;
  TestCredentials? _testCredentials;
  PaymentInitiateResponse? _paymentResponse;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedToken();
    _loadTestCredentials();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _taxAmountController.dispose();
    _serviceChargeController.dispose();
    _deliveryChargeController.dispose();
    _tokenController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedToken() async {
    final token = await EsewaService.getAccessToken();
    if (token != null) {
      _tokenController.text = token;
    }
  }

  Future<void> _loadTestCredentials() async {
    try {
      final token = await EsewaService.getAccessToken();
      if (token == null || token.isEmpty) {
        return;
      }
      
      final credentials = await EsewaService.getTestCredentials();
      setState(() {
        _testCredentials = credentials;
      });
    } catch (e) {
      print('Failed to load test credentials: $e');
    }
  }

  Future<void> _saveToken() async {
    if (_tokenController.text.isNotEmpty) {
      await EsewaService.setAccessToken(_tokenController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access token saved!')),
      );
    }
  }

  double get _calculatedTotal {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final tax = double.tryParse(_taxAmountController.text) ?? 0;
    final service = double.tryParse(_serviceChargeController.text) ?? 0;
    final delivery = double.tryParse(_deliveryChargeController.text) ?? 0;
    return amount + tax + service + delivery;
  }

  Future<void> _initiatePayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter access token')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _saveToken();
      
      final request = PaymentInitiateRequest(
        amount: double.parse(_amountController.text),
        taxAmount: _taxAmountController.text.isNotEmpty ? double.parse(_taxAmountController.text) : null,
        productServiceCharge: _serviceChargeController.text.isNotEmpty ? double.parse(_serviceChargeController.text) : null,
        productDeliveryCharge: _deliveryChargeController.text.isNotEmpty ? double.parse(_deliveryChargeController.text) : null,
      );

      final response = await EsewaService.initiatePayment(request);
      
      setState(() {
        _paymentResponse = response;
        _isLoading = false;
      });

      // Show payment URLs for debugging
      print('🔗 Payment URLs:');
      print('   Success: ${response.esewaFormData.successUrl}');
      log(response.toString(), name: 'esewaPaymentUrl');
      print('   Failure: ${response.esewaFormData.failureUrl}');
      print('   Transaction: ${response.esewaFormData.transactionUuid}');

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EsewaPaymentWebView(
              paymentResponse: response,
              onPaymentComplete: _handlePaymentComplete,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _handlePaymentComplete(bool success, String? transactionUuid) {
    print('🎯 Payment completion detected:');
    print('   Success: $success');
    print('   Transaction UUID: $transactionUuid');
    
    if (success && transactionUuid != null) {
      // Payment was successful - show success message and navigate to status
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Payment successful! Your balance should be updated.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentStatusScreen(transactionUuid: transactionUuid),
        ),
      );
    } else if (!success && transactionUuid != null) {
      // Payment failed - show error and option to check status
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Payment failed or was cancelled'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Still navigate to status screen to show details
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentStatusScreen(transactionUuid: transactionUuid),
        ),
      );
    } else {
      // No transaction UUID available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Payment process incomplete. Please check manually.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eSewa Payment'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Payment'),
            Tab(text: 'Test Info'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPaymentTab(),
          _buildTestInfoTab(),
        ],
      ),
    );
  }

  Widget _buildPaymentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Access Token',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tokenController,
                      decoration: const InputDecoration(
                        labelText: 'JWT Access Token',
                        hintText: 'Enter your authentication token',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.security),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter access token' : null,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _saveToken,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Token'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Payment Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount *',
                        hintText: 'Enter amount (min: 1.00)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.money),
                        suffixText: 'NPR',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Please enter amount';
                        final amount = double.tryParse(value!);
                        if (amount == null || amount < 1) return 'Amount must be at least 1.00';
                        return null;
                      },
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _taxAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Tax Amount',
                        hintText: 'Enter tax amount (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance),
                        suffixText: 'NPR',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _serviceChargeController,
                      decoration: const InputDecoration(
                        labelText: 'Service Charge',
                        hintText: 'Enter service charge (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.build),
                        suffixText: 'NPR',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _deliveryChargeController,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Charge',
                        hintText: 'Enter delivery charge (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_shipping),
                        suffixText: 'NPR',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'NPR ${_calculatedTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _initiatePayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Pay with eSewa', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Need to Check Payment Status?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('After completing payment in browser:'),
                    const Text('1. Return to this app'),
                    const Text('2. Enter your transaction UUID in the status checker'),
                    const Text('3. View real-time payment status'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PaymentStatusChecker(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Check Payment Status'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Testing Environment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_testCredentials != null) ...[
                    const Text('Test eSewa IDs:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._testCredentials!.esewaIds.map((id) => 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 16),
                            const SizedBox(width: 8),
                            Text(id),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Copied: $id')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCredentialRow('Password:', _testCredentials!.password),
                    _buildCredentialRow('MPIN:', _testCredentials!.mpin),
                    _buildCredentialRow('Token:', _testCredentials!.token),
                  ] else ...[
                    const Icon(Icons.warning, color: Colors.orange, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Test credentials not available',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Please ensure:'),
                    const Text('• You have entered a valid access token'),
                    const Text('• Your backend server is running'),
                    const Text('• The test-credentials endpoint is working'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadTestCredentials,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instructions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('1. Use any of the test eSewa IDs above'),
                  const Text('2. Enter the provided password when prompted'),
                  const Text('3. Use the MPIN for authorization'),
                  const Text('4. Always use token: 123456 for testing'),
                  const Text('5. Payment will be processed in test mode'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Text(value),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied: $value')),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Payment Status Checker Widget
class PaymentStatusChecker extends StatefulWidget {
  const PaymentStatusChecker({Key? key}) : super(key: key);

  @override
  State<PaymentStatusChecker> createState() => _PaymentStatusCheckerState();
}

class _PaymentStatusCheckerState extends State<PaymentStatusChecker> {
  final _uuidController = TextEditingController();
  bool _isLoading = false;
  PaymentDetails? _paymentDetails;
  String? _error;

  @override
  void dispose() {
    _uuidController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (_uuidController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a transaction UUID');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _paymentDetails = null;
    });

    try {
      final details = await EsewaService.checkPaymentStatus(_uuidController.text.trim());
      setState(() {
        _paymentDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check Payment Status'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter Transaction UUID',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _uuidController,
                      decoration: const InputDecoration(
                        labelText: 'Transaction UUID',
                        hintText: 'e.g., 250713-114500-A1B2C3D4',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _checkStatus,
                        icon: _isLoading 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                            )
                          : const Icon(Icons.search),
                        label: Text(_isLoading ? 'Checking...' : 'Check Status'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              ),
            if (_paymentDetails != null)
              Expanded(
                child: PaymentStatusScreen(transactionUuid: _paymentDetails!.transactionUuid),
              ),
          ],
        ),
      ),
    );
  }
}