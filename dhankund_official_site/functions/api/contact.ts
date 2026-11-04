const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

// Where contact enquiries are delivered (inbox you already publish on the site).
const DESTINATION_EMAIL = "info@dhankund.com";
// Verified sender address on the dhankund.com domain. Make sure this address is
// verified in Cloudflare Email Routing / Email Service, otherwise sending fails
// with E_SENDER_NOT_VERIFIED.
const SENDER_EMAIL = "noreply@dhankund.com";

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

export async function onRequestOptions() {
  return new Response(null, { headers: corsHeaders });
}

interface ContactBody {
  firstName?: string;
  lastName?: string;
  mobile?: string;
  email?: string;
  message?: string;
}

export async function onRequestPost(context: { request: Request; env: Record<string, unknown> }) {
  const { request, env } = context;

  let body: ContactBody;
  try {
    body = (await request.json()) as ContactBody;
  } catch {
    return json({ error: "Invalid request body." }, 400);
  }

  const firstName = (body.firstName ?? "").toString().trim();
  const lastName = (body.lastName ?? "").toString().trim();
  const mobile = (body.mobile ?? "").toString().trim();
  const email = (body.email ?? "").toString().trim();
  const message = (body.message ?? "").toString().trim();

  if (!firstName || !mobile || !email || !message) {
    return json({ error: "Please fill in your name, mobile number, email, and message." }, 400);
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json({ error: "Please enter a valid email address." }, 400);
  }

  const sendEmail = env.SEB as
    | { send: (msg: Record<string, unknown>) => Promise<unknown> }
    | undefined;

  const fullName = [firstName, lastName].filter(Boolean).join(" ");
  const subject = `New contact enquiry from ${fullName}`;
  const textBody =
    `New contact enquiry received from the Dhankund website.\n\n` +
    `Name: ${fullName}\n` +
    `Mobile: ${mobile}\n` +
    `Email: ${email}\n\n` +
    `Message:\n${message}\n`;

  const htmlBody =
    `<h2>New contact enquiry</h2>` +
    `<p>A visitor submitted the contact form on the Dhankund website.</p>` +
    `<p><strong>Name:</strong> ${escapeHtml(fullName)}<br/>` +
    `<strong>Mobile:</strong> ${escapeHtml(mobile)}<br/>` +
    `<strong>Email:</strong> ${escapeHtml(email)}</p>` +
    `<p><strong>Message:</strong></p>` +
    `<blockquote>${escapeHtml(message).replace(/\n/g, "<br/>")}</blockquote>`;

  const reqHost = new URL(request.url).hostname;
  const apiBase =
    reqHost.includes("dev.") || reqHost.includes("preview")
      ? "https://dev.api.dhankund.com"
      : "https://api.dhankund.com";

  // Directly push lead to Dhankund CRM Payouts & Referrals ecosystem as a Website Lead
  let crmSynced = false;
  try {
    const crmRes = await fetch(`${apiBase}/api/v1/contact-lead`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ firstName, lastName, mobile, email, message }),
    });
    crmSynced = crmRes.ok;
  } catch (crmErr) {
    console.warn("CRM lead sync warning:", crmErr);
  }

  try {
    if (sendEmail && typeof sendEmail.send === "function") {
      await sendEmail.send({
        to: DESTINATION_EMAIL,
        from: SENDER_EMAIL,
        replyTo: email,
        subject,
        text: textBody,
        html: htmlBody,
      });
    } else if (!crmSynced) {
      console.error("SEB send_email binding is not configured and CRM sync did not complete");
      return json({ error: "Email service is not configured on the server." }, 500);
    }

    return json({ success: true, crm_synced: crmSynced });
  } catch (e: unknown) {
    const err = e as { code?: string; message?: string };
    console.error("Email send failed:", err.code, err.message);
    if (crmSynced) {
      return json({ success: true, crm_synced: true });
    }
    return json({ error: "Could not send your message. Please try again later." }, 500);
  }
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
