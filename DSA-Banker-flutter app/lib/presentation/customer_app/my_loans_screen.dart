import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'loan_detail_screen.dart';

class MyLoansScreen extends StatefulWidget {
  const MyLoansScreen({super.key});

  @override
  State<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends State<MyLoansScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text(
          'My Loans',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A3AFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4A3AFF),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Applications'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLoanList('Active'), // Active Loans
          _buildLoanList('Applications'), // Pending Applications
          _buildLoanList('History'), // Closed or Rejected
        ],
      ),
    );
  }

  Widget _buildLoanList(String category) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return const Center(child: Text('Please login to view loans'));

    Query query = FirebaseFirestore.instance
        .collection('loan_applications')
        .where(
          'email',
          isEqualTo: user.email,
        ); // Filtering by user email for simplicity

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        // Filter locally based on category
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'Submitted';
          if (category == 'Active') return status == 'Disbursed';
          if (category == 'Applications') {
            return ['Submitted', 'Under Review', 'Approved'].contains(status);
          }
          if (category == 'History') {
            return ['Closed', 'Rejected'].contains(status);
          }
          return false;
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_late_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No $category Loans Found',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            final docId = filteredDocs[index].id;
            return _buildLoanCard(data, docId);
          },
        );
      },
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> data, String docId) {
    String status = data['status'] ?? 'Submitted';
    String loanType = data['loan_type'] ?? 'Personal Loan';
    String amount = data['loan_amount'] ?? '0';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LoanDetailScreen(loanData: data, docId: docId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loanType,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Amount: ₹$amount',
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (['Submitted', 'Under Review', 'Approved'].contains(status))
              _buildSimpleProgressTracker(status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.blue;
    if (status == 'Under Review') color = Colors.orange;
    if (status == 'Approved') color = Colors.teal;
    if (status == 'Disbursed') color = Colors.green;
    if (status == 'Rejected') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSimpleProgressTracker(String currentStatus) {
    final stages = ['Submitted', 'Under Review', 'Approved', 'Disbursed'];
    int currentIndex = stages.indexOf(currentStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status Tracker',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (currentIndex + 1) / stages.length,
          backgroundColor: Colors.grey.shade200,
          color: const Color(0xFF4A3AFF),
          minHeight: 6,
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    );
  }
}
