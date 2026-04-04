import { JWT } from "https://esm.sh/google-auth-library@9";

export async function sendFCMNotification(
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>
) {
  // Try to get from a single JSON string first
  let serviceAccount: any = {};
  const saEnv = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (saEnv) {
    try {
      serviceAccount = JSON.parse(saEnv);
    } catch (e) {
      console.error("[FCM] Error parsing FIREBASE_SERVICE_ACCOUNT JSON:", e);
    }
  }

  // Fallback to individual env vars if JSON is missing or incomplete
  const projectId = serviceAccount.project_id || Deno.env.get('FIREBASE_PROJECT_ID');
  const clientEmail = serviceAccount.client_email || Deno.env.get('FIREBASE_CLIENT_EMAIL');
  const privateKey = serviceAccount.private_key || Deno.env.get('FIREBASE_PRIVATE_KEY');

  if (!projectId || !clientEmail || !privateKey) {
    console.error("[FCM] Missing Firebase credentials. Please ensure FIREBASE_SERVICE_ACCOUNT or (FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY) are set in Supabase Secrets.");
    return;
  }

  const client = new JWT({
    email: clientEmail,
    key: privateKey.replace(/\\n/g, '\n'), // Ensure newlines are handled correctly
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  });

  const jwtToken = await client.getAccessToken();
  const accessToken = jwtToken.token;

  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  const payload = {
    message: {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: data,
      android: {
        priority: "high",
        notification: {
          channel_id: "zuno_channel_id",
        },
      },
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
            sound: "default",
          },
        },
      },
    },
  };

  const response = await fetch(fcmUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const result = await response.json();
  if (!response.ok) {
    console.error("[FCM] Error sending message:", result);
    throw new Error(`FCM error: ${JSON.stringify(result)}`);
  }

  console.log("[FCM] Success:", result.name);
  return result;
}
