// Vercel serverless function: exposes only the two values the client needs,
// read from Vercel's environment variables (Project Settings → Environment
// Variables) rather than being hardcoded in the committed source.
module.exports = function handler(req, res) {
  res.status(200).json({
    supabaseUrl: process.env.SUPABASE_URL || "",
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY || ""
  });
};
