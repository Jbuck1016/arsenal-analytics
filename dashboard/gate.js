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

    // The gate's colours are --gate-* in tokens.css, and they are DELIBERATELY
    // THEME-INDEPENDENT: they sit on :root, not in a light or dark scope,
    // because the gate paints before the page behind it exists and so has no
    // surface to match. theme.js has already settled the root class by the
    // time this runs -- it is loaded ahead of gate.js on every page that has
    // one -- so the gate is inside the theme system rather than outside it,
    // and simply chooses not to vary. Phase 2 changed nothing else here.
    //
    // This <style> is appended
    // to <head>, so it is later in the cascade than the tokens.css link on
    // every page that includes it, whichever order the two tags appear in.
    //
    // ONE FALLBACK, AND ONLY ONE: the overlay's own background keeps #080a0e
    // after the var(). This element is the privacy control -- if its
    // background does not paint, the gated page is legible straight through
    // it. That is worth a duplicated literal in a way the button's hover tint
    // is not, and it is the single case where a missing tokens.css turns a
    // styling failure into a disclosure. Recorded in deliberate-skips.csv.
    var css = document.createElement('style');
    css.textContent =
      '#siteGate{position:fixed;inset:0;z-index:99999;background:var(--gate-ground,#080a0e);' +
      'display:flex;align-items:center;justify-content:center;padding:24px;' +
      "font-family:'Inter',system-ui,sans-serif}" +
      '.gate-card{width:100%;max-width:360px;background:var(--gate-card);' +
      'border:1px solid var(--gate-card-border);' +
      'border-radius:5px;padding:26px 24px;box-shadow:var(--gate-elevation)}' +
      ".gate-mark{font:700 10px/1 'JetBrains Mono',monospace;letter-spacing:.18em;" +
      'color:var(--gate-mark);margin-bottom:9px}' +
      '.gate-title{font:800 22px/1.1 Inter,sans-serif;color:var(--gate-ink);letter-spacing:-.02em}' +
      '.gate-sub{font:400 12.5px/1.6 Inter,sans-serif;color:var(--gate-ink-soft);margin:9px 0 18px}' +
      '#gatePw{width:100%;box-sizing:border-box;background:var(--gate-field);color:var(--gate-ink);' +
      'border:1px solid var(--gate-field-border);border-radius:3px;padding:12px 13px;font-size:14px;outline:none}' +
      '#gatePw:focus{border-color:var(--gate-focus-ring)}' +
      '.gate-remember{display:flex;align-items:center;gap:7px;margin:12px 0 4px;' +
      'font:400 11.5px/1 Inter,sans-serif;color:var(--gate-ink-soft);cursor:pointer}' +
      '#gateGo{width:100%;margin-top:12px;background:var(--gate-action-fill);color:var(--gate-mark);' +
      'border:1px solid var(--gate-action-edge);border-radius:3px;padding:11px;' +
      "font:700 11px/1 'JetBrains Mono',monospace;letter-spacing:.1em;text-transform:uppercase;" +
      'cursor:pointer}' +
      '#gateGo:hover{background:var(--gate-action-fill-hover)}' +
      '.gate-err{min-height:16px;margin-top:10px;font:500 11.5px/1.4 Inter,sans-serif;color:var(--gate-error)}';

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
