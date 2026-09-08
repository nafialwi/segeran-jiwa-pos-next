# CS-03 Owner Bootstrap

This is performed once, before normal staff creation.

1. Choose the Owner username. Normalize it with lowercase + trim and verify it matches:
   `^[a-z0-9][a-z0-9_-]{2,31}$`
2. In Supabase Auth Users, manually create the first user with:
   `<normalized_username>@auth.segeranjiwa.invalid`
   and the Owner's chosen password.
3. Copy only the Auth user's UUID.
4. In SQL Editor, while operating as the project administrator, run:
   `select private.bootstrap_first_owner('<AUTH_USER_UUID>', '<USERNAME>', '<DISPLAY_NAME>');`
5. The call must return one profile UUID.
6. Do not call the bootstrap function again. A second call must fail with
   `SJ_OWNER_ALREADY_BOOTSTRAPPED`.

Never paste the Owner password into SQL, GitHub, chat logs, migration files, or application settings.
