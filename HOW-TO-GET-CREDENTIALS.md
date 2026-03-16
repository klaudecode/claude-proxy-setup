# How to get every credential (step by step)

This guide tells you **exactly what information you need** and **how to get each value**, so you can fill in `.env` or `secrets.json` and run the setup.

---

## Overview: what you need

| Credential | Where it comes from | Required? |
|------------|---------------------|-----------|
| **SSH_HOST** | Vultr dashboard | Yes |
| **SSH_USER** | Your Vultr server (usually `root`) | Yes |
| **SSH_KEY_PATH** or **SSH_PASSWORD** | Your PC (key file) or Vultr (password) | One of them |
| **BRIGHT_DATA_HOST** | Bright Data dashboard | Yes |
| **BRIGHT_DATA_PORT** | Bright Data dashboard | Yes |
| **BRIGHT_DATA_USER** | Bright Data dashboard | Yes |
| **BRIGHT_DATA_PASS** | Bright Data dashboard | Yes |
| WIREGUARD_PORT, XRAY_PORT, etc. | Optional; leave defaults unless you know you need to change them | No |

---

## Part 1: Vultr (SSH access to your server)

### 1.1 SSH_HOST — your server’s IP address

**What it is:** The public IP address of the Vultr server you will SSH into.

**How to get it:**

1. Go to **https://my.vultr.com** and log in.
2. Click **Products** (or **Servers**) in the left sidebar.
3. Find the server you want to use for this setup.
4. In the server row you’ll see an **IP Address** (e.g. `45.76.123.45`). That is **SSH_HOST**.

**Format:** Plain IP, no `http://` or port. Example: `45.76.123.45`.

**In .env:**  
`SSH_HOST=45.76.123.45`

---

### 1.2 SSH_USER — the user you log in as over SSH

**What it is:** The Linux username you use when connecting via SSH.

**How to get it:**

- If you created the server with Vultr’s default image (e.g. Ubuntu), the default user is usually **`root`**.
- You can confirm by opening the server in Vultr: the **Overview** or **Settings** often show “Username: root” (or another user if you created one).

**Format:** One word, lowercase. Usually: `root`.

**In .env:**  
`SSH_USER=root`

---

### 1.3 SSH_KEY_PATH **or** SSH_PASSWORD — how you prove your identity to the server

You need **either** an SSH key path **or** the server’s root password. Key is more secure; password is quicker if you already have it.

---

#### Option A: Use an SSH key (recommended)

**What it is:** The full path on your Windows PC to the **private** key file (e.g. `id_ed25519` or `id_rsa`) that you use to log into this Vultr server.

**How to get / set it up:**

**Step 1 — See if you already have a key**

1. Open **PowerShell**.
2. Run:
   ```powershell
   Get-ChildItem $env:USERPROFILE\.ssh
   ```
3. If you see a file named `id_ed25519` or `id_rsa` (no `.pub`), you already have a private key. Its full path is:
   - `C:\Users\Kyle\.ssh\id_ed25519` or
   - `C:\Users\Kyle\.ssh\id_rsa`  
   (Replace `Kyle` with your Windows username if different.)

**Step 2 — If you don’t have a key, create one**

1. In PowerShell, run:
   ```powershell
   ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\id_ed25519 -N '""'
   ```
   (This creates a key with no passphrase. For a passphrase, use `-N '"YourPassphrase"'`.)
2. Your private key path is: `C:\Users\Kyle\.ssh\id_ed25519` (again, replace `Kyle` with your username).

**Step 3 — Add the public key to your Vultr server**

1. In PowerShell, run:
   ```powershell
   Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
   ```
2. Copy the **entire** line (starts with `ssh-ed25519 …`).
3. In Vultr: **Products** → click your server → **Settings** (or **Server Details**).
4. Find **SSH Keys** or **Authorized SSH Keys**.
5. Paste the copied line and save, or use “Add SSH Key” and paste there.
6. If the server was created **before** you added the key, you may need to use the **root password** once (from Vultr → server → “View password” or the email they sent) to log in and add the key to `~/.ssh/authorized_keys` yourself. After that, you can use the key.

**Format for .env:**  
Full path, with backslashes or forward slashes. Examples:

- `SSH_KEY_PATH=C:\Users\Kyle\.ssh\id_ed25519`
- Or: `SSH_KEY_PATH=C:/Users/Kyle/.ssh/id_ed25519`

**In .env:**  
- Set: `SSH_KEY_PATH=C:\Users\Kyle\.ssh\id_ed25519` (use your path).
- Leave `SSH_PASSWORD` commented out or delete it.

---

#### Option B: Use the server’s root password

**What it is:** The password for the `root` user (or whatever **SSH_USER** you use) on the Vultr server.

**How to get it:**

1. In Vultr: **Products** → click the server.
2. Open **Overview** or **Settings**.
3. Look for **Password** or **Root password** or **View password**. Click to reveal and copy it.  
   (Sometimes Vultr emails this when the server is created; check that email if you don’t see it in the dashboard.)

**In .env:**  
- Leave **SSH_KEY_PATH** commented out or delete it.
- Add (use your real password, no quotes unless the password contains spaces):
  ```env
  SSH_PASSWORD=your_actual_root_password
  ```

**Security:** Prefer SSH key over password when possible.

---

## Part 2: Bright Data (proxy for outbound traffic from your server)

You need a Bright Data **proxy zone** (e.g. Residential or Datacenter). The dashboard gives you: host, port, username, and password.

### 2.1 Log in and open the right zone

1. Go to **https://brightdata.com** and log in (or sign up).
2. In the dashboard, open **Proxies & Scraping** (or **Proxy**).
3. Find the **proxy product** you use (e.g. **Residential proxies**, **Datacenter proxies**, **Web Share**).
4. Open the **zone** you want to use for this setup (or create one and note its name).

---

### 2.2 BRIGHT_DATA_HOST — proxy server hostname

**What it is:** The hostname of Bright Data’s proxy server for your zone.

**How to get it:**

1. In the zone’s page, look for **Access parameters**, **Integration**, **Proxy setup**, or **Connection details**.
2. You’ll see something like:
   - **Host:** `brd.superproxy.io` or `gate.smartproxy.com` or a zone-specific host.  
   The exact name depends on the product; common ones are `brd.superproxy.io` or a host that contains your zone name.
3. Copy that **host** value. Do not include `http://` or a port in it.

**Format:** Hostname only. Example: `brd.superproxy.io`.

**In .env:**  
`BRIGHT_DATA_HOST=brd.superproxy.io`  
(Use the host your zone actually shows.)

---

### 2.3 BRIGHT_DATA_PORT — proxy port

**What it is:** The port number for the proxy (often 22225 for residential, or 22222, etc.).

**How to get it:**

1. Same place as the host (Access parameters / Integration / Proxy setup).
2. Look for **Port** (e.g. `22225`, `22222`, `24000`). Copy that number.

**Format:** Numbers only. Example: `22225`.

**In .env:**  
`BRIGHT_DATA_PORT=22225`

---

### 2.4 BRIGHT_DATA_USER — proxy username

**What it is:** The username Bright Data gives you for this zone. It often looks like:

- `brd-customer-XXXXX-zone-residential` or  
- `brd-customer-XXXXX-zone-datacenter`  
(where XXXXX is your customer ID and the zone name may vary.)

**How to get it:**

1. In the same **Access parameters** / **Integration** / **Proxy setup** section.
2. Find **Username** (or “User”). It’s usually long and contains your customer ID and zone name.
3. Copy the **entire** string. Don’t add or remove anything.

**Format:** One string, no spaces. Example: `brd-customer-hl_abc12345-zone-residential`.

**In .env:**  
`BRIGHT_DATA_USER=brd-customer-hl_abc12345-zone-residential`  
(Use your actual value.)

---

### 2.5 BRIGHT_DATA_PASS — proxy password

**What it is:** The password for the proxy zone (sometimes called “Zone password” or “Proxy password”).

**How to get it:**

1. Same **Access parameters** / **Integration** section.
2. Find **Password** (or “Zone password”). Click to reveal and copy.
3. If you never set one, there may be a “Set password” or “Generate” button; set it and copy it once.

**Format:** Use the exact string. If it contains special characters (e.g. `#`, `&`, `=`), in `.env` you can wrap it in double quotes:  
`BRIGHT_DATA_PASS="my#pass&word"`

**In .env:**  
`BRIGHT_DATA_PASS=your_actual_zone_password`

---

## Part 3: Optional values (you can leave these as in the example)

You only need to change these if you have a specific reason (e.g. port conflict, different network design).

| Variable | What it is | Default | When to change |
|----------|------------|--------|----------------|
| **WIREGUARD_PORT** | UDP port WireGuard listens on on the server | `51820` | If your host or firewall blocks 51820. |
| **XRAY_PORT** | Port Xray listens on inside the VPN | `1080` | Only if you want a different internal port. |
| **WG_CLIENT_IP** | Client’s IP in the VPN (e.g. 10.66.66.2) | `10.66.66.2` | Rarely. |
| **WG_SERVER_IP** | Server’s IP in the VPN (e.g. 10.66.66.1) | `10.66.66.1` | Rarely. |

You can copy the defaults from `.env.example` and not change them.

---

## Part 4: Fill the file (checklist)

**Using .env (recommended):**

1. In the `claude-proxy-setup` folder, copy the example:
   ```powershell
   Copy-Item .env.example .env
   ```
2. Open `.env` in a text editor (e.g. Notepad, VS Code, Cursor).
3. Replace **every** placeholder with the value you got:

   - [ ] **SSH_HOST** = your Vultr server IP  
   - [ ] **SSH_USER** = `root` (or your SSH user)  
   - [ ] **SSH_KEY_PATH** = full path to your private key, **or**  
   - [ ] **SSH_PASSWORD** = root password (and comment out or remove SSH_KEY_PATH)  
   - [ ] **BRIGHT_DATA_HOST** = host from Bright Data  
   - [ ] **BRIGHT_DATA_PORT** = port from Bright Data  
   - [ ] **BRIGHT_DATA_USER** = username from Bright Data  
   - [ ] **BRIGHT_DATA_PASS** = password from Bright Data  

4. Save the file. Do not commit `.env` to git or share it; it contains secrets.

**Using secrets.json:**

1. Copy: `Copy-Item secrets.json.example secrets.json`
2. Open `secrets.json` and replace the placeholder strings with the same values as above. Use the exact same names: `SSH_HOST`, `SSH_USER`, `SSH_KEY_PATH` or `SSH_PASSWORD`, `BRIGHT_DATA_HOST`, `BRIGHT_DATA_PORT`, `BRIGHT_DATA_USER`, `BRIGHT_DATA_PASS`.
3. In JSON, strings with backslashes (e.g. Windows paths) need double backslashes:  
   `"C:\\Users\\Kyle\\.ssh\\id_ed25519"`.
4. Save. Do not commit `secrets.json`.

---

## Quick reference: where each value lives

| Value | Where to get it |
|-------|------------------|
| **SSH_HOST** | Vultr → Products → your server → IP Address |
| **SSH_USER** | Usually `root` (see Vultr server overview/settings) |
| **SSH_KEY_PATH** | Your PC: `C:\Users\YourName\.ssh\id_ed25519` (create with `ssh-keygen` if needed) |
| **SSH_PASSWORD** | Vultr → your server → Overview/Settings → Password (if not using a key) |
| **BRIGHT_DATA_HOST** | Bright Data → your zone → Access parameters / Integration → Host |
| **BRIGHT_DATA_PORT** | Same place → Port |
| **BRIGHT_DATA_USER** | Same place → Username |
| **BRIGHT_DATA_PASS** | Same place → Password |

Once all of these are filled in, you can run the setup script as in [STEP-BY-STEP.md](STEP-BY-STEP.md).
