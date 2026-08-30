import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_flutter_app/presentation/partner_app/refer_friend_form_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReferralDashboardScreen extends StatefulWidget {
  const ReferralDashboardScreen({super.key});

  @override
  State<ReferralDashboardScreen> createState() =>
      _ReferralDashboardScreenState();
}

class _ReferralDashboardScreenState extends State<ReferralDashboardScreen> {
  String _searchQuery = "";
  String _selectedStatus = "All";
  final List<String> _statuses = [
    "All",
    "Invited",
    "Submitted",
    "Approved",
    "Earned",
    "Ineligible",
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login to see referrals")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text(
          'My Referrals',
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
          icon: const Icon(Icons.logout, color: Colors.red),
          tooltip: 'Log Out',
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('biometric_enabled');
            await FirebaseAuth.instance.signOut();
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('referrals')
            .where('referrer_id', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text("Something went wrong"));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          final referrals = snapshot.data!.docs;

          // Calculate stats
          int total = referrals.length;
          int successful = referrals
              .where((doc) => doc['status'] == 'Earned')
              .length;
          int pendingRewards = referrals
              .where((doc) => doc['status'] == 'Approved')
              .length;

          // Filter by search and dropdown
          final filteredReferrals = referrals.where((doc) {
            bool matchesSearch = doc['friend_name']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
            bool matchesStatus =
                _selectedStatus == "All" || doc['status'] == _selectedStatus;
            return matchesSearch && matchesStatus;
          }).toList();

          return Column(
            children: [
              // Summary Cards
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _buildStatCard("Total", "$total", Colors.blue),
                    const SizedBox(width: 12),
                    _buildStatCard("Successful", "$successful", Colors.green),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      "Pending Rewards",
                      "$pendingRewards",
                      Colors.orange,
                    ),
                  ],
                ),
              ),

              // Search and Filter
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: "Search friend by name...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _statuses
                            .map(
                              (status) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(status),
                                  selected: _selectedStatus == status,
                                  onSelected: (val) =>
                                      setState(() => _selectedStatus = status),
                                  selectedColor: const Color(0xFF4A3AFF),
                                  labelStyle: TextStyle(
                                    color: _selectedStatus == status
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Referrals List
              Expanded(
                child: filteredReferrals.isEmpty
                    ? const Center(child: Text("No referrals found"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: filteredReferrals.length,
                        itemBuilder: (context, index) {
                          final data =
                              filteredReferrals[index].data()
                                  as Map<String, dynamic>;
                          return _buildReferralCard(data);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ReferFriendFormScreen(),
          ),
        ),
        label: const Text("Refer a New Friend"),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF4A3AFF),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCard(Map<String, dynamic> data) {
    String status = data['status'] ?? 'Invited';

    return Container(
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
                data['friend_name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['relationship'],
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              if (data['loan_type'] != null)
                Text(
                  data['loan_type'],
                  style: const TextStyle(
                    color: Color(0xFF4A3AFF),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (data['estimated_amount'] != null && data['estimated_amount'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Estimated Amount: ₹${data['estimated_amount']}',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Progress Tracker
          _buildProgressTracker(status),
        ],
      ),
    );
  }

  Widget _buildProgressTracker(String currentStatus) {
    final steps = ["Invited", "Submitted", "Approved", "Earned"];
    final stepLabels = [
      "Invited",
      "Application Submitted",
      "Loan Approved",
      "Reward Earned",
    ];
    int currentIndex = steps.indexOf(currentStatus);
    if (currentStatus == "Ineligible") currentIndex = -1;

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index % 2 != 0) {
          // Line
          int lineIndex = index ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: lineIndex < currentIndex
                  ? const Color(0xFF4A3AFF)
                  : Colors.grey.shade200,
            ),
          );
        } else {
          // Dot
          int dotIndex = index ~/ 2;
          bool isCompleted = dotIndex <= currentIndex;
          bool isCurrent = dotIndex == currentIndex;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? const Color(0xFF4A3AFF)
                      : Colors.grey.shade200,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : const SizedBox(width: 10, height: 10),
              ),
              const SizedBox(height: 4),
              Text(
                stepLabels[dotIndex],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 7,
                  color: isCurrent ? const Color(0xFF4A3AFF) : Colors.grey,
                ),
              ),
            ],
          );
        }
      }),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Invited":
        return Colors.blue;
      case "Submitted":
        return Colors.orange;
      case "Approved":
        return Colors.teal;
      case "Earned":
        return Colors.green;
      case "Ineligible":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

