// 공통: CORS, 허용 출처, JSON 응답, 오류 코드, 사용량 제한(메모리)
//
// 사용량 제한은 DB 없이 Edge Function 인스턴스 메모리에 둔다(인스턴스가 바뀌면 초기화되는 최선의 노력 방식).
// 비용 안전은 이것이 아니라 "Gemini API 키에 결제 계정을 연결하지 않는 것"이 보장한다:
// 무료 등급 한도를 넘으면 Gemini가 429로 거절할 뿐 과금되지 않는다.

export type ErrorCode =
  | "bad_request"
  | "forbidden_origin"
  | "rate_limited" // 우리 서버의 사용자별 제한
  | "quota_exceeded" // Gemini 무료 사용량 소진(429)
  | "ai_unavailable" // Gemini 오류·시간 초과
  | "ai_bad_output" // 구조화 응답 파싱 실패
  | "not_configured" // 서버 비밀값 없음
  | "tts_unavailable" // 이 언어 음성 서버 없음
  | "tts_failed";

const DEFAULT_ORIGINS = [
  "https://pajussanai.github.io",
];

function allowedOrigins(): string[] {
  const extra = (Deno.env.get("ALLOWED_ORIGINS") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  return [...DEFAULT_ORIGINS, ...extra];
}

/** 로컬 개발(localhost)은 ALLOW_LOCALHOST=1일 때만 허용 */
export function originAllowed(origin: string | null): boolean {
  if (!origin) return false;
  if (allowedOrigins().includes(origin)) return true;
  if (Deno.env.get("ALLOW_LOCALHOST") === "1") {
    try {
      const u = new URL(origin);
      return u.hostname === "localhost" || u.hostname === "127.0.0.1";
    } catch {
      return false;
    }
  }
  return false;
}

export function corsHeaders(origin: string | null): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": origin && originAllowed(origin) ? origin : DEFAULT_ORIGINS[0],
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
    "Access-Control-Allow-Headers": "content-type, authorization, apikey, x-client-info",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

export function json(
  body: unknown,
  status: number,
  origin: string | null,
  extra: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json; charset=utf-8", ...extra },
  });
}

export function fail(
  code: ErrorCode,
  status: number,
  origin: string | null,
  extra: Record<string, string> = {},
): Response {
  return json({ error: code }, status, origin, extra);
}

/** 요청자 식별(제한용). 원래 IP는 저장하지 않고 메모리 키로만 쓴다. */
export function clientKey(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for") ?? "";
  return fwd.split(",")[0].trim() || req.headers.get("x-real-ip") || "unknown";
}

type Window = { start: number; count: number };
const windows = new Map<string, Window>();

/**
 * 고정 창 방식 제한. 허용되면 null, 아니면 다시 시도할 수 있을 때까지의 초를 돌려준다.
 * limit이 0 이하이면 제한하지 않는다.
 */
export function rateLimit(bucket: string, key: string, limit: number, windowSec: number): number | null {
  if (limit <= 0) return null;
  const now = Date.now();
  const id = `${bucket}:${key}`;
  const w = windows.get(id);
  if (!w || now - w.start >= windowSec * 1000) {
    windows.set(id, { start: now, count: 1 });
    if (windows.size > 50_000) windows.clear(); // 메모리 보호
    return null;
  }
  if (w.count >= limit) return Math.ceil((w.start + windowSec * 1000 - now) / 1000);
  w.count++;
  return null;
}

export function envInt(name: string, fallback: number): number {
  const v = Number(Deno.env.get(name));
  return Number.isFinite(v) && Deno.env.get(name) !== undefined && Deno.env.get(name) !== "" ? v : fallback;
}
