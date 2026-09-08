import { requireOwnerContext } from '../_shared/auth-context.ts';
import { okJson, safeErrorResponse, SafeHttpError } from '../_shared/http.ts';
import {
  normalizeUsername,
  toInternalAuthEmail,
  validateStaffPassword,
} from '../_shared/identity.ts';

type ActionBody = {
  action?: unknown;
  username?: unknown;
  display_name?: unknown;
  password?: unknown;
  role_code?: unknown;
  profile_id?: unknown;
  status?: unknown;
  permission_code?: unknown;
  effect?: unknown;
};

function requiredText(
  value: unknown,
  code: string,
  message: string,
  maxLength = 100,
): string {
  if (typeof value !== 'string') {
    throw new SafeHttpError(code, message, 400);
  }

  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maxLength) {
    throw new SafeHttpError(code, message, 400);
  }

  return trimmed;
}

function requiredUuid(value: unknown): string {
  const text = requiredText(
    value,
    'SJ_PROFILE_ID_INVALID',
    'Profil pengguna tidak valid.',
    64,
  );

  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      text,
    )
  ) {
    throw new SafeHttpError(
      'SJ_PROFILE_ID_INVALID',
      'Profil pengguna tidak valid.',
      400,
    );
  }

  return text;
}

function rpcError(error: unknown): never {
  void error;
  throw new SafeHttpError(
    'SJ_ADMIN_OPERATION_FAILED',
    'Perubahan pengguna tidak dapat diproses.',
    400,
  );
}

async function createStaff(
  body: ActionBody,
  context: Awaited<ReturnType<typeof requireOwnerContext>>,
) {
  const usernameRaw = requiredText(
    body.username,
    'SJ_USERNAME_INVALID',
    'Username tidak valid.',
    32,
  );
  const username = normalizeUsername(usernameRaw);
  const email = toInternalAuthEmail(username);
  const displayName = requiredText(
    body.display_name,
    'SJ_DISPLAY_NAME_INVALID',
    'Nama pengguna tidak valid.',
    80,
  );
  const password = validateStaffPassword(body.password);
  const roleCode = requiredText(
    body.role_code,
    'SJ_ROLE_INVALID',
    'Role tidak valid.',
    32,
  ).toUpperCase();

  if (roleCode === 'OWNER') {
    throw new SafeHttpError(
      'SJ_ROLE_OWNER_NOT_ASSIGNABLE',
      'Role Owner tidak dapat diberikan dari menu pengguna.',
      403,
    );
  }

  const { data: created, error: createError } =
    await context.adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        sjpos_username: username,
      },
    });

  if (createError || !created.user) {
    throw new SafeHttpError(
      'SJ_CREATE_STAFF_FAILED',
      'Pengguna tidak dapat dibuat.',
      400,
    );
  }

  const newAuthUser = created.user;

  const { data: profileId, error: bindError } = await context.adminClient.rpc(
    'cs03_admin_bind_staff',
    {
      p_business_id: context.authority.business_id,
      p_actor_auth_user_id: context.userId,
      p_actor_session_id: context.sessionId,
      p_target_auth_user_id: newAuthUser.id,
      p_username: username,
      p_display_name: displayName,
      p_role_code: roleCode,
    },
  );

  if (bindError || typeof profileId !== 'string') {
    await context.adminClient.auth.admin.deleteUser(newAuthUser.id);
    rpcError(bindError);
  }

  return {
    profile_id: profileId,
    username,
    display_name: displayName,
  };
}

async function resetPassword(
  body: ActionBody,
  context: Awaited<ReturnType<typeof requireOwnerContext>>,
) {
  const profileId = requiredUuid(body.profile_id);
  const password = validateStaffPassword(body.password);

  const { data: targetAuthUserId, error: lookupError } =
    await context.adminClient.rpc('cs03_admin_get_target_auth_user', {
      p_business_id: context.authority.business_id,
      p_actor_auth_user_id: context.userId,
      p_actor_session_id: context.sessionId,
      p_target_profile_id: profileId,
    });

  if (lookupError || typeof targetAuthUserId !== 'string') {
    rpcError(lookupError);
  }

  const { error: updateError } =
    await context.adminClient.auth.admin.updateUserById(targetAuthUserId, {
      password,
    });

  if (updateError) {
    throw new SafeHttpError(
      'SJ_PASSWORD_RESET_FAILED',
      'Password tidak dapat diubah.',
      400,
    );
  }

  const { error: auditError } = await context.adminClient.rpc(
    'cs03_admin_record_password_reset',
    {
      p_business_id: context.authority.business_id,
      p_actor_auth_user_id: context.userId,
      p_actor_session_id: context.sessionId,
      p_target_profile_id: profileId,
    },
  );

  if (auditError) rpcError(auditError);

  return { profile_id: profileId };
}

async function setStatus(
  body: ActionBody,
  context: Awaited<ReturnType<typeof requireOwnerContext>>,
) {
  const profileId = requiredUuid(body.profile_id);
  const status = requiredText(
    body.status,
    'SJ_STATUS_INVALID',
    'Status pengguna tidak valid.',
    16,
  ).toUpperCase();

  if (!['ACTIVE', 'LEAVE', 'DISABLED'].includes(status)) {
    throw new SafeHttpError(
      'SJ_STATUS_INVALID',
      'Status pengguna tidak valid.',
      400,
    );
  }

  const { error } = await context.adminClient.rpc('cs03_admin_set_status', {
    p_business_id: context.authority.business_id,
    p_actor_auth_user_id: context.userId,
    p_actor_session_id: context.sessionId,
    p_target_profile_id: profileId,
    p_status: status,
  });

  if (error) rpcError(error);

  return {
    profile_id: profileId,
    status,
  };
}

async function setPermission(
  body: ActionBody,
  context: Awaited<ReturnType<typeof requireOwnerContext>>,
) {
  const profileId = requiredUuid(body.profile_id);
  const permissionCode = requiredText(
    body.permission_code,
    'SJ_PERMISSION_INVALID',
    'Izin tidak valid.',
    64,
  ).toUpperCase();
  const effect = requiredText(
    body.effect,
    'SJ_PERMISSION_EFFECT_INVALID',
    'Pilihan izin tidak valid.',
    16,
  ).toUpperCase();

  if (!['ALLOW', 'DENY', 'INHERIT'].includes(effect)) {
    throw new SafeHttpError(
      'SJ_PERMISSION_EFFECT_INVALID',
      'Pilihan izin tidak valid.',
      400,
    );
  }

  const { error } = await context.adminClient.rpc(
    'cs03_admin_set_permission_override',
    {
      p_business_id: context.authority.business_id,
      p_actor_auth_user_id: context.userId,
      p_actor_session_id: context.sessionId,
      p_target_profile_id: profileId,
      p_permission_code: permissionCode,
      p_effect: effect,
    },
  );

  if (error) rpcError(error);

  return {
    profile_id: profileId,
    permission_code: permissionCode,
    effect,
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

    if (action === 'create_staff') {
      return okJson(await createStaff(body, context), 201);
    }

    if (action === 'reset_password') {
      return okJson(await resetPassword(body, context));
    }

    if (action === 'set_status') {
      return okJson(await setStatus(body, context));
    }

    if (action === 'set_permission') {
      return okJson(await setPermission(body, context));
    }

    throw new SafeHttpError(
      'SJ_ACTION_INVALID',
      'Aksi pengguna tidak valid.',
      400,
    );
  } catch (error) {
    return safeErrorResponse(error);
  }
});
