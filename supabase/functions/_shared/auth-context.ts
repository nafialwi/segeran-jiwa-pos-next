import { createAdminClient, createUserClient } from './admin-clients.ts';
import { SafeHttpError } from './http.ts';

type JwtPayload = {
  session_id?: unknown;
};

type CurrentAuthority = {
  business_id: string;
  owner: boolean;
  [key: string]: unknown;
};

function bearerToken(req: Request): {
  authorization: string;
  token: string;
} {
  const authorization = req.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) {
    throw new SafeHttpError('SJ_AUTH_REQUIRED', 'Sesi masuk diperlukan.', 401);
  }

  const token = authorization.slice('Bearer '.length).trim();
  if (!token) {
    throw new SafeHttpError('SJ_AUTH_REQUIRED', 'Sesi masuk diperlukan.', 401);
  }

  return { authorization, token };
}

function decodeJwtPayload(token: string): JwtPayload {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new SafeHttpError(
      'SJ_AUTH_SESSION_INVALID',
      'Sesi masuk tidak valid.',
      401,
    );
  }

  try {
    const normalized = parts[1]
      .replace(/-/g, '+')
      .replace(/_/g, '/')
      .padEnd(Math.ceil(parts[1].length / 4) * 4, '=');

    const json = atob(normalized);
    return JSON.parse(json) as JwtPayload;
  } catch {
    throw new SafeHttpError(
      'SJ_AUTH_SESSION_INVALID',
      'Sesi masuk tidak valid.',
      401,
    );
  }
}

export async function getUserAndJwt(req: Request) {
  const { authorization, token } = bearerToken(req);
  const userClient = createUserClient(authorization);

  const {
    data: { user },
    error,
  } = await userClient.auth.getUser(token);

  if (error || !user) {
    throw new SafeHttpError('SJ_AUTH_REQUIRED', 'Sesi masuk tidak valid.', 401);
  }

  const payload = decodeJwtPayload(token);
  const sessionId = payload.session_id;
  if (typeof sessionId !== 'string' || sessionId.length === 0) {
    throw new SafeHttpError(
      'SJ_AUTH_SESSION_INVALID',
      'Sesi masuk tidak valid.',
      401,
    );
  }

  return {
    userId: user.id,
    sessionId,
    authorization,
    userClient,
  };
}

export async function requireOwnerContext(req: Request) {
  const { userId, sessionId, userClient } = await getUserAndJwt(req);

  const { data, error } = await userClient.rpc('get_my_authority');
  if (error || !data || typeof data !== 'object') {
    throw new SafeHttpError(
      'SJ_AUTHORITY_DENIED',
      'Akses tidak dapat diverifikasi.',
      403,
    );
  }

  const authority = data as CurrentAuthority;
  if (authority.owner !== true) {
    throw new SafeHttpError(
      'SJ_OWNER_REQUIRED',
      'Akses Owner diperlukan.',
      403,
    );
  }

  if (
    typeof authority.business_id !== 'string' ||
    authority.business_id.length === 0
  ) {
    throw new SafeHttpError(
      'SJ_AUTHORITY_DENIED',
      'Akses tidak dapat diverifikasi.',
      403,
    );
  }

  const adminClient = createAdminClient();

  return {
    userId,
    sessionId,
    authority,
    userClient,
    adminClient,
  };
}
