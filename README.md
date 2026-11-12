# Wedding RSVP

A wedding RSVP site with a personal link for each guest, plus an admin dashboard.
It's plain HTML with no build step, using Supabase for the database and Netlify for hosting. Both are free.

| File | What it is |
|---|---|
| `config.js` | **The only file you edit.** Names, date, venue, deadline, Supabase keys |
| `index.html` | The guest page (opened with a personal link such as `yoursite.netlify.app/?i=K7P2QX9M`) |
| `admin.html` | Your dashboard: add guests, send WhatsApp links, see who's coming, export a CSV |
| `schema.sql` | Database setup. Paste it into Supabase once |
| `style.css`, `favicon.svg` | Styling |

Want to try it first? Open `index.html?i=DEMO1` or `admin.html`. With no Supabase keys set, the site runs in **demo mode** with sample guests.

---

## Setup (about 15 minutes, all on your personal accounts)

### 1. GitHub: store the code
1. Sign in to your **personal** github.com account → **+** (top right) → **New repository**.
2. Name it `wedding-rsvp`, set it to **Private**, then click **Create repository**.
3. On the empty repo page, click **uploading an existing file**.
4. Drag in **all the files from this folder** (the files themselves, not the folder) → **Commit changes**.

### 2. Supabase: the database
1. Sign in to your **personal** supabase.com account → **New project**.
   Name: `wedding-rsvp` · Region: **West EU (Ireland)** or **Central EU (Frankfurt)** · Save the database password somewhere safe.
2. When the project is ready, go to **SQL Editor** → **New query**.
3. Open `schema.sql` and **change `your.personal@email.com` near the bottom to the email you'll log in with.**
4. Paste the whole file → **Run**. Success means the last result shows one row with your email.
   ⚠️ Run this file only once.
5. Go to **Project Settings → API** (or **Data API / API Keys**). Copy:
   - the **Project URL**
   - the **anon public** key (or the **publishable** key, which starts with `sb_publishable_`)
   **Never** use the `service_role` or secret key.

### 3. Netlify: put it online
1. Sign in to your **personal** netlify.com account → **Add new project** → **Import an existing project** → **GitHub**.
2. Allow access to the `wedding-rsvp` repo and select it.
3. Leave the build command **empty** and the publish directory **empty** (or `.`) → **Deploy**.
4. **Project configuration → Change project name**, for example `alex-and-jordan`. Your site is now `https://alex-and-jordan.netlify.app`.

### 4. Connect everything
1. **In GitHub**, open `config.js` → ✏️ edit → fill in your wedding details and paste the `supabaseUrl` and `supabaseKey` → **Commit**.
   Netlify redeploys automatically within about 30 seconds.
2. **In Supabase → Authentication → URL Configuration:**
   - **Site URL:** `https://alex-and-jordan.netlify.app`
   - **Redirect URLs** → Add: `https://alex-and-jordan.netlify.app/admin.html`
3. Open `https://alex-and-jordan.netlify.app/admin.html` → enter your email → click the link in your inbox. You're in.

---

## Using it

- **Add guests** in the admin page, one at a time or in bulk. Bulk format, one invite per line:
  ```
  The Naidoo Family; Priya Naidoo, Kevin Naidoo
  Sarah; Sarah van der Merwe; plus1; nokids
  ```
  `plus1` lets that invite add a guest. `nokids` hides the kids question.
- **Send invites** with the **WhatsApp** button, which pre-fills a message with their personal link, or with **Copy link**.
- **Guests can change their answer** up until the RSVP deadline in `config.js`. After that, the form closes.
- **Someone phoned to RSVP?** Click **Open** on their row and fill in the form for them.
- **Export CSV** gives you the full list for the caterer, the seating plan or the DJ.
- **Adding another admin** (your partner, say): in Supabase → Table Editor → `admins` → Insert row → their email.

## Security notes
- Each guest's link has a random 8-character code. Without a valid code, nobody can see or change anything.
- The guest list itself can only be read by emails listed in the `admins` table.
- The Supabase key in `config.js` is meant to be public. The database rules are what protect your data.
