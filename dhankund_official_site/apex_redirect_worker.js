// Redirects the apex domain (dhankund.com) to the canonical www host.
// The official Next.js site is bound to www.dhankund.com; this tiny Worker is
// bound only to the apex so that both hosts never compete for the same route.
export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.hostname === 'dhankund.com') {
      url.hostname = 'www.dhankund.com';
      url.protocol = 'https:';
      return Response.redirect(url.toString(), 301);
    }
    return new Response('Not found', { status: 404 });
  },
};
