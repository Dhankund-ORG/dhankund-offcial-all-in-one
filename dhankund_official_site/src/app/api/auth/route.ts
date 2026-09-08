import { NextRequest, NextResponse } from 'next/server';
import { getRequestContext } from '@cloudflare/next-on-pages';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
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
    const { action, email, password, uid } = body as any;

    switch (action) {
      case 'signIn':
        // Extremely simplified mock for demonstration
        if (email && password) {
          const user = { uid: email.split('@')[0], email };
          return NextResponse.json({ success: true, user }, { headers: corsHeaders });
        }
        break;
      
      case 'getUser':
        if (uid) {
          const userRecord = await d1.prepare('SELECT * FROM users WHERE uid = ?').bind(uid).first();
          if (userRecord) {
            return NextResponse.json({ success: true, user: userRecord }, { headers: corsHeaders });
          }
        }
        break;
    }
    
    return NextResponse.json({ error: 'Invalid authentication request' }, { status: 401, headers: corsHeaders });

  } catch (e: any) {
    return NextResponse.json({ error: e.message || 'Internal Server Error' }, { status: 500, headers: corsHeaders });
  }
}
