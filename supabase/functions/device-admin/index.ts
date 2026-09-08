import { requireOwnerContext } from '../_shared/auth-context.ts';
import { okJson, safeErrorResponse, SafeHttpError } from '../_shared/http.ts';

type ActionBody = {
  action?: unknown;
  profile_id?: unknown;
  device_id?: unknown;
  friendly_name?: unknown;
};

function requiredUuid(value: unknown, code: string, message: string): string {
  if (
    typeof value !== 'string' ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      value,
    )
  ) {
    throw new SafeHttpError(code, message, 400);
  }

  return value;
}

function requiredFriendlyName(value: unknown): string {
  if (typeof value !== 'string') {
    throw new SafeHttpError(
      'SJ_DEVICE_NAME_INVALID',
      'Nama perangkat tidak valid.',
      400,
    );
  }

  const friendlyName = value.trim();
  if (friendlyName.length === 0 || friendlyName.length > 64) {
    throw new SafeHttpError(
      'SJ_DEVICE_NAME_INVALID',
      'Nama perangkat harus 1–64 karakter.',
      400,
    );
  }

  return friendlyName;
}

function rpcFailed(): never {
  throw new SafeHttpError(
    'SJ_DEVICE_OPERATION_FAILED',
    'Perubahan perangkat tidak dapat diproses.',
    400,
  );
}

async function revokeDevice(
  body: ActionBody,
  context: Awaited<ReturnType<typeof requireOwnerContext>>,
) {
  const profileId = requiredUuid(
    body.profile_id,
    'SJ_PROFILE_ID_INVALID',
    'Profil pengguna tidak valid.',
  );
  const deviceId = requiredUuid(
    body.device_id,
    'SJ_DEVICE_ID_INVALID',
    'Perangkat tidak valid.',
  );

  const { error } = await context.adminClient.rpc('cs03_admin_revoke_device', {
    p_business_id: context.authority.business_id,
    p_actor_auth_user_id: context.userId,
    p_actor_session_id: context.sessionId,
    p_target_profile_id: profileId,
    p_device_id: deviceId,
  });

  if (error) rpcFailed();

  return {
    profile_id: profileId,
    device_id: deviceId,
    revoked: true,
  };
}

async function removeDevice(
  body: ActionBody,
  context: Awaited<ReturnType<typeof requireOwnerContext>>,
) {
  const profileId = requiredUuid(
    body.profile_id,
    'SJ_PROFILE_ID_INVALID',
    'Profil pengguna tidak valid.',
  );
  const deviceId = requiredUuid(
    body.device_id,
    'SJ_DEVICE_ID_INVALID',
    'Perangkat tidak valid.',
  );

  const { error } = await context.adminClient.rpc('cs03_admin_remove_device', {
    p_business_id: context.authority.business_id,
    p_actor_auth_user_id: context.userId,
    p_actor_session_id: context.sessionId,
    p_target_profile_id: profileId,
    p_device_id: deviceId,
  });

  if (error) rpcFailed();

  return {
    profile_id: profileId,
    device_id: deviceId,
    removed: true,
  };
}

async function revokeAndRemoveDevice(
  body: ActionBody,
  context: Awaited<ReturnType<typeof requireOwnerContext>>,
) {
  const profileId = requiredUuid(
    body.profile_id,
    'SJ_PROFILE_ID_INVALID',
    'Profil pengguna tidak valid.',
  );
  const deviceId = requiredUuid(
    body.device_id,
    'SJ_DEVICE_ID_INVALID',
    'Perangkat tidak valid.',
  );

  const { error: revokeError } = await context.adminClient.rpc(
    'cs03_admin_revoke_device',
    {
      p_business_id: context.authority.business_id,
      p_actor_auth_user_id: context.userId,
      p_actor_session_id: context.sessionId,
      p_target_profile_id: profileId,
      p_device_id: deviceId,
    },
  );

  if (revokeError) rpcFailed();

  const { error: removeError } = await context.adminClient.rpc(
    'cs03_admin_remove_device',
    {
      p_business_id: context.authority.business_id,
      p_actor_auth_user_id: context.userId,
      p_actor_session_id: context.sessionId,
      p_target_profile_id: profileId,
      p_device_id: deviceId,
    },
  );

  if (removeError) rpcFailed();

  return {
    profile_id: profileId,
    device_id: deviceId,
    revoked: true,
    removed: true,
  };
}

async function renameDevice(
  body: ActionBody,
  context: Awaited<ReturnType<typeof requireOwnerContext>>,
) {
  const deviceId = requiredUuid(
    body.device_id,
    'SJ_DEVICE_ID_INVALID',
    'Perangkat tidak valid.',
  );
  const friendlyName = requiredFriendlyName(body.friendly_name);

  const { error } = await context.adminClient.rpc('cs03_admin_rename_device', {
    p_business_id: context.authority.business_id,
    p_actor_auth_user_id: context.userId,
    p_actor_session_id: context.sessionId,
    p_device_id: deviceId,
    p_friendly_name: friendlyName,
  });

  if (error) rpcFailed();

  return {
    device_id: deviceId,
    friendly_name: friendlyName,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  try {
    const context = await requireOwnerContext(req);
    const body = (await req.json()) as ActionBody;
    const action = body.action;

    if (action === 'revoke_device') {
      return okJson(await revokeDevice(body, context));
    }

    if (action === 'remove_device') {
      return okJson(await removeDevice(body, context));
    }

    if (action === 'revoke_and_remove') {
      return okJson(await revokeAndRemoveDevice(body, context));
    }

    if (action === 'rename_device') {
      return okJson(await renameDevice(body, context));
    }

    throw new SafeHttpError(
      'SJ_ACTION_INVALID',
      'Aksi perangkat tidak valid.',
      400,
    );
  } catch (error) {
    return safeErrorResponse(error);
  }
});
