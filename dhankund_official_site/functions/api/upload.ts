const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export async function onRequestOptions() {
  return new Response(null, {
    headers: corsHeaders,
  });
}

export async function onRequestPost(context: any) {
  const { request, env } = context;
  
  try {
    const bucket = env.R2_BUCKET;
    if (!bucket) {
      return new Response(JSON.stringify({ error: 'R2 bucket binding not found' }), { 
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      });
    }

    const url = new URL(request.url);
    const fileName = url.searchParams.get('filename');
    
    if (!fileName) {
      return new Response(JSON.stringify({ error: 'Filename is required in query params' }), { 
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      });
    }

    const body = request.body;
    if (!body) {
      return new Response(JSON.stringify({ error: 'No file provided' }), { 
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      });
    }

    await bucket.put(fileName, body);
    
    // Construct the public URL or download API URL
    const downloadUrl = `/api/download/${fileName}`;
    
    return new Response(JSON.stringify({ 
      success: true, 
      url: downloadUrl,
      fileName: fileName
    }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    });
    
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e.message || 'Internal Server Error' }), { 
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    });
  }
}
