export async function onRequestGet(context: any) {
  const { request, env, params } = context;

  try {
    const bucket = env.R2_BUCKET;
    if (!bucket) {
      return new Response('R2 bucket binding not found', { status: 500 });
    }

    const segments = params.filename;
    const fileName = Array.isArray(segments) ? segments.join('/') : String(segments ?? '');
    if (!fileName) {
      return new Response('Filename is required', { status: 400 });
    }

    const object = await bucket.get(fileName);
    if (!object) {
      return new Response('File not found', { status: 404 });
    }

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set('etag', object.httpEtag);
    headers.set('Cache-Control', 'public, max-age=31536000');

    return new Response(object.body, {
      headers,
    });

  } catch (e: any) {
    return new Response(e.message || 'Internal Server Error', { status: 500 });
  }
}
