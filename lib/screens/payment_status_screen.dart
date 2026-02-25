
import 'package:flutter/material.dart';
import '../models/esewa_models.dart';
import '../services/esewa_service.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String transactionUuid;

  const PaymentStatusScreen({Key? key, required this.transactionUuid}) : super(key: key);

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  PaymentDetails? _paymentDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkPaymentStatus();
  }

  Future<void> _checkPaymentStatus() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Use the simplified balance update trigger
      final result = await EsewaService.triggerBalanceUpdate(widget.transactionUuid);
      
      final paymentDetails = result['payment_details'] as PaymentDetails;
      final needsManualCheck = result['needs_manual_check'] as bool;
      
      setState(() {
        _paymentDetails = paymentDetails;
        _isLoading = false;
      });
      
      // Show a message if balance might need manual verification
      if (needsManualCheck && paymentDetails.status.toUpperCase() == 'COMPLETE') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💡 Payment completed! Please verify your current balance.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 5),
          ),
        );
      }
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETE':
        return Icons.check_circle;
      case 'PENDING':
        return Icons.schedule;
      case 'CANCELED':
      case 'NOT_FOUND':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkPaymentStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _checkPaymentStatus,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _paymentDetails != null
                  ? _buildPaymentDetails()
                  : const Center(child: Text('No payment details found')),
    );
  }

  Widget _buildPaymentDetails() {
    final details = _paymentDetails!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    _getStatusIcon(details.status),
                    size: 64,
                    color: _getStatusColor(details.status),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    details.status,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(details.status),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Payment ${details.status.toLowerCase()}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_paymentDetails != null && _paymentDetails!.status.toUpperCase() == 'COMPLETE')
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.green, size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment Completed Successfully!',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your balance should be updated. You can verify by checking your current balance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '💰 Amount Added: NPR ${_paymentDetails!.totalAmount}\n'
                              '📝 Transaction: ${_paymentDetails!.transactionUuid}\n'
                              '✅ Status: ${_paymentDetails!.status}'
                            ),
                            duration: const Duration(seconds: 5),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.info),
                      label: const Text('View Transaction Summary'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Transaction UUID', details.transactionUuid),
                  if (details.transactionCode != null)
                    _buildDetailRow('Transaction Code', details.transactionCode!),
                  _buildDetailRow('Amount', 'NPR ${details.amount}'),
                  if (double.parse(details.taxAmount) > 0)
                    _buildDetailRow('Tax Amount', 'NPR ${details.taxAmount}'),
                  if (double.parse(details.productServiceCharge) > 0)
                    _buildDetailRow('Service Charge', 'NPR ${details.productServiceCharge}'),
                  if (double.parse(details.productDeliveryCharge) > 0)
                    _buildDetailRow('Delivery Charge', 'NPR ${details.productDeliveryCharge}'),
                  _buildDetailRow('Total Amount', 'NPR ${details.totalAmount}', isTotal: true),
                  _buildDetailRow('User Email', details.userEmail),
                  _buildDetailRow('Created At', _formatDateTime(details.createdAt)),
                  _buildDetailRow('Updated At', _formatDateTime(details.updatedAt)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Back to Home'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                fontSize: isTotal ? 16 : 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14,
                color: isTotal ? Colors.green : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }
}