# Xray Backend Guide

> Connect your existing Xray panel (3x-ui) to a DNS tunnel for censorship-resistant proxy access.

---

## What Is This?

If you have both a DNS tunnel (via dnstm-setup) and a 3x-ui panel, they currently work independently. The DNS tunnel only offers a basic SOCKS5 proxy — no user management, no traffic stats, no data limits. The 3x-ui panel has all of that, but its protocols (VLESS, etc.) can be blocked directly.

With `--add-xray`, you connect Xray to the DNS tunnel so that Xray protocols travel inside DNS queries. Censors only see normal DNS traffic — the Xray protocol is completely hidden.

> **This feature is fully optional.** Your existing tunnels continue to work without any changes.

---

## Traffic Flow

```
Phone (SlipNet + Nekobox)
  │
  ├── SlipNet       → establishes the DNS tunnel (DNS queries on port 53)
  │                       → Your server: DNSTT decodes traffic
  │                            → Xray inbound (127.0.0.1 only)
  │                                 → Free internet
  │
  └── Nekobox       → speaks the Xray protocol (VLESS/SS/VMess/Trojan)
        └── chained through SlipNet's SOCKS proxy
```

---

## Speed & Stability

> **Important:** This feature does NOT change the speed or stability of the DNS tunnel. The bottleneck is the DNS path, which is unchanged. What changes is management capability.

---

## What Do You Gain?

The script creates one inbound with one UUID or password. After setup, you can add more users from the **3x-ui dashboard**. These are features of the 3x-ui panel itself, now accessible through the DNS tunnel:

| Feature | Without Xray | With Xray |
|---|---|---|
| User management | Single SOCKS5 user only | Per-user from panel |
| Traffic stats | None | Per-user in dashboard |
| Data limits | None | Configurable |
| Expiry dates | None | Configurable |
| Protocol | SOCKS5 only | VLESS / SS / VMess / Trojan |
| Disable a user | Change the single password | One click in panel (per-user) |

---

## Prerequisites

- **dnstm-setup** already installed (completed the 12-step setup)
- `curl` and `jq` on the server (`jq` is auto-installed if missing)
- **3x-ui is optional** — if not installed, the script offers to install it

---

## Server Setup

### Step 1: Run the command

```bash
sudo bash dnstm-setup.sh --add-xray
```

Or from the management menu:

```bash
sudo bash dnstm-setup.sh --manage
# Select option 8 → Xray backend
```

### Step 2: Panel detection

The script auto-detects 3x-ui (native or Docker). If not found, it offers two options:

1. **Full panel (3x-ui)** — web dashboard, user management, traffic stats
2. **Headless (Xray only)** — no web panel, lightweight, config-based

If you choose the full panel, you'll set an admin username, password, and panel port.

### Step 3: Choose protocol

| Protocol | Description |
|---|---|
| **VLESS** | Lightweight, recommended |
| **Shadowsocks** | Widely supported, simple |
| **VMess** | V2Ray protocol |
| **Trojan** | HTTPS-like traffic |

### Step 4: Inbound & tunnel creation

The script automatically:

1. Creates a new inbound on `127.0.0.1` — **not accessible from the internet**, only reachable through the DNS tunnel
2. Creates a DNSTT tunnel for subdomain `x`
3. Connects the tunnel to the Xray inbound

### Step 5: Get your links

Two links are displayed:

- **Link 1:** `slipnet://...` — for the DNS tunnel (import into SlipNet)
- **Link 2:** Client URI — depending on your chosen protocol: `vless://` or `ss://` or `vmess://` or `trojan://` (import into Nekobox/v2rayNG)

Copy both.

### Step 6: DNS record

Add this record in **Cloudflare**:

| Type | Name | Value | Proxy |
|---|---|---|---|
| `NS` | `x` | `ns.yourdomain.com` | OFF (grey cloud) |

This delegates `x.yourdomain.com` to your server, just like the other tunnel subdomains.

---

## Phone Setup

### Why two apps?

The Xray inbound listens on `127.0.0.1` (localhost) on the server. This is intentional — it is **not exposed to the internet**, so censors cannot detect or block it. The only way to reach it is through the DNS tunnel.

This is how the two apps work together:

1. **SlipNet** creates a DNS tunnel between your phone and the server. On your phone, it opens a local SOCKS proxy on `127.0.0.1:1080`. On the server side, traffic exits the tunnel and arrives at localhost — where Xray is listening.

2. **Nekobox** speaks the Xray protocol (VLESS/VMess/etc). You tell Nekobox to send its traffic through SlipNet's SOCKS proxy (`127.0.0.1:1080`). Nekobox thinks it's connecting to `127.0.0.1` on the server — and it is, because the tunnel makes server's localhost reachable from your phone.

```
Your phone                          Your server
──────────                          ───────────
Nekobox (vless://127.0.0.1:PORT)
    │
    └──→ SlipNet SOCKS (127.0.0.1:1080)
              │
              └──→ DNS queries (port 53) ──→ DNSTT decodes
                                                  │
                                                  └──→ 127.0.0.1:PORT (Xray)
                                                            │
                                                            └──→ Internet
```

> **The vless:// link alone will NOT work** — without SlipNet, there is no tunnel, and `127.0.0.1` on the server is unreachable from your phone.

### Required apps

You need two apps:

- **SlipNet** — creates the DNS tunnel ([download](https://github.com/anonvector/SlipNet/releases))
- **Nekobox** or **v2rayNG** or any V2Ray client — speaks the Xray protocol through the tunnel

Any client that supports **proxy chaining** works:

| Platform | Apps |
|---|---|
| Android | Nekobox, v2rayNG, Hiddify, Clash Meta |
| Desktop | Nekoray, v2rayN, Clash Verge |

> **Note:** SlipNet is currently Android-only. iOS is not supported yet.

### Step 1: Import tunnel into SlipNet

Open SlipNet and import the first link (`slipnet://...`). The tunnel profile is created automatically.

### Step 2: Enable Proxy Only Mode

In SlipNet profile settings, enable **Proxy Only Mode**. This makes SlipNet act as a pure tunnel — it creates a local SOCKS proxy on `127.0.0.1:1080`.

### Step 3: Import protocol into Nekobox

Open Nekobox (or v2rayNG) and import the second link. Proxy settings are configured automatically.

### Step 4: Set up proxy chain

In Nekobox, go to proxy settings and find **Outbound proxy** or **chain**:

- **Type:** `SOCKS5`
- **Address:** `127.0.0.1`
- **Port:** `1080`

This routes Nekobox traffic through SlipNet's DNS tunnel.

### Step 5: Enable UDP over TCP

In **both apps** (SlipNet and Nekobox), find and enable **UDP over TCP**. This improves connection stability.

### Step 6: Bypass SlipNet from routing (prevent loops)

In Nekobox, go to **Route settings** → **App routing**. Add **SlipNet** to the **bypass/direct** list.

> **This step is critical.** Without it, Nekobox tries to route SlipNet's own DNS traffic through the tunnel, creating a loop. Nothing will work.

### Connect

1. **First** connect SlipNet
2. **Then** turn on Nekobox

The order matters — Nekobox depends on SlipNet's SOCKS proxy being active.

---

## Removing an Xray Tunnel

```bash
sudo bash dnstm-setup.sh --remove-tunnel xray1
```

This removes the DNSTT tunnel and service override. The Xray inbound is **not automatically removed**:

- **Panel mode (3x-ui):** Delete the inbound from the web dashboard
- **Headless mode:** Edit `/usr/local/etc/xray/config.json` manually

---

## FAQ

**Does this increase tunnel speed?**
No. The DNS path is the bottleneck and is unchanged. The benefit is better user management.

**Do I need 3x-ui?**
No. If not installed, the script offers to install it (full panel or headless).

**Does it work with iOS?**
Not yet. SlipNet is currently Android-only. iOS support is planned.

**Will my existing tunnels break?**
No. This feature is completely separate. Slipstream, DNSTT, and NoizDNS tunnels are untouched.

---

## Links

- **Project:** [github.com/SamNet-dev/dnstm-setup](https://github.com/SamNet-dev/dnstm-setup)
- **SlipNet:** [github.com/anonvector/SlipNet](https://github.com/anonvector/SlipNet/releases)
- **3x-ui:** [github.com/mhsanaei/3x-ui](https://github.com/mhsanaei/3x-ui)

---

<div dir="rtl">

# راهنمای Xray Backend

> اتصال پنل Xray (3x-ui) به تانل DNS برای دسترسی ضد سانسور

---

## این قابلیت چیه؟

خیلی از شما هم تانل DNS دارید (با dnstm-setup) و هم پنل 3x-ui. مشکل اینه که این دوتا جدا از هم کار می‌کنن. تانل DNS فقط یه پراکسی SOCKS5 ساده داره — نه مدیریت کاربر دارید، نه آمار ترافیک، نه محدودیت حجم. از طرف دیگه پنل 3x-ui همه این‌ها رو داره ولی پروتکل‌هاش مستقیم قابل مسدود شدنه.

با دستور `--add-xray` می‌تونید پنل Xray رو به تانل DNS وصل کنید تا پروتکل‌های Xray از داخل تانل DNS رد بشن. سانسورچی فقط کوئری DNS عادی می‌بینه و پروتکل Xray کاملاً مخفیه.

**این قابلیت کاملاً اختیاریه** و تانل‌های قبلیتون بدون تغییر کار می‌کنن.

---

## مسیر ترافیک

</div>

```
Phone (SlipNet + Nekobox) / گوشی
  │
  ├── SlipNet       → DNS tunnel (port 53) / تانل DNS از پورت ۵۳
  │                       → Server: DNSTT decodes / سرور: DNSTT دیکد می‌کنه
  │                            → Xray inbound (127.0.0.1)
  │                                 → Free internet / اینترنت آزاد
  │
  └── Nekobox       → Xray protocol (VLESS/SS/VMess/Trojan) / پروتکل Xray
        └── chained through SlipNet / از طریق SlipNet زنجیره میشه
```

<div dir="rtl">

---

## سرعت و پایداری

**مهم:** این قابلیت سرعت یا پایداری تانل DNS رو تغییر نمیده. گلوگاه همون مسیر DNS هست و تغییر نکرده. چیزی که عوض میشه قابلیت مدیریته.

---

## چه فایده‌ای داره؟

اسکریپت یه اینباند با یه UUID یا رمز می‌سازه. بعد از راه‌اندازی، می‌تونید از **داشبورد 3x-ui** کاربرهای بیشتر اضافه کنید. این‌ها قابلیت‌های خود پنل 3x-ui هستن که حالا از طریق تانل DNS قابل استفاده شدن:

| قابلیت | بدون Xray | با Xray |
|---|---|---|
| مدیریت کاربر | فقط یک کاربر SOCKS5 | هر کاربر جدا از پنل |
| آمار ترافیک | نداره | برای هر کاربر در داشبورد |
| محدودیت حجم | نداره | قابل تنظیم |
| تاریخ انقضا | نداره | قابل تنظیم |
| پروتکل | فقط SOCKS5 | VLESS / SS / VMess / Trojan |
| غیرفعال کردن کاربر | رمز رو عوض کن | یه کلیک توی پنل (فقط اون کاربر) |

---

## پیش‌نیازها

- **dnstm-setup** قبلاً نصب شده باشه (۱۲ مرحله اصلی رو انجام داده باشید)
- `curl` و `jq` روی سرور باشن (`jq` خودکار نصب میشه)
- **پنل 3x-ui اختیاریه** — اگه نداشته باشید اسکریپت پیشنهاد نصب میده

---

## راه‌اندازی سمت سرور

**مرحله ۱:** دستور رو اجرا کنید:

</div>

```bash
sudo bash dnstm-setup.sh --add-xray
```

<div dir="rtl">

یا از منوی مدیریت: `--manage` و بعد گزینه ۸

**مرحله ۲:** اسکریپت خودش پنل 3x-ui رو پیدا می‌کنه. اگه پنل نداشته باشید دو گزینه میده: نصب پنل کامل با داشبورد وب، یا نصب سبک بدون داشبورد.

**مرحله ۳:** پروتکل مورد نظرتون رو انتخاب کنید:

| پروتکل | توضیح |
|---|---|
| **VLESS** | سبک‌ترین، پیشنهادی |
| **Shadowsocks** | پشتیبانی گسترده، ساده |
| **VMess** | پروتکل V2Ray |
| **Trojan** | شبیه ترافیک HTTPS |

**مرحله ۴:** اسکریپت خودکار یه اینباند جدید روی `127.0.0.1` می‌سازه. این اینباند از اینترنت قابل دسترس نیست و فقط از داخل تانل DNS بهش می‌شه وصل شد. بعد یه تانل DNSTT برای ساب‌دامین `x` می‌سازه و وصلش می‌کنه به اینباند.

**مرحله ۵:** دوتا لینک بهتون نمایش داده میشه. لینک اول `slipnet://` برای تانل و لینک دوم لینک کلاینت بسته به پروتکل انتخابی (`vless://` یا `ss://` یا `vmess://` یا `trojan://`). هر دوتا رو کپی کنید.

**مرحله ۶:** توی Cloudflare یه رکورد DNS جدید بسازید:

| Type | Name | Value | Proxy |
|---|---|---|---|
| `NS` | `x` | `ns.yourdomain.com` | خاموش (ابر خاکستری) |

---

## راه‌اندازی سمت گوشی

### چرا دو تا اپ لازمه؟

اینباند Xray روی `127.0.0.1` (localhost) سرور گوش میده. این عمدیه — از اینترنت قابل دسترسی نیست و سانسورچی نمیتونه ببینتش یا بلاکش کنه. تنها راه دسترسی بهش از داخل تانل DNS هست.

دو تا اپ اینجوری با هم کار می‌کنن:

**SlipNet** یه تانل DNS بین گوشی و سرور میسازه. توی گوشیتون یه پراکسی SOCKS محلی روی `127.0.0.1:1080` باز میکنه. سمت سرور، ترافیک از تانل خارج میشه و به localhost سرور میرسه — جایی که Xray گوش میده.

**Nekobox** پروتکل Xray (مثلاً VLESS) رو حرف میزنه. بهش میگید ترافیکش رو از پراکسی SlipNet (`127.0.0.1:1080`) رد کنه. Nekobox فکر میکنه داره به `127.0.0.1` سرور وصل میشه — و واقعاً هم همینه، چون تانل باعث میشه localhost سرور از گوشیتون قابل دسترسی باشه.

</div>

```
گوشی شما                              سرور شما
──────────                            ───────────
Nekobox (vless://127.0.0.1:PORT)
    │
    └──→ SlipNet SOCKS (127.0.0.1:1080)
              │
              └──→ DNS queries (port 53) ──→ DNSTT decodes
                                                  │
                                                  └──→ 127.0.0.1:PORT (Xray)
                                                            │
                                                            └──→ اینترنت آزاد
```

<div dir="rtl">

**لینک vless:// به تنهایی کار نمیکنه** — بدون SlipNet تانلی وجود نداره و `127.0.0.1` سرور از گوشیتون قابل دسترسی نیست.

### اپ‌های مورد نیاز

دو تا اپ لازم دارید:

- **SlipNet** — تانل DNS رو میسازه ([دانلود](https://github.com/anonvector/SlipNet/releases))
- **Nekobox** یا **v2rayNG** یا هر کلاینت V2Ray دیگه — پروتکل Xray رو از داخل تانل رد میکنه

هر کلاینتی که **زنجیره پراکسی** (proxy chain) پشتیبانی کنه کار می‌کنه:

| پلتفرم | اپ‌ها |
|---|---|
| Android | Nekobox, v2rayNG, Hiddify, Clash Meta |
| Desktop | Nekoray, v2rayN, Clash Verge |

**توجه:** SlipNet فعلاً فقط برای اندروید هست. پشتیبانی iOS هنوز اضافه نشده.

**مرحله ۱:** اپ SlipNet رو باز کنید و لینک اول (`slipnet://`) رو وارد کنید. پروفایل تانل خودکار ساخته میشه.

**مرحله ۲:** توی تنظیمات پروفایل SlipNet، حالت **Proxy Only Mode** رو فعال کنید. با این کار SlipNet فقط یه تانل میشه و یه پراکسی محلی روی `127.0.0.1:1080` ساخته میشه.

**مرحله ۳:** اپ Nekobox (یا v2rayNG) رو باز کنید و لینک دوم رو وارد کنید. تنظیمات پراکسی خودکار ساخته میشه.

**مرحله ۴:** توی Nekobox برید به تنظیمات پراکسی و قسمت **Outbound proxy** یا **chain** رو پیدا کنید. نوع رو بذارید SOCKS5 و آدرس رو `127.0.0.1` و پورت رو `1080`. این باعث میشه ترافیک Nekobox از داخل تانل SlipNet رد بشه.

**مرحله ۵:** توی هر دو اپ (SlipNet و Nekobox) گزینه **UDP over TCP** رو فعال کنید. این کار پایداری اتصال رو بهتر می‌کنه.

**مرحله ۶:** توی Nekobox برید به **Route settings** و بعد **App routing**. اپ SlipNet رو به لیست **بایپس** اضافه کنید. **این مرحله خیلی مهمه** — بدون این کار Nekobox سعی می‌کنه ترافیک خود SlipNet رو از تانل رد کنه و لوپ ایجاد میشه.

**اتصال:** اول SlipNet رو وصل کنید و بعد Nekobox رو روشن کنید. ترتیب مهمه.

---

## حذف تانل Xray

</div>

```bash
sudo bash dnstm-setup.sh --remove-tunnel xray1
```

<div dir="rtl">

این دستور تانل و تنظیمات سرویس رو حذف می‌کنه. اینباند Xray خودکار حذف نمیشه — اگه پنل دارید از داشبورد حذف کنید، اگه headless هست فایل `config.json` رو دستی ویرایش کنید.

---

## سوالات متداول

**سرعت تانل بیشتر میشه؟** نه. گلوگاه سرعت تانل DNS هست و تغییر نکرده. فایده‌ش مدیریت بهتر کاربرهاست.

**حتماً باید 3x-ui داشته باشم؟** نه. اسکریپت پیشنهاد نصب میده. حالت بدون داشبورد هم هست.

**با iOS کار می‌کنه؟** فعلاً نه. SlipNet فقط برای اندروید هست. پشتیبانی iOS در برنامه هست.

**تانل‌های قبلیم خراب میشه؟** نه. این قابلیت کاملاً جداست.

---

## لینک‌ها

- **پروژه:** [github.com/SamNet-dev/dnstm-setup](https://github.com/SamNet-dev/dnstm-setup)
- **SlipNet:** [github.com/anonvector/SlipNet](https://github.com/anonvector/SlipNet/releases)
- **3x-ui:** [github.com/mhsanaei/3x-ui](https://github.com/mhsanaei/3x-ui)

</div>
