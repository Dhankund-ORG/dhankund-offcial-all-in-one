import { getRequestContext } from '@cloudflare/next-on-pages';

export const runtime = 'edge';

export async function POST(request: Request) {
  try {
    const { env } = getRequestContext();
    const bucket = (env as any).R2_BUCKET;
    if (!bucket) {
      return new Response(JSON.stringify({ error: 'R2 bucket binding not found' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const url = new URL(request.url);
    const fileName = url.searchParams.get('filename');
    if (!fileName) {
      return new Response(JSON.stringify({ error: 'Filename is required in query params' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (fileName.includes('..') || fileName.startsWith('/')) {
      return new Response(JSON.stringify({ error: 'Invalid filename' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!request.body) {
      return new Response(JSON.stringify({ error: 'No file provided' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    await bucket.put(fileName, request.body);
    const downloadUrl = url.origin + '/api/download/' + fileName;

    return new Response(JSON.stringify({ success: true, url: downloadUrl, fileName }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e?.message || 'Internal Server Error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}
