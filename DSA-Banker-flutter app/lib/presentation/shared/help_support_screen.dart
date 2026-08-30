import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  final String userName;

  const HelpSupportScreen({super.key, required this.userName});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _sendEmail(String emailAddress) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: emailAddress,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = userName.isNotEmpty ? userName : 'Guest';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Contact Card
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A3AFF), Color(0xFF6C5CE7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A3AFF).withOpacity(0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello $displayName,',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Welcome to Dhankund Loan Services, Indore',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'We are happy to help you here.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 20),
                  
                  // Phone Row
                  InkWell(
                    onTap: () async {
                      // Call first number
                      await _makePhoneCall('9669084666');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Call Now on',
                                  style: TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                                Text(
                                  '9669084666, 6268147177',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call, color: Colors.white, size: 16),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Email Row
                  InkWell(
                    onTap: () => _sendEmail('Info@Dhankund.com'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.mail_outline, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'E-mail us at',
                                  style: TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                                Text(
                                  'Info@Dhankund.com',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send, color: Colors.white, size: 16),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // FAQs Title Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Text(
                'Frequently Asked Questions (FAQs)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            
            // FAQs List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Column(
                children: [
                  _buildFaqCategory(
                    title: '📌 General Questions (Samanya Sawal)',
                    faqs: [
                      _FaqItem(
                        question: 'Q1. Dhankund App kya hai?',
                        answer: 'Ans: Dhankund ek digital lending platform hai jo aapko ghar baithe aasani se aur jaldi Personal aur Business loan pradan karta hai. Humara uddeshya aapki financial zaruraton ko jaldi aur bina kisi pareshani ke pura karna hai.',
                      ),
                      _FaqItem(
                        question: 'Q2. Kya mera data Dhankund App par surakshit (safe) hai?',
                        answer: 'Ans: Haan, bilkul! Aapka data humare paas 100% surakshit hai. Hum aapki jankari ko protect karne ke liye highest level of encryption (256-bit) ka upyog karte hain aur aapki details kisi bhi third-party ke sath share nahi karte.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFaqCategory(
                    title: '📌 Eligibility & Documents (Yogyata aur Dastavez)',
                    faqs: [
                      _FaqItem(
                        question: 'Q3. Loan lene ke liye eligibility criteria kya hai?',
                        answer: 'Ans: Dhankund se loan lene ke liye:\n\n• Aapki umar 21 se 60 saal ke beech honi chahiye.\n\n• Aap ek bhartiya nagrik (Indian citizen) hone chahiye.\n\n• Aapke paas har mahine aane wali ek regular income (Salary ya Business se) honi chahiye.',
                      ),
                      _FaqItem(
                        question: 'Q4. Loan apply karne ke liye kaun-kaun se documents chahiye?',
                        answer: 'Ans: Loan process bahut hi aasaan hai. Aapko sirf niche diye gaye documents upload karne honge:\n\n• Identity Proof: PAN Card\n\n• Address Proof: Aadhaar Card (OTP based e-KYC ke liye)\n\n• Income Proof: Pichle 3 se 6 mahine ka Bank Statement',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFaqCategory(
                    title: '📌 Loan Application & Approval (Loan Avedan aur Swikriti)',
                    faqs: [
                      _FaqItem(
                        question: 'Q5. Main Dhankund par loan ke liye kaise apply karu?',
                        answer: 'Ans: Loan apply karne ke step bahut aasaan hain:\n\n1. Dhankund app par apna mobile number daalkar register karein.\n2. Apni basic details bharein aur apni loan limit check karein.\n3. KYC documents (Aadhaar aur PAN) upload karein.\n4. Apna bank account link karein.\n5. Application submit karein aur approval ka wait karein!',
                      ),
                      _FaqItem(
                        question: 'Q6. Loan approve hone aur bank account me aane me kitna time lagta hai?',
                        answer: 'Ans: Application aur documents verify hone ke baad, aam taur par 2 se 24 ghante ke andar loan ka paisa aapke bank account me transfer kar diya jata hai.',
                      ),
                      _FaqItem(
                        question: 'Q7. Meri loan application reject kyu ho gayi?',
                        answer: 'Ans: Application reject hone ke kai kaaran ho sakte hain, jaise ki:\n\n• CIBIL score ka kam hona.\n• Documents ka clear (saaf) na hona ya galat hona.\n• Aapki profile humari eligibility criteria se match na karna.\n\nAap 30 din baad dobara apply kar sakte hain.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFaqCategory(
                    title: '📌 Repayment & Charges (Bhugtan aur Shulk)',
                    faqs: [
                      _FaqItem(
                        question: 'Q8. Main apna loan EMI repay (wapas) kaise kar sakta hu?',
                        answer: 'Ans: Aap Dhankund app ke \'Repayment\' section me jaakar aasani se payment kar sakte hain. Hum kai options accept karte hain jaise: UPI (PhonePe, GPay, Paytm), Debit Card, aur Net Banking. Aap Auto-Debit (e-NACH) bhi set up kar sakte hain taaki EMI apne aap bank se katt jaye.',
                      ),
                      _FaqItem(
                        question: 'Q9. Agar main EMI time par pay na karu to kya hoga?',
                        answer: 'Ans: Agar aap EMI due date tak pay nahi karte hain, toh aapke account par Late Payment Penalty charges lagaye jayenge. Iske alawa, late payment ki report Credit Bureaus (jaise CIBIL) ko di jati hai, jisse aapka credit score kharab ho sakta hai aur bhavishya mein loan lene mein pareshani ho sakti hai.',
                      ),
                      _FaqItem(
                        question: 'Q10. Kya main apna loan samay se pehle pura (foreclose) kar sakta hu?',
                        answer: 'Ans: Haan, aap apna loan samay se pehle band (foreclose) kar sakte hain. Iske liye app ke repayment section mein jakar \'Foreclosure\' ka option chunein. (Aap yahan apne terms ke hisaab se foreclosure charges ke baare mein bhi likh sakte hain).',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFaqCategory(
                    title: '📌 Customer Support (Grahak Sahayata)',
                    faqs: [
                      _FaqItem(
                        question: 'Q11. Mujhe aur jankari chahiye, main Customer Care se kaise sampark karu?',
                        answer: 'Ans: Aap kisi bhi samayatsya ke liye humse sampark kar sakte hain:\n\n• Email: support@dhankund.com\n\n• Help Section: App ke \'Help & Support\' section me jaakar apna ticket raise karein.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqCategory({required String title, required List<_FaqItem> faqs}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A3AFF),
          ),
        ),
        iconColor: const Color(0xFF4A3AFF),
        collapsedIconColor: Colors.grey,
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: faqs.map((faq) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  faq.question,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  faq.answer,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 0.5),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}
