// Gemini 호출. 음성 이해 + 교정 + 캐릭터 응답을 한 요청으로 처리한다.
//
// 기본은 공식 문서가 권하는 Interactions API(POST /v1beta/interactions).
// GEMINI_API_STYLE=generate_content이면 기존 generateContent API를 쓴다(문서상 '레거시', 계속 지원).
// 두 형식 모두 store/학습과 무관하게 무료 등급이면 Google이 입력을 제품 개선에 쓸 수 있다(약관).

export type GeminiInput = {
  system: string;
  text: string;
  audio?: { mimeType: string; base64: string };
  schema: Record<string, unknown>;
};

export type GeminiOutput =
  | { ok: true; text: string; inputTokens?: number; outputTokens?: number }
  | {
    ok: false;
    status: number;
    reason: "quota" | "unavailable" | "region" | "config" | "timeout" | "bad_output";
    detail: string;
  };

const BASE = "https://generativelanguage.googleapis.com/v1beta";

export function model(): string {
  // 7개 언어 실측(2026-11-19)에서 학습자 실수를 고치지 않고 받아 적는 정확도와 속도가 가장 좋았던 무료 모델
  return Deno.env.get("GEMINI_MODEL") || "gemini-3.1-flash-lite";
}

function thinkingLevel(): string {
  return Deno.env.get("GEMINI_THINKING_LEVEL") || "minimal";
}

function classify(status: number, body: string): GeminiOutput {
  // 429: 무료 등급 한도(RPM·TPM·RPD) 초과. 402: 선불 잔액 없음. 둘 다 다시 과금 경로로 넘기지 않고 막는다.
  if (status === 429 || status === 402) return { ok: false, status, reason: "quota", detail: body.slice(0, 300) };
  if (status === 400 && body.includes("FAILED_PRECONDITION")) {
    return { ok: false, status, reason: "region", detail: body.slice(0, 300) };
  }
  if (status === 401 || status === 403) return { ok: false, status, reason: "config", detail: body.slice(0, 300) };
  return { ok: false, status, reason: "unavailable", detail: body.slice(0, 300) };
}

async function post(url: string, key: string, body: unknown, headers: Record<string, string> = {}): Promise<Response> {
  return await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": key, ...headers },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(Number(Deno.env.get("GEMINI_TIMEOUT_MS") || 30000)),
  });
}

async function viaInteractions(key: string, inp: GeminiInput): Promise<GeminiOutput> {
  const content: unknown[] = [{ type: "text", text: inp.text }];
  if (inp.audio) content.push({ type: "audio", data: inp.audio.base64, mime_type: inp.audio.mimeType });
  const res = await post(`${BASE}/interactions`, key, {
    model: model(),
    system_instruction: inp.system,
    input: [{ type: "user_input", content }],
    generation_config: { thinking_level: thinkingLevel(), max_output_tokens: 2048 },
    response_format: { type: "text", mime_type: "application/json", schema: inp.schema },
    store: false,
  }, { "Api-Revision": "2026-05-20" });
  const body = await res.text();
  if (!res.ok) return classify(res.status, body);
  try {
    const j = JSON.parse(body);
    if (j.status && j.status !== "completed") {
      return { ok: false, status: 502, reason: "bad_output", detail: `status ${j.status}` };
    }
    const text = (j.steps ?? [])
      .filter((s: { type?: string }) => s.type === "model_output")
      .flatMap((s: { content?: { type?: string; text?: string }[] }) => s.content ?? [])
      .filter((c: { type?: string }) => c.type === "text")
      .map((c: { text?: string }) => c.text ?? "")
      .join("");
    return { ok: true, text, inputTokens: j.usage?.total_input_tokens, outputTokens: j.usage?.total_output_tokens };
  } catch {
    return { ok: false, status: 502, reason: "bad_output", detail: "unparseable interaction" };
  }
}

async function viaGenerateContent(key: string, inp: GeminiInput): Promise<GeminiOutput> {
  const parts: unknown[] = [{ text: inp.text }];
  if (inp.audio) parts.push({ inline_data: { mime_type: inp.audio.mimeType, data: inp.audio.base64 } });
  const res = await post(`${BASE}/models/${model()}:generateContent`, key, {
    systemInstruction: { parts: [{ text: inp.system }] },
    contents: [{ role: "user", parts }],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: inp.schema,
      maxOutputTokens: 2048,
      thinkingConfig: { thinkingLevel: thinkingLevel().toUpperCase() },
    },
  });
  const body = await res.text();
  if (!res.ok) return classify(res.status, body);
  try {
    const j = JSON.parse(body);
    const text = (j.candidates?.[0]?.content?.parts ?? [])
      .filter((p: { thought?: boolean }) => !p.thought)
      .map((p: { text?: string }) => p.text ?? "")
      .join("");
    return {
      ok: true,
      text,
      inputTokens: j.usageMetadata?.promptTokenCount,
      outputTokens: j.usageMetadata?.candidatesTokenCount,
    };
  } catch {
    return { ok: false, status: 502, reason: "bad_output", detail: "unparseable response" };
  }
}

export async function generate(inp: GeminiInput): Promise<GeminiOutput> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) return { ok: false, status: 500, reason: "config", detail: "GEMINI_API_KEY not set" };
  try {
    return Deno.env.get("GEMINI_API_STYLE") === "generate_content"
      ? await viaGenerateContent(key, inp)
      : await viaInteractions(key, inp);
  } catch (e) {
    const timeout = e instanceof DOMException && (e.name === "TimeoutError" || e.name === "AbortError");
    return { ok: false, status: 504, reason: timeout ? "timeout" : "unavailable", detail: String(e).slice(0, 200) };
  }
}
