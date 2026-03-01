// GoodWatch Supabase Proxy Worker
// Routes api.goodwatch.movie/* -> jdjqrlkynwfhbtyuddjk.supabase.co/*
// Bypasses ISP-level DNS blocks in India that affect *.supabase.co

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const supabaseUrl = env.SUPABASE_URL || 'https://jdjqrlkynwfhbtyuddjk.supabase.co';

    // Block requests without apikey header
    const apikey = request.headers.get('apikey');
    if (!apikey) {
      return new Response(JSON.stringify({ error: 'Missing apikey header' }), {
        status: 401,
        headers: corsHeaders('application/json'),
      });
    }

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(),
      });
    }

    // WebSocket upgrade for Realtime
    const upgradeHeader = request.headers.get('Upgrade');
    if (upgradeHeader && upgradeHeader.toLowerCase() === 'websocket') {
      return handleWebSocket(request, url, supabaseUrl);
    }

    // Build target URL: replace origin, keep path + query
    const targetUrl = supabaseUrl + url.pathname + url.search;

    // Copy all headers from original request
    const headers = new Headers();
    for (const [key, value] of request.headers.entries()) {
      // Skip host header (will be set by fetch)
      if (key.toLowerCase() === 'host') continue;
      headers.set(key, value);
    }

    // Build fetch options
    const fetchOptions = {
      method: request.method,
      headers: headers,
    };

    // Copy body for non-GET/HEAD requests
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      fetchOptions.body = request.body;
    }

    try {
      const response = await fetch(targetUrl, fetchOptions);

      // Copy response headers
      const responseHeaders = new Headers(response.headers);

      // Add CORS headers
      responseHeaders.set('Access-Control-Allow-Origin', '*');
      responseHeaders.set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
      responseHeaders.set('Access-Control-Allow-Headers', 'apikey, Authorization, Content-Type, Prefer, X-Client-Info, Range');
      responseHeaders.set('Access-Control-Expose-Headers', 'Content-Range, X-Total-Count');

      // Add proxy identification
      responseHeaders.set('X-Proxied-By', 'goodwatch-cf-worker');

      // Add rate limiting header (tracking only, not enforced)
      responseHeaders.set('X-RateLimit', 'tracking-only');

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: responseHeaders,
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: 'Proxy error', detail: err.message }), {
        status: 502,
        headers: corsHeaders('application/json'),
      });
    }
  },
};

// WebSocket passthrough for Supabase Realtime
async function handleWebSocket(request, url, supabaseUrl) {
  const targetUrl = supabaseUrl.replace('https://', 'wss://') + url.pathname + url.search;

  // Cloudflare Workers WebSocket passthrough
  const upgradeResponse = await fetch(targetUrl, {
    headers: request.headers,
    method: request.method,
  });

  return upgradeResponse;
}

// CORS headers helper
function corsHeaders(contentType) {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'apikey, Authorization, Content-Type, Prefer, X-Client-Info, Range',
    'Access-Control-Expose-Headers': 'Content-Range, X-Total-Count',
    'X-Proxied-By': 'goodwatch-cf-worker',
  };
  if (contentType) {
    headers['Content-Type'] = contentType;
  }
  return headers;
}
