import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/api_service.dart';
import 'package:my_flutter_app/presentation/customer_app/loan_selection_screen.dart';

class MyLoansScreen extends StatefulWidget {
  const MyLoansScreen({super.key});
  @override
  State<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends State<MyLoansScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _loans = [];
  bool _isLoading = true;
  Timer? _pollTimer;

  @override
  void initState() { super.initState(); _loadLoans(); _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadLoans()); }
  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }

  Future<void> _loadLoans() async {
    try {
      final list = await _api.fetchMyLoans();
      if (mounted) setState(() { _loans = list; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': case 'disbursed': return const Color(0xFF27AE60);
      case 'rejected': return Colors.redAccent;
      case 'processing': case 'in review': return Colors.blue;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(title: const Text('My Loans', style: TextStyle(color: Color(0xFF4A3AFF), fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: RefreshIndicator(
        color: const Color(0xFF4A3AFF),
        onRefresh: _loadLoans,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A3AFF)))
          : _loans.isEmpty
            ? ListView(children: [const SizedBox(height: 200), Center(child: Column(children: [Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), const Text('No loan applications yet', style: TextStyle(color: Colors.grey, fontSize: 16))]))],)
            : ListView.builder(padding: const EdgeInsets.all(20.0), itemCount: _loans.length, itemBuilder: (context, index) {
                final loan = _loans[index];
                final status = (loan['status'] ?? 'Pending').toString();
                final color = _statusColor(status);
                return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(loan['loan_type'] ?? 'Loan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)))]),
                  const SizedBox(height: 12), const Divider(),
                  const SizedBox(height: 12),
                  if ((loan['full_name'] ?? '').toString().isNotEmpty) _buildInfoRow('Applicant', loan['full_name']),
                  if ((loan['loan_amount'] ?? '').toString().isNotEmpty) _buildInfoRow('Amount', '₹${loan['loan_amount']}'),
                  if ((loan['mobile_number'] ?? '').toString().isNotEmpty) _buildInfoRow('Mobile', loan['mobile_number']),
                  _buildInfoRow('Submitted', (loan['submitted_at'] ?? '').toString().substring(0, (loan['submitted_at'] ?? '').toString().length > 10 ? 10 : (loan['submitted_at'] ?? '').toString().length)),
                ]));
              }),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoanSelectionScreen())), backgroundColor: const Color(0xFF4A3AFF), icon: const Icon(Icons.add, color: Colors.white), label: const Text('Apply New Loan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)), const SizedBox(width: 12), Flexible(child: Text(value?.toString() ?? '-', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)))]));
}
