// 중급 AI 회화 한 턴: 사용자 음성(또는 입력한 문장) → Gemini(받아쓰기·교정·캐릭터 응답) → 구조화 JSON
//
// 요청(POST JSON):
//   lang, character, topic, custom_topic?, summary?, history?[{role, text}],
//   opening?(true면 첫 인사), audio_base64? + audio_mime?, text?(마이크를 못 쓸 때)
// 응답: { result: TurnResult, model }  또는  { error: ErrorCode }
//
// 사용자 음성·대화는 저장하지 않는다. 로그에는 언어·상태·시간·토큰 수만 남긴다.
import { clientKey, corsHeaders, envInt, fail, json, originAllowed, rateLimit } from "../_shared/http.ts";
import { generate, model } from "../_shared/gemini.ts";
import {
  isCharacter,
  isLang,
  parseTranscript,
  parseTurn,
  responseSchema,
  systemInstruction,
  TOPICS,
  TRANSCRIBE_SCHEMA,
  transcribeInstruction,
  type TurnContext,
  turnText,
} from "../_shared/prompt.ts";

const AUDIO_TYPES = new Set([
  "audio/wav",
  "audio/webm",
  "audio/ogg",
  "audio/mp3",
  "audio/mpeg",
  "audio/aac",
  "audio/m4a",
  "audio/flac",
]);
// 앱은 16kHz 모노 WAV로 최대 30초를 보낸다(≈960KB → base64 ≈1.3MB).
// 브라우저가 16kHz로 바꾸지 못하면 48kHz가 될 수 있어(≈2.9MB → base64 ≈3.9MB) 그만큼 허용한다.
const MAX_AUDIO_B64 = 4_000_000;

function str(v: unknown, max: number): string | undefined {
  return typeof v === "string" ? v.trim().slice(0, max) : undefined;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders(origin) });
  if (req.method !== "POST") return fail("bad_request", 405, origin);
  if (!originAllowed(origin)) return fail("forbidden_origin", 403, origin);

  // 사용자별 제한(기본값은 docs/intermediate-ai.md의 제안값, 환경 변수로 바꾼다)
  const who = clientKey(req);
  for (
    const [bucket, limit, sec] of [
      ["turn-m", envInt("TURN_PER_MINUTE", 8), 60],
      ["turn-h", envInt("TURN_PER_HOUR", 80), 3600],
      ["turn-d", envInt("TURN_PER_DAY", 200), 86400],
      ["turn-all-m", envInt("GLOBAL_TURNS_PER_MINUTE", 0), 60],
    ] as const
  ) {
    const wait = rateLimit(bucket, bucket === "turn-all-m" ? "all" : who, limit, sec);
    if (wait !== null) return fail("rate_limited", 429, origin, { "Retry-After": String(wait) });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail("bad_request", 400, origin);
  }

  const lang = body.lang;
  const character = body.character;
  const topic = str(body.topic, 30) ?? "free";
  if (!isLang(lang) || !isCharacter(character) || !(topic in TOPICS)) return fail("bad_request", 400, origin);

  const opening = body.opening === true;
  const typed = str(body.text, 300);
  const audioB64 = typeof body.audio_base64 === "string" ? body.audio_base64 : undefined;
  const audioMime = str(body.audio_mime, 40)?.split(";")[0];
  if (!opening && !typed && !audioB64) return fail("bad_request", 400, origin);
  if (audioB64 && (audioB64.length > MAX_AUDIO_B64 || !audioMime || !AUDIO_TYPES.has(audioMime))) {
    return fail("bad_request", 413, origin);
  }

  const history = Array.isArray(body.history)
    ? (body.history as unknown[]).slice(-8).flatMap((h) => {
      const o = h as Record<string, unknown>;
      const text = str(o?.text, 400);
      return (o?.role === "user" || o?.role === "character") && text ? [{ role: o.role, text }] : [];
    })
    : [];

  const ctx: TurnContext = {
    lang,
    character,
    topic,
    customTopic: str(body.custom_topic, 80) || undefined,
    summary: str(body.summary, 400) || undefined,
    history: history as TurnContext["history"],
    opening,
    typedText: !opening && typed ? typed : undefined,
  };

  const started = Date.now();
  // (선택) GEMINI_TRANSCRIBE_FIRST=1: 받아쓰기만 하는 요청을 먼저 보내 학습자 발화를 고치지 않고 적게 한다.
  // 요청이 두 번이 되어 무료 한도를 두 배로 쓰므로 기본은 꺼 둔다. 실패하면 한 번에 처리하는 방식으로 돌아간다.
  let transcript: string | undefined;
  if (!opening && !typed && audioB64 && Deno.env.get("GEMINI_TRANSCRIBE_FIRST") === "1") {
    const t = await generate({
      system: transcribeInstruction(lang),
      text: "Transcribe the attached audio verbatim.",
      audio: { mimeType: audioMime!, base64: audioB64 },
      schema: TRANSCRIBE_SCHEMA,
    });
    if (!t.ok && t.reason === "quota") return fail("quota_exceeded", 429, origin);
    const parsed = t.ok ? parseTranscript(t.text) : null;
    if (parsed?.understandable && parsed.transcript) {
      transcript = parsed.transcript;
      ctx.transcript = transcript;
    }
    console.log(JSON.stringify({ fn: "transcribe", lang, ok: !!transcript, ms: Date.now() - started }));
  }
  const input = {
    system: systemInstruction(ctx),
    text: turnText(ctx),
    audio: !opening && !typed && !transcript && audioB64 ? { mimeType: audioMime!, base64: audioB64 } : undefined,
    schema: responseSchema(lang),
  };

  // 형식이 깨진 응답이면 한 번만 다시 묻는다(무료 한도를 아끼기 위해 그 이상은 하지 않음).
  for (let attempt = 1; attempt <= 2; attempt++) {
    const out = await generate(input);
    if (!out.ok) {
      // 오류 본문은 Google의 오류 설명이며 사용자 발화를 담지 않는다.
      console.log(JSON.stringify({
        fn: "turn",
        lang,
        ok: false,
        reason: out.reason,
        status: out.status,
        detail: out.detail.slice(0, 200),
        ms: Date.now() - started,
      }));
      if (out.reason === "bad_output" && attempt === 1) continue;
      if (out.reason === "quota") return fail("quota_exceeded", 429, origin);
      if (out.reason === "config") return fail("not_configured", 500, origin);
      if (out.reason === "bad_output") return fail("ai_bad_output", 502, origin);
      return fail("ai_unavailable", 503, origin);
    }
    const result = parseTurn(out.text);
    // 1단계 받아쓰기를 했으면 화면에는 그 글을 그대로 보여 준다(대화 모델이 고쳐 쓰지 못하게).
    if (result && transcript) result.recognized_text = transcript;
    if (!result) {
      console.log(JSON.stringify({ fn: "turn", lang, ok: false, reason: "parse", attempt, ms: Date.now() - started }));
      if (attempt === 1) continue;
      return fail("ai_bad_output", 502, origin);
    }
    console.log(JSON.stringify({
      fn: "turn",
      lang,
      ok: true,
      opening,
      audio: !!input.audio,
      ms: Date.now() - started,
      in: out.inputTokens,
      out: out.outputTokens,
    }));
    return json({ result, model: model() }, 200, origin);
  }
  return fail("ai_bad_output", 502, origin);
});
