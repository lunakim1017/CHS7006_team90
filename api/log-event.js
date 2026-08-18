// Vercel serverless function. The browser never sees a Supabase key —
// it only calls this endpoint, which writes to Supabase using the
// service_role key (server-side env var only). service_role bypasses
// Row Level Security entirely, so no RLS policy is required on the table.
const ALLOWED_EVENTS = ["save", "unsave", "find_near_me"];

module.exports = async function handler(req, res) {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const body = req.body || {};
  const { event_type, food_id, food_name_ko, was_saved, session_id } = body;

  if (!ALLOWED_EVENTS.includes(event_type) || typeof food_id !== "string" || !food_id) {
    res.status(400).json({ error: "Invalid event payload" });
    return;
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !serviceKey) {
    res.status(500).json({ error: "Server is missing Supabase configuration" });
    return;
  }

  const response = await fetch(supabaseUrl.replace(/\/$/, "") + "/rest/v1/food_events", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": serviceKey,
      "Authorization": "Bearer " + serviceKey,
      "Prefer": "return=minimal"
    },
    body: JSON.stringify({
      session_id: typeof session_id === "string" ? session_id : null,
      food_id: food_id,
      food_name_ko: typeof food_name_ko === "string" ? food_name_ko : null,
      event_type: event_type,
      was_saved: typeof was_saved === "boolean" ? was_saved : null
    })
  });

  if (!response.ok) {
    const detail = await response.text();
    res.status(502).json({ error: "Supabase insert failed", detail: detail });
    return;
  }

  res.status(204).end();
};
