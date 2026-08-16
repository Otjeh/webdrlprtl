import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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
    if (!authorization) {
      return json({ error: 'Missing authorization.' }, 401);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const accessToken = authorization.replace('Bearer ', '');

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: callerData, error: callerError } = await userClient.auth.getUser(
      accessToken,
    );
    if (callerError || !callerData.user?.email) {
      return json({ error: 'Invalid session.' }, 401);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const { data: adminProfile, error: profileError } = await adminClient
      .from('dealer_profiles')
      .select('role')
      .ilike('email', callerData.user.email)
      .maybeSingle();
    if (profileError || adminProfile?.role !== 'Portal Administrator') {
      return json({ error: 'Administrator access required.' }, 403);
    }

    const body = await request.json();
    const email = String(body.email ?? '').trim().toLowerCase();
    const password = String(body.password ?? '');
    if (!email || password.length < 6) {
      return json({ error: 'A valid email and password are required.' }, 400);
    }

    const { data: targetProfile, error: targetProfileError } = await adminClient
      .from('dealer_profiles')
      .select('auth_user_id, email')
      .ilike('email', email)
      .maybeSingle();
    if (targetProfileError) throw targetProfileError;
    if (!targetProfile) {
      return json({ error: 'The selected user has no registered profile.' }, 404);
    }

    let targetUser;
    if (targetProfile.auth_user_id) {
      const { data, error } = await adminClient.auth.admin.getUserById(
        targetProfile.auth_user_id,
      );
      if (error) throw error;
      targetUser = data.user;
    } else {
      for (let page = 1; ; page++) {
        const { data, error } = await adminClient.auth.admin.listUsers({
          page,
          perPage: 1000,
        });
        if (error) throw error;
        targetUser = data.users.find(
          (user) => user.email?.toLowerCase() === email,
        );
        if (targetUser || data.users.length < 1000) break;
      }
    }

    if (!targetUser) {
      return json({ error: 'Registered Auth user not found.' }, 404);
    }

    const { error: updateError } = await adminClient.auth.admin.updateUserById(
      targetUser.id,
      { password },
    );
    if (updateError) throw updateError;

    if (!targetProfile.auth_user_id) {
      const { error: linkError } = await adminClient
        .from('dealer_profiles')
        .update({ auth_user_id: targetUser.id })
        .ilike('email', email);
      if (linkError) throw linkError;
    }

    return json({ updated: true }, 200);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Password update failed.' }, 500);
  }
});

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
