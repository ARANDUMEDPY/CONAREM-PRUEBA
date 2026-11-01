# Banco CONAREM

Web de práctica para el examen CONAREM (Especialidades Troncales): plan diario, práctica con filtros, errores, progreso, explicaciones con fuentes y glosario de siglas. Cada usuario entra con su cuenta y activa el acceso con un código de un solo uso.

## Cómo está armado

| Parte | Dónde |
|---|---|
| Página para estudiantes | `index.html` |
| Panel de administración (códigos, usuarios, carga de preguntas) | `admin.html` |
| Conexión a la base de datos | `config.js` |
| Estructura y seguridad de la base | `supabase/schema.sql` |

- **Web:** GitHub Pages (gratis).
- **Usuarios, preguntas y progreso:** Supabase. Las preguntas **no** están en este repositorio: solo se descargan después de iniciar sesión, y solo para usuarios con acceso activo.

## Puesta en marcha (una sola vez)

1. **Supabase → SQL Editor:** pegá el contenido de `supabase/schema.sql` y tocá **Run**.
2. **Supabase → Project Settings → API:** copiá la **Project URL** y la **anon public key** dentro de `config.js`. Nunca uses la *service_role key*.
3. **Supabase → Authentication → URL Configuration:** en *Site URL* poné la dirección de la web, por ejemplo `https://andrewgimenez20-crypto.github.io/conarem-prueba/`.
4. **GitHub → Settings → Pages:** *Deploy from a branch* → `main` / `(root)` → Save.
5. Entrá a la web, **creá tu cuenta** y confirmá el correo.
6. En **SQL Editor**, convertite en administrador:
   ```sql
   update public.profiles set is_admin = true where email = 'tu-correo@ejemplo.com';
   ```
7. Abrí `admin.html` → **Cargar preguntas** → elegí `preguntas_supabase.json` (te lo paso aparte, **no lo subas a GitHub**).

## Uso diario

- **Vender un acceso:** en `admin.html`, generá un código (por ejemplo, 150 días), tocá **Copiar mensaje** y mandalo por WhatsApp.
- **La persona:** entra a la web, crea su cuenta, confirma el correo e ingresa el código.
- **Renovar:** con un código nuevo; los días se suman.
- **Dar acceso a mano:** en `admin.html`, con el correo y la fecha.
