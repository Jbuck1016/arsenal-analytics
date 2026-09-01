/* ---------------------------------------------------------------------------
   Site gate.

   WHAT THIS IS: a doormat. It keeps the pages from being casually browsed by
   anyone who stumbles on the URL, and it keeps the site out of a shoulder-surfer's
   reach while it is being built.

   WHAT THIS IS NOT: security. Everything here runs in the browser, so anyone who
   opens dev tools can read this file and bypass it. More importantly the Supabase
   anon key is embedded in every page and the tables carry public-read policies,
   so the underlying data is readable through the API whether or not this gate is
   passed. If the data itself ever needs protecting, that means Supabase Auth and
   real RLS policies, not this.

   Because of that: use a password you use NOWHERE ELSE. The hash below lives in a
   public repository. A hash is not plaintext, but it is offline-crackable, so treat
   the password as compromised the moment it is pushed.

   To change it, run this in any browser console and paste the result over HASH:
     crypto.subtle.digest('SHA-256', new TextEncoder().encode('yourNewPassword'))
       .then(b => console.log([...new Uint8Array(b)]
         .map(x => x.toString(16).padStart(2,'0')).join('')))
--------------------------------------------------------------------------- */
(function () {
  // The gate is only a production doormat. Local rendering and screenshot
  // checks must be able to exercise the actual controls without storing or
  // distributing the shared working-build password.
  if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') return;
  var HASH = '1ffe25fc45112b9b3b816d9469f193399ea07014b98570abc3352a59515785e8';
  var KEY = 'siteAccess';
  var FLAG = 'granted-v1';

  try {
    if (sessionStorage.getItem(KEY) === FLAG || localStorage.getItem(KEY) === FLAG) return;
  } catch (e) { /* storage blocked: fall through and ask */ }

  async function sha256(text) {
    var buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
    return Array.from(new Uint8Array(buf))
      .map(function (b) { return b.toString(16).padStart(2, '0'); }).join('');
  }

  function build() {
    var wrap = document.createElement('div');
    wrap.id = 'siteGate';
    wrap.innerHTML =
      '<div class="gate-card">' +
        '<div class="gate-mark">MLS 2026</div>' +
        '<div class="gate-title">Analytics</div>' +
        '<div class="gate-sub">This is a private working build. Enter the password to continue.</div>' +
        '<input id="gatePw" type="password" autocomplete="current-password" ' +
          'placeholder="Password" spellcheck="false">' +
        '<label class="gate-remember"><input type="checkbox" id="gateRemember" checked> ' +
          'Stay signed in on this device</label>' +
        '<button id="gateGo">Enter</button>' +
        '<div class="gate-err" id="gateErr"></div>' +
      '</div>';

    var css = document.createElement('style');
    css.textContent =
      '#siteGate{position:fixed;inset:0;z-index:99999;background:#080a0e;' +
      'display:flex;align-items:center;justify-content:center;padding:24px;' +
      "font-family:'Inter',system-ui,sans-serif}" +
      '.gate-card{width:100%;max-width:360px;background:#0e1116;border:1px solid #1c222c;' +
      'border-radius:5px;padding:26px 24px;box-shadow:0 18px 60px rgba(0,0,0,.55)}' +
      ".gate-mark{font:700 10px/1 'JetBrains Mono',monospace;letter-spacing:.18em;" +
      'color:#e2b877;margin-bottom:9px}' +
      '.gate-title{font:800 22px/1.1 Inter,sans-serif;color:#e8eef6;letter-spacing:-.02em}' +
      '.gate-sub{font:400 12.5px/1.6 Inter,sans-serif;color:#8794a6;margin:9px 0 18px}' +
      '#gatePw{width:100%;box-sizing:border-box;background:#141821;color:#e8eef6;' +
      'border:1px solid #2b333f;border-radius:3px;padding:12px 13px;font-size:14px;outline:none}' +
      '#gatePw:focus{border-color:rgba(226,184,119,.5)}' +
      '.gate-remember{display:flex;align-items:center;gap:7px;margin:12px 0 4px;' +
      'font:400 11.5px/1 Inter,sans-serif;color:#8794a6;cursor:pointer}' +
      '#gateGo{width:100%;margin-top:12px;background:rgba(226,184,119,.12);color:#e2b877;' +
      'border:1px solid rgba(226,184,119,.35);border-radius:3px;padding:11px;' +
      "font:700 11px/1 'JetBrains Mono',monospace;letter-spacing:.1em;text-transform:uppercase;" +
      'cursor:pointer}' +
      '#gateGo:hover{background:rgba(226,184,119,.2)}' +
      '.gate-err{min-height:16px;margin-top:10px;font:500 11.5px/1.4 Inter,sans-serif;color:#ff5f56}';

    document.head.appendChild(css);
    (document.body || document.documentElement).appendChild(wrap);
    document.documentElement.style.overflow = 'hidden';

    var pw = document.getElementById('gatePw');
    var err = document.getElementById('gateErr');
    var tries = 0;
    pw.focus();

    async function attempt() {
      var val = pw.value;
      if (!val) return;
      var ok = false;
      try { ok = (await sha256(val)) === HASH; } catch (e) { ok = false; }
      if (ok) {
        try {
          var store = document.getElementById('gateRemember').checked
            ? localStorage : sessionStorage;
          store.setItem(KEY, FLAG);
        } catch (e) { /* storage blocked: they will be asked again next load */ }
        wrap.remove();
        document.documentElement.style.overflow = '';
        return;
      }
      tries++;
      err.textContent = tries >= 3
        ? 'Still not right. Passwords are case sensitive.'
        : 'Incorrect password.';
      pw.value = '';
      pw.focus();
    }

    document.getElementById('gateGo').addEventListener('click', attempt);
    pw.addEventListener('keydown', function (e) { if (e.key === 'Enter') attempt(); });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', build);
  } else {
    build();
  }
})();
