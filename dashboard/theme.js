/* One theme control for the whole site.
   ---------------------------------------------------------------------------
   WHAT THIS REPLACES
   Sixteen pages each shipped their own, in two dialects that disagreed about
   what the absence of a stored preference meant. Nine wrote

       if (localStorage.getItem('theme') === 'light') root.classList.remove('dark')

   and relied on the class already being in the markup; six wrote the inverse,
   adding 'dark' unless 'light' was stored. Both defaulted to dark, neither
   read the reader's system preference, and each page repainted its own toggle
   glyph with its own copy of the same three lines.

   MUST BE A CLASSIC SCRIPT IN <head>. Not defer, not async, not module. It has
   to run before the first paint or the page flashes the wrong theme, and the
   browser blocks rendering on a plain <script src> in the head, which is the
   whole mechanism. Every page loads it ahead of tokens.css for the same
   reason, and ahead of gate.js so the password overlay paints into a document
   whose theme is already settled.

   WHAT DECIDES THE THEME, in order:
     1. a ?theme=light or ?theme=dark in the URL, which does NOT persist. It
        is for exports and for linking someone a specific rendering, and
        model-lab.html already relied on it.
     2. an explicit choice this reader has made before, from localStorage.
     3. prefers-color-scheme. FIRST VISIT ONLY: once there is a stored choice
        it wins forever, including over a later change to the system setting,
        because a reader who picked light on a machine that is dark meant it.

   The markup still carries class="dark" on <html>. That is deliberate: if this
   file fails to load, every page keeps the dark default it had before rather
   than rendering unstyled.

   WHAT THIS DOES NOT DO
   It owns no markup. Each page keeps its own toggle button and its own glyph,
   because changing those is a visual decision and this is not the phase for
   one. A page wires its button to FutTheme.toggle() and registers its glyph
   painter with FutTheme.onChange().

       FutTheme.get()        'light' | 'dark'
       FutTheme.isDark()     boolean
       FutTheme.set(mode)    persists, notifies listeners if it changed
       FutTheme.toggle()     returns the new mode
       FutTheme.onChange(fn) fn(mode) on every change, AND once immediately,
                             so a page does not also need an init call
--------------------------------------------------------------------------- */
(function () {
  'use strict';

  var KEY = 'theme';
  var root = document.documentElement;
  var listeners = [];

  function stored() {
    try { return localStorage.getItem(KEY); } catch (e) { return null; }
  }
  function store(mode) {
    try { localStorage.setItem(KEY, mode); } catch (e) { /* private mode */ }
  }
  function systemPrefersLight() {
    try {
      return !!(window.matchMedia &&
                window.matchMedia('(prefers-color-scheme: light)').matches);
    } catch (e) { return false; }
  }
  function fromUrl() {
    try {
      var v = new URLSearchParams(window.location.search).get('theme');
      return (v === 'light' || v === 'dark') ? v : null;
    } catch (e) { return null; }
  }
  function paint(mode) {
    root.classList.toggle('dark', mode !== 'light');
  }

  var urlMode = fromUrl();
  var mode = urlMode || stored() || (systemPrefersLight() ? 'light' : 'dark');
  paint(mode);

  function notify() {
    for (var i = 0; i < listeners.length; i++) {
      // One page's listener throwing must not stop the others, and must not
      // leave the class and the listeners disagreeing about the theme.
      try { listeners[i](mode); }
      catch (e) { if (window.console) console.error('theme listener failed', e); }
    }
  }

  function set(next, persist) {
    next = (next === 'light') ? 'light' : 'dark';
    var changed = (next !== mode);
    mode = next;
    paint(mode);
    if (persist !== false) store(mode);
    if (changed) notify();
    return mode;
  }

  /* Follow the system only while the reader has expressed no preference.
     The moment they pick one, this stops mattering. */
  try {
    if (!stored() && window.matchMedia) {
      var mq = window.matchMedia('(prefers-color-scheme: light)');
      var follow = function (e) { if (!stored()) set(e.matches ? 'light' : 'dark', false); };
      if (mq.addEventListener) mq.addEventListener('change', follow);
      else if (mq.addListener) mq.addListener(follow);
    }
  } catch (e) { /* no matchMedia */ }

  window.FutTheme = {
    get: function () { return mode; },
    isDark: function () { return mode !== 'light'; },
    set: set,
    toggle: function () { return set(mode === 'light' ? 'dark' : 'light'); },
    onChange: function (fn) {
      if (typeof fn !== 'function') return fn;
      listeners.push(fn);
      try { fn(mode); }
      catch (e) { if (window.console) console.error('theme listener failed', e); }
      return fn;
    }
  };
}());
