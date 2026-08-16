import { cert, getApps, initializeApp } from 'npm:firebase-admin/app';
import { getMessaging } from 'npm:firebase-admin/messaging';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const actorAliases: Record<string, string> = {
  'dlr.ddd-dist-adm.bbb': 'dealer distribution admin',
  'dlr.ddd-dist-mgr.ccc': 'dealer distribution manager',
  'whs-dist-adm.mmm': 'modena warehouse distribution admin',
  'log.lll-drvr.kkk': 'third party logistics driver',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization) return json({ error: 'Missing authorization.' }, 401);

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: callerData, error: callerError } = await userClient.auth.getUser(
      authorization.replace('Bearer ', ''),
    );
    if (callerError || !callerData.user?.email) {
      return json({ error: 'Invalid session.' }, 401);
    }

    const body = await request.json();
    const journeyId = String(body.journey_id ?? '').trim();
    if (!journeyId) return json({ error: 'A product journey ID is required.' }, 400);

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: sender, error: senderError } = await admin
      .from('dealer_profiles')
      .select('email')
      .ilike('email', callerData.user.email)
      .maybeSingle();
    if (senderError) throw senderError;
    if (!sender) return json({ error: 'Registered staff access required.' }, 403);

    const { data: journey, error: journeyError } = await admin
      .from('product_journey')
      .select('id, product_id, product_name, actor')
      .eq('id', journeyId)
      .maybeSingle();
    if (journeyError) throw journeyError;
    if (!journey) return json({ error: 'Product journey not found.' }, 404);

    const { data: profiles, error: profilesError } = await admin
      .from('dealer_profiles')
      .select('email, role, code');
    if (profilesError) throw profilesError;

    const normalizedActor = String(journey.actor).trim().toLowerCase();
    const recipients = (profiles ?? []).filter((profile) => {
      const role = String(profile.role ?? '').trim().toLowerCase();
      const code = String(profile.code ?? '').trim().toLowerCase();
      return normalizedActor === role ||
        normalizedActor === code ||
        actorAliases[normalizedActor] === role;
    });

    const productName = String(journey.product_name ?? journey.product_id ?? 'product');
    const title = 'Product journey requires attention';
    const message = `${productName} is ready for ${journey.actor} confirmation.`;
    if (recipients.length === 0) {
      return json({ notified: 0, pushed: 0 }, 200);
    }

    const notifications = recipients.map((recipient) => ({
      recipient_email: recipient.email,
      journey_id: journey.id,
      sender_email: sender.email,
      title,
      message,
    }));
    const { error: notificationError } = await admin
      .from('portal_notifications')
      .insert(notifications);
    if (notificationError) throw notificationError;

    const recipientEmails = recipients.map((recipient) => recipient.email);
    const { data: deviceTokens, error: tokenError } = await admin
      .from('mobile_device_tokens')
      .select('token')
      .in('recipient_email', recipientEmails);
    if (tokenError) throw tokenError;

    const tokens = (deviceTokens ?? []).map((device) => String(device.token));
    const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
    if (tokens.length === 0 || !serviceAccountJson) {
      return json({ notified: recipients.length, pushed: 0 }, 200);
    }

    if (getApps().length === 0) {
      initializeApp(cert(JSON.parse(serviceAccountJson)));
    }
    const pushResult = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body: message },
      data: { journey_id: journey.id, type: 'journey_assignment' },
    });

    const invalidTokens = pushResult.responses
      .map((response, index) => response.success ? null : tokens[index])
      .filter((token): token is string => token != null);
    if (invalidTokens.length > 0) {
      await admin.from('mobile_device_tokens').delete().in('token', invalidTokens);
    }

    return json({ notified: recipients.length, pushed: pushResult.successCount }, 200);
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : 'Notification delivery failed.' },
      500,
    );
  }
});

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
