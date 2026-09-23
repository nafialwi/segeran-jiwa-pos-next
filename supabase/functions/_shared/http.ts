export type SafeErrorPayload = {
  code: string;
  message: string;
};

export const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers':
    'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

const JSON_HEADERS = {
  ...CORS_HEADERS,
  'content-type': 'application/json; charset=utf-8',
};

export class SafeHttpError extends Error {
  readonly code: string;
  readonly status: number;

  constructor(code: string, message: string, status = 400) {
    super(message);
    this.name = 'SafeHttpError';
    this.code = code;
    this.status = status;
  }
}

export function okJson(data: unknown, status = 200): Response {
  return new Response(
    JSON.stringify({
      ok: true,
      data,
    }),
    {
      status,
      headers: JSON_HEADERS,
    },
  );
}

export function errorJson(
  code: string,
  message: string,
  status = 400,
): Response {
  return new Response(
    JSON.stringify({
      ok: false,
      error: {
        code,
        message,
      },
    }),
    {
      status,
      headers: JSON_HEADERS,
    },
  );
}

export function safeErrorResponse(error: unknown): Response {
  if (error instanceof SafeHttpError) {
    return errorJson(error.code, error.message, error.status);
  }

  return errorJson(
    'SJ_EDGE_REQUEST_FAILED',
    'Permintaan tidak dapat diproses.',
    500,
  );
}
