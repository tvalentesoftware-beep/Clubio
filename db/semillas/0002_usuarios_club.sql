-- Clubio — acceso de usuarios a los clubes de demostracion
--
-- Se corre despues de crear el usuario en Supabase Auth (Authentication ->
-- Users). Vincula por email, asi que el archivo sirve en cualquier entorno
-- donde exista ese usuario. Solo El Molino: Padel Belgrano queda sin
-- usuarios a proposito, para que las pruebas de aislamiento tengan un club
-- que el usuario NO deberia ver.

insert into usuarios_club (club_id, usuario_id, rol)
select '11111111-1111-4111-8111-111111111111', u.id, 'dueno'
  from auth.users u
 where u.email = 'tvalente.software@gmail.com'
on conflict (club_id, usuario_id) do nothing;
