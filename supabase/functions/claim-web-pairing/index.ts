import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createHash } from 'node:crypto';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization) return json({ error: 'Missing authorization.' }, 401);

    const url = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const accessToken = authorization.replace('Bearer ', '');
    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: authData, error: authError } = await userClient.auth.getUser(
      accessToken,
    );
    if (authError || !authData.user?.email) return json({ error: 'Invalid session.' }, 401);

    const body = await request.json();
    const pairingId = String(body.pairing_id ?? '');
    const code = String(body.code ?? '');
    if (!pairingId || !/^\d{5}$/.test(code)) {
      return json({ error: 'A pairing ID and five-digit code are required.' }, 400);
    }

    const admin = createClient(url, serviceRoleKey);
    const { data: pairing, error: pairingError } = await admin
      .from('web_mobile_pairings')
      .select('id, code_hash, status, expires_at')
      .eq('id', pairingId)
      .maybeSingle();
    if (pairingError) throw pairingError;
    if (!pairing || pairing.status !== 'pending' || new Date(pairing.expires_at) <= new Date()) {
      return json({ error: 'Pairing expired or already used.' }, 410);
    }

    const hash = createHash('sha256').update(code).digest('hex');
    if (hash !== pairing.code_hash) return json({ error: 'Invalid pairing code.' }, 401);

    const { data: profile, error: profileError } = await admin
      .from('dealer_profiles')
      .select('email, role')
      .ilike('email', authData.user.email)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile) return json({ error: 'No registered dealer profile.' }, 403);

    const { error: updateError } = await admin
      .from('web_mobile_pairings')
      .update({
        status: 'approved',
        approved_email: profile.email,
        approved_role: profile.role,
        approved_at: new Date().toISOString(),
      })
      .eq('id', pairingId)
      .eq('status', 'pending');
    if (updateError) throw updateError;

    return json({ approved: true, role: profile.role }, 200);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Pairing failed.' }, 500);
  }
});

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
