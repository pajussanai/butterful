// TTS Router: { language, character_id, text } → 언어에 맞는 기존 엔진 서버로 보내 MP3를 돌려준다.
//
// 엔진 서버(server/tts, Hugging Face Space)는 언어별로 하나의 공통 인터페이스(/tts)를 쓴다.
//   TTS_URL      : Supertonic 3 + Kokoro 서버(en, ja, ko, fr, en_gb, es)
//   TTS_ZH_URL   : Qwen3-TTS 서버(zh). 무료 CPU에서는 너무 느려 기본으로 두지 않는다 → 없으면 tts_unavailable.
//   TTS_SHARED_SECRET : 엔진 서버와 같은 값(X-Tts-Key)
// 문장과 음성은 저장하지 않는다(개인 대화이므로 캐시하지 않음).
import { clientKey, corsHeaders, envInt, fail, originAllowed, rateLimit } from "../_shared/http.ts";
import { isCharacter, isLang } from "../_shared/prompt.ts";

const MAX_CHARS = 400;
const MAIN_LANGS = new Set(["en", "ja", "ko", "fr", "en_gb", "es"]);

function serverFor(lang: string): string | undefined {
  const url = MAIN_LANGS.has(lang) ? Deno.env.get("TTS_URL") : lang === "zh" ? Deno.env.get("TTS_ZH_URL") : undefined;
  return url ? url.replace(/\/$/, "") : undefined;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders(origin) });
  if (!originAllowed(origin)) return fail("forbidden_origin", 403, origin);

  // GET: 어떤 언어의 음성을 쓸 수 있는지(앱이 '음성 준비 중'을 정직하게 보여 주기 위해)
  if (req.method === "GET") {
    const langs = ["en", "ja", "ko", "fr", "en_gb", "es", "zh"].filter((l) => !!serverFor(l));
    return new Response(JSON.stringify({ languages: langs }), {
      status: 200,
      headers: { ...corsHeaders(origin), "Content-Type": "application/json", "Cache-Control": "max-age=300" },
    });
  }
  if (req.method !== "POST") return fail("bad_request", 405, origin);

  const who = clientKey(req);
  for (
    const [bucket, limit, sec] of [
      ["tts-m", envInt("TTS_PER_MINUTE", 12), 60],
      ["tts-d", envInt("TTS_PER_DAY", 300), 86400],
    ] as const
  ) {
    const wait = rateLimit(bucket, who, limit, sec);
    if (wait !== null) return fail("rate_limited", 429, origin, { "Retry-After": String(wait) });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail("bad_request", 400, origin);
  }
  const { language, character_id } = body;
  const text = typeof body.text === "string" ? body.text.trim().slice(0, MAX_CHARS) : "";
  if (!isLang(language) || !isCharacter(character_id) || !text) return fail("bad_request", 400, origin);

  const server = serverFor(language);
  const secret = Deno.env.get("TTS_SHARED_SECRET");
  if (!server) return fail("tts_unavailable", 501, origin);
  if (!secret) return fail("not_configured", 500, origin);

  const started = Date.now();
  try {
    const res = await fetch(`${server}/tts`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Tts-Key": secret },
      body: JSON.stringify({ language, character_id, text }),
      // 무료 Space가 잠들어 있으면 깨어나는 데 오래 걸릴 수 있다. 앱은 그동안 글로 대화를 이어 간다.
      signal: AbortSignal.timeout(Number(Deno.env.get("TTS_TIMEOUT_MS") || 45000)),
    });
    console.log(JSON.stringify({ fn: "tts", lang: language, status: res.status, ms: Date.now() - started }));
    if (!res.ok) return fail("tts_failed", 502, origin);
    return new Response(res.body, {
      status: 200,
      headers: { ...corsHeaders(origin), "Content-Type": "audio/mpeg", "Cache-Control": "no-store" },
    });
  } catch (e) {
    console.log(
      JSON.stringify({ fn: "tts", lang: language, error: String(e).slice(0, 100), ms: Date.now() - started }),
    );
    return fail("tts_failed", 504, origin);
  }
});
