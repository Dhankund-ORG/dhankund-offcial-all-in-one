import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export async function OPTIONS() {
  return new NextResponse(null, { headers: corsHeaders });
}

export async function POST(req: NextRequest) {
  try {
    const { env } = getRequestContext();
    const d1 = env.DB as any;

    if (!d1) {
      return NextResponse.json({ error: 'D1 database binding not found' }, { status: 500, headers: corsHeaders });
    }

    const body = await req.json();
    const { action, payload } = body as any;

    let result;
    switch (action) {
      // ---------------------------------------------
      // Overview Metrics
      // ---------------------------------------------
      case 'fetchOverviewMetrics':
        const usersCount = (await d1.prepare('SELECT COUNT(*) as count FROM users').first())?.count || 0;
        const loansCount = (await d1.prepare('SELECT COUNT(*) as count FROM loan_applications').first())?.count || 0;
        const referralsCount = (await d1.prepare('SELECT COUNT(*) as count FROM referrals').first())?.count || 0;
        const pendingApprovals = (await d1.prepare('SELECT COUNT(*) as count FROM registrations WHERE status = ?').bind('pending').first())?.count || 0;
        
        const referrals = await d1.prepare('SELECT status FROM referrals').all();
        let disbursedCommission = 0;
        let pendingCommission = 0;
        
        for (const ref of referrals.results) {
          const status = String(ref.status).toLowerCase();
          if (status === 'earned') disbursedCommission += 5000;
          else if (status === 'approved') pendingCommission += 5000;
        }

        result = {
          totalUsers: usersCount,
          totalLoans: loansCount,
          totalReferrals: referralsCount,
          pendingApprovals: pendingApprovals,
          disbursedCommission,
          pendingCommission,
        };
        break;

      // ---------------------------------------------
      // Registrations
      // ---------------------------------------------
      case 'fetchRegistrations':
        result = await d1.prepare('SELECT * FROM registrations WHERE role_type = ? ORDER BY timestamp DESC')
          .bind(payload.roleType)
          .all();
        result = result.results;
        break;

      case 'updateRegistrationStatus':
        await d1.prepare('UPDATE registrations SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
          .bind(payload.status, payload.docId)
          .run();
        
        if (String(payload.status).toLowerCase() === 'approved' && payload.uid) {
           await d1.prepare(`
             INSERT INTO users (uid, role, profile_completed, updated_at) 
             VALUES (?, ?, 1, CURRENT_TIMESTAMP)
             ON CONFLICT(uid) DO UPDATE SET role = excluded.role, profile_completed = 1, updated_at = CURRENT_TIMESTAMP
           `).bind(payload.uid, payload.role).run();
        }
        result = { success: true };
        break;

      case 'deleteUserRecord':
        if (payload.uid) {
           await d1.prepare('DELETE FROM users WHERE uid = ?').bind(payload.uid).run();
        }
        if (payload.docId) {
           await d1.prepare('DELETE FROM registrations WHERE id = ?').bind(payload.docId).run();
        }
        result = { success: true };
        break;

      // ---------------------------------------------
      // KYC & Bank Details
      // ---------------------------------------------
      case 'fetchKycBankUsers':
        result = await d1.prepare('SELECT * FROM users').all();
        result = result.results;
        break;
      
      case 'updateKycVerification':
        await d1.prepare('UPDATE users SET kyc_completed = ?, updated_at = CURRENT_TIMESTAMP WHERE uid = ?')
          .bind(payload.completed ? 1 : 0, payload.uid)
          .run();
        result = { success: true };
        break;

      case 'updateBankVerification':
        await d1.prepare('UPDATE users SET bank_details_completed = ?, updated_at = CURRENT_TIMESTAMP WHERE uid = ?')
          .bind(payload.completed ? 1 : 0, payload.uid)
          .run();
        result = { success: true };
        break;

      // ---------------------------------------------
      // Loan Applications
      // ---------------------------------------------
      case 'fetchLoanApplications':
        result = await d1.prepare('SELECT * FROM loan_applications ORDER BY submitted_at DESC').all();
        result = result.results;
        break;

      case 'updateLoanStatus':
        await d1.prepare('UPDATE loan_applications SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
          .bind(payload.status, payload.docId)
          .run();
        result = { success: true };
        break;
      
      case 'createLoanApplication':
        const loanId = crypto.randomUUID();
        await d1.prepare(`
          INSERT INTO loan_applications (
            id, loan_type, full_name, pan_number, aadhaar_number, mobile_number, email,
            loan_amount, salary, turnover, status, applicant_cibil, submitted_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        `).bind(
          loanId, payload.loanType, payload.fullName, payload.panNumber, payload.aadhaarNumber,
          payload.mobileNumber, payload.email, payload.loanAmount, payload.salary, payload.turnover,
          payload.status, payload.applicantCibil
        ).run();
        result = { id: loanId, success: true };
        break;
        
      case 'updateLoanApplication':
        await d1.prepare(`
          UPDATE loan_applications SET 
            loan_type = ?, full_name = ?, pan_number = ?, aadhaar_number = ?, 
            mobile_number = ?, email = ?, loan_amount = ?, salary = ?, turnover = ?, 
            status = ?, applicant_cibil = ?, updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
        `).bind(
          payload.loanType, payload.fullName, payload.panNumber, payload.aadhaarNumber,
          payload.mobileNumber, payload.email, payload.loanAmount, payload.salary, payload.turnover,
          payload.status, payload.applicantCibil, payload.docId
        ).run();
        result = { success: true };
        break;

      // ---------------------------------------------
      // Referrals
      // ---------------------------------------------
      case 'fetchReferrals':
        result = await d1.prepare('SELECT * FROM referrals ORDER BY created_at DESC').all();
        result = result.results;
        break;
      
      case 'updateReferralStatus':
        await d1.prepare('UPDATE referrals SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
          .bind(payload.status, payload.docId)
          .run();
        result = { success: true };
        break;

      case 'createReferral':
        const refId = crypto.randomUUID();
        await d1.prepare(`
          INSERT INTO referrals (id, referrer_id, friend_name, friend_mobile, friend_email, relationship, loan_type, estimated_amount, consent_given, status, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        `).bind(
          refId, payload.referrerId, payload.friendName, payload.friendMobile, payload.friendEmail, payload.relationship, payload.loanType, payload.estimatedAmount, payload.consentGiven ? 1 : 0, payload.status
        ).run();
        result = { id: refId, success: true };
        break;

      // ---------------------------------------------
      // Community & Admin
      // ---------------------------------------------
      case 'fetchAdminPosts':
        result = await d1.prepare('SELECT * FROM admin_posts ORDER BY timestamp DESC').all();
        result = result.results;
        break;

      case 'createAdminPost':
        const postId = crypto.randomUUID();
        await d1.prepare('INSERT INTO admin_posts (id, uid, name, title, content, image_url, timestamp) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)')
          .bind(postId, 'admin', 'Admin', payload.title, payload.content, payload.imageUrl)
          .run();
        result = { id: postId, success: true };
        break;

      case 'fetchNewsFeed':
        result = await d1.prepare('SELECT * FROM news_feed ORDER BY timestamp DESC').all();
        result = result.results;
        break;

      case 'fetchStatuses':
        result = await d1.prepare('SELECT * FROM statuses ORDER BY timestamp DESC').all();
        result = result.results;
        break;

      // ---------------------------------------------
      // Bank Policies
      // ---------------------------------------------
      case 'fetchBankPolicies':
        result = await d1.prepare('SELECT * FROM bank_policies ORDER BY updated_at DESC').all();
        result = result.results;
        break;

      case 'saveBankPolicy':
        if (payload.docId) {
          await d1.prepare(`
            UPDATE bank_policies SET 
              bank_name = ?, banker_name = ?, banker_mobile = ?, loan_type = ?, product_type = ?, 
              vertical = ?, min_cibil = ?, min_income = ?, min_ticket_size = ?, max_ticket_size = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
          `).bind(
            payload.bankName, payload.bankerName, payload.bankerMobile, payload.loanType, payload.productType,
            payload.vertical, payload.minCibil, payload.minIncome, payload.minTicketSize, payload.maxTicketSize, payload.docId
          ).run();
        } else {
          const policyId = crypto.randomUUID();
          await d1.prepare(`
            INSERT INTO bank_policies (
              id, bank_name, banker_name, banker_mobile, loan_type, product_type, vertical, min_cibil, min_income, min_ticket_size, max_ticket_size, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
          `).bind(
            policyId, payload.bankName, payload.bankerName, payload.bankerMobile, payload.loanType, payload.productType,
            payload.vertical, payload.minCibil, payload.minIncome, payload.minTicketSize, payload.maxTicketSize
          ).run();
        }
        result = { success: true };
        break;

      // ---------------------------------------------
      // Broadcast History
      // ---------------------------------------------
      case 'fetchBroadcastHistory':
        result = await d1.prepare('SELECT * FROM broadcast_history ORDER BY timestamp DESC').all();
        result = result.results;
        break;
      
      case 'createBroadcast':
        const broadcastId = crypto.randomUUID();
        await d1.prepare(`
          INSERT INTO broadcast_history (id, audiences, send_whatsapp, send_email, subject, message, recipient_count, timestamp)
          VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        `).bind(
          broadcastId, JSON.stringify(payload.audiences), payload.sendWhatsapp ? 1 : 0, payload.sendEmail ? 1 : 0, payload.subject, payload.message, payload.recipientCount
        ).run();
        result = { id: broadcastId, success: true };
        break;

      default:
        return NextResponse.json({ error: 'Invalid action' }, { status: 400, headers: corsHeaders });
    }

    return NextResponse.json({ success: true, data: result }, { headers: corsHeaders });
    
  } catch (e: any) {
    return NextResponse.json({ error: e.message || 'Internal Server Error' }, { status: 500, headers: corsHeaders });
  }
}
