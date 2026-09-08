const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export async function onRequestOptions() {
  return new Response(null, { headers: corsHeaders });
}

export async function onRequestPost(context: any) {
  const { request, env } = context;
  const d1 = env.DB;

  try {
    const body = await request.json();
    const { action, email, password, uid } = body;

    switch (action) {
      case 'signIn':
        // Extremely simplified mock for demonstration
        if (email && password) {
          const user = { uid: email.split('@')[0], email };
          return new Response(JSON.stringify({ success: true, user }), {
            headers: { 'Content-Type': 'application/json', ...corsHeaders }
          });
        }
        break;
      
      case 'getUser':
        if (uid) {
          const userRecord = await d1.prepare('SELECT * FROM users WHERE uid = ?').bind(uid).first();
          if (userRecord) {
            return new Response(JSON.stringify({ success: true, user: userRecord }), {
              headers: { 'Content-Type': 'application/json', ...corsHeaders }
            });
          }
        }
        break;
    }
    
    return new Response(JSON.stringify({ error: 'Invalid authentication request' }), { 
      status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } 
    });

  } catch (e: any) {
    return new Response(JSON.stringify({ error: e.message || 'Internal Server Error' }), { 
      status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } 
    });
  }
}
