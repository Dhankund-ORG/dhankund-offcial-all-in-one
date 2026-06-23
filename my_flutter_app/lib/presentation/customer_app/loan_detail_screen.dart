import 'package:flutter/material.dart';

class LoanDetailScreen extends StatelessWidget {
  final Map<String, dynamic> loanData;
  final String docId;

  const LoanDetailScreen({
    super.key,
    required this.loanData,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    String status = loanData['status'] ?? 'Submitted';
    String loanType = loanData['loan_type'] ?? 'Personal Loan';
    String amount = loanData['loan_amount'] ?? '0';
    String rate = loanData['interest_rate'] ?? '12%';
    String nextEmiDate = loanData['next_emi_date'] ?? '05th Feb 2026';
    String emiAmount = loanData['emi_amount'] ?? '₹5,200';
    String tenure = loanData['tenure'] ?? '24 Months';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text(
          'Loan Details',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            _buildSectionHeader('Loan Identity'),
            _buildDetailCard([
              _buildDetailItem(
                'Loan ID',
                '#${docId.substring(0, 8).toUpperCase()}',
              ),
              _buildDetailItem('Loan Type', loanType),
            ]),

            const SizedBox(height: 24),
            _buildSectionHeader('Money Details'),
            _buildDetailCard([
              _buildDetailItem('Total Sanctioned', '₹$amount'),
              _buildDetailItem('Interest Rate', '$rate p.a.'),
              _buildDetailItem(
                'Total Payable',
                '₹${(double.tryParse(amount) ?? 0) * 1.2}',
              ), // Placeholder calculation
            ]),

            const SizedBox(height: 24),
            _buildSectionHeader('Repayment Info'),
            _buildRepaymentCard(nextEmiDate, emiAmount, tenure),

            const SizedBox(height: 24),
            _buildSectionHeader('Documents'),
            _buildDocumentSection(),

            const SizedBox(height: 32),
            if (status == 'Disbursed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A3AFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Pay EMI Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRepaymentCard(String date, String amount, String tenure) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A3AFF), Color(0xFF6C5CE7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Next EMI Date',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            date,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRepaymentMiniItem('EMI Amount', amount),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildRepaymentMiniItem('Remaining', tenure),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepaymentMiniItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentSection() {
    return Row(
      children: [
        Expanded(
          child: _buildDocButton('Sanction Letter', Icons.picture_as_pdf),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildDocButton('Loan Agreement', Icons.description)),
      ],
    );
  }

  Widget _buildDocButton(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF4A3AFF)),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
