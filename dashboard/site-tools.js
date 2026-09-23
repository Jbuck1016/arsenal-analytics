(function () {
  'use strict';

  var DESTINATIONS = [
    ['Explore matches', [
      ['Home', 'index.html'],
      ['Match analysis', 'match.html'],
      ['Possession sequences', 'sequences.html'],
      ['Quick ingest', 'quick-ingest.html']
    ]],
    ['Scout players & teams', [
      ['Player fingerprints', 'players.html'],
      ['Team profiles', 'teams.html'],
      ['Scouting insights', 'insights.html'],
      ['Player search', 'search.html'],
      ['Market values', 'market-values.html']
    ]],
    ['Forecast & investigate', [
      ['Domestic forecasts', 'model-review.html'],
      ['Model laboratory', 'model-lab.html'],
      ['Writing lab', 'writing-lab.html']
    ]],
    ['Learn', [
      ['Field guide', 'guide.html'],
      ['Metric reference', 'glossary.html'],
      ['Methodology', 'methodology.html'],
      ['Validation', 'validation.html']
    ]]
  ];

  function esc(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (char) {
      return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[char];
    });
  }

  function addStyles() {
    if (document.getElementById('fsSiteToolsCss')) return;
    var style = document.createElement('style');
    style.id = 'fsSiteToolsCss';
    style.textContent =
      '.fs-goto{position:relative;display:inline-flex;flex:0 0 auto;z-index:70}' +
      '.fs-goto-btn,.fs-card-export button{appearance:none;border:1px solid var(--border,var(--line2,#34404f));background:var(--surface,var(--bg2,#151b24));color:var(--text,#f1f4f7);font:700 10px/1.1 var(--f-body,Arial,sans-serif);letter-spacing:.055em;text-transform:uppercase;border-radius:6px;padding:7px 10px;cursor:pointer;white-space:nowrap}' +
      '.fs-goto-btn:hover,.fs-card-export button:hover{border-color:var(--accent,var(--red,#e4573d));color:var(--accent,var(--red,#e4573d))}' +
      '.fs-goto-btn:focus-visible,.fs-card-export button:focus-visible,.fs-goto-panel a:focus-visible{outline:2px solid var(--accent,var(--red,#e4573d));outline-offset:2px}' +
      '.fs-goto-btn:after{content:"";display:inline-block;margin-left:7px;vertical-align:2px;border:3.5px solid transparent;border-top-color:currentColor}' +
      '.fs-goto-btn[aria-expanded="true"]:after{transform:rotate(180deg);vertical-align:4px}' +
      '.fs-goto-panel{display:none;position:fixed;z-index:9999;width:244px;max-height:calc(100vh - 70px);overflow:auto;padding:7px;background:var(--bg2,#101720);color:var(--text,#f1f4f7);border:1px solid var(--border2,var(--line2,#34404f));border-radius:9px;box-shadow:0 18px 48px rgba(0,0,0,.34)}' +
      '.fs-goto-panel.open{display:block}.fs-goto-group{padding:8px 9px 5px;color:var(--text3,var(--dim,#8995a5));font:800 9px/1 var(--f-body,Arial,sans-serif);letter-spacing:.16em;text-transform:uppercase}' +
      '.fs-goto-panel a{display:block;padding:8px 9px;border-radius:6px;color:var(--text2,var(--text,#dce3ea));text-decoration:none;font:650 12px/1.15 var(--f-body,Arial,sans-serif)}' +
      '.fs-goto-panel a:hover{background:var(--surface2,var(--bg3,#1d2632));color:var(--text,#fff)}.fs-goto-panel a[aria-current="page"]{color:var(--accent,var(--red,#e4573d));background:var(--accent-dim,rgba(228,87,61,.1))}' +
      '.fs-export-bar{display:flex;justify-content:flex-end;margin:0 0 10px}.fs-card-export{display:inline-flex;gap:5px;margin-left:auto}.fs-card-export button{padding:6px 9px;font-size:9px}' +
      '.fs-exporting{opacity:.62;pointer-events:none}.fs-export-stage{position:fixed;left:-20000px;top:0;width:1120px;padding:28px;background:var(--bg2,#fff);color:var(--text,#111);z-index:-1}' +
      '@media(max-width:720px){.fs-goto-panel{width:min(244px,calc(100vw - 16px))}.fs-goto-btn{padding:7px 8px}}';
    document.head.appendChild(style);
  }

  function currentFile() {
    var name = location.pathname.split('/').pop();
    return name || 'index.html';
  }

  function groupHomeNavigation() {
    if (currentFile() !== 'index.html') return;
    var modules = document.querySelector('.mods');
    if (!modules || modules.classList.contains('enhanced')) return;
    var groups = [
      ['Explore matches', 'Start with a fixture, its events, or a newly completed game.',
        ['match.html', 'sequences.html', 'quick-ingest.html']],
      ['Scout players & teams', 'Move from a profile to comparisons, patterns, and market context.',
        ['players.html', 'teams.html', 'insights.html', 'search.html', 'market-values.html']],
      ['Forecast & write', 'Review the next slate, interrogate the model, or assemble an article.',
        ['model-review.html', 'model-lab.html', 'writing-lab.html']],
      ['Learn the data', 'Definitions and reading guides for every analysis surface.',
        ['glossary.html', 'guide.html']]
    ];
    var cards = Array.from(modules.querySelectorAll(':scope > .mod'));
    var byHref = new Map(cards.map(function (card) { return [card.getAttribute('href'), card]; }));
    if (groups.some(function (group) { return group[2].some(function (href) { return !byHref.has(href); }); })) return;
    groups.forEach(function (group, index) {
      var section = document.createElement('section');
      section.className = 'nav-cluster';
      section.setAttribute('aria-labelledby', 'nav-cluster-' + index);
      section.innerHTML = '<div class="nav-cluster-head"><div><span class="nav-cluster-index">0' + (index + 1) + ' / FUTSCOUT</span><h2 id="nav-cluster-' + index + '">' + esc(group[0]) + '</h2></div><p>' + esc(group[1]) + '</p></div>';
      var grid = document.createElement('div');
      grid.className = 'nav-cluster-grid';
      group[2].forEach(function (href) { grid.appendChild(byHref.get(href)); });
      section.appendChild(grid);
      modules.appendChild(section);
    });
    modules.classList.add('enhanced');
  }

  function gotoHost() {
    return document.getElementById('navMenu') ||
      document.querySelector('.hdr-right') ||
      document.querySelector('header .actions') ||
      document.querySelector('.mast-actions') ||
      document.querySelector('.sys-top .nav') ||
      document.querySelector('.top .nav') ||
      document.querySelector('.hdr .nav') ||
      document.querySelector('header .nav') ||
      document.querySelector('.sys-top') ||
      document.querySelector('.hdr') ||
      document.querySelector('header');
  }

  function installGoto() {
    var host = gotoHost();
    if (!host) return;
    var existing = document.getElementById('fsGoto');
    if (existing) existing.remove();
    var wrap = document.createElement('div');
    wrap.className = 'fs-goto';
    wrap.id = 'fsGoto';
    var file = currentFile();
    var links = DESTINATIONS.map(function (group) {
      return '<div class="fs-goto-group">' + esc(group[0]) + '</div>' +
        group[1].map(function (item) {
          return '<a href="' + item[1] + '"' + (item[1] === file ? ' aria-current="page"' : '') + '>' + esc(item[0]) + '</a>';
        }).join('');
    }).join('');
    wrap.innerHTML = '<button type="button" class="fs-goto-btn" aria-haspopup="true" aria-expanded="false">Go to</button>' +
      '<div class="fs-goto-panel" role="menu">' + links + '</div>';
    if (host.id === 'navMenu') host.replaceChildren(wrap);
    else host.appendChild(wrap);
    var button = wrap.querySelector('button');
    var panel = wrap.querySelector('.fs-goto-panel');

    function place() {
      var rect = button.getBoundingClientRect();
      var right = Math.max(8, window.innerWidth - rect.right);
      if (window.innerWidth - right - 244 < 8) right = 8;
      panel.style.top = Math.round(rect.bottom + 6) + 'px';
      panel.style.right = right + 'px';
    }
    function setOpen(open) {
      panel.classList.toggle('open', open);
      button.setAttribute('aria-expanded', open ? 'true' : 'false');
      if (open) place();
    }
    button.addEventListener('click', function (event) {
      event.stopPropagation();
      setOpen(!panel.classList.contains('open'));
    });
    wrap.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') { setOpen(false); button.focus(); }
    });
    document.addEventListener('pointerdown', function (event) {
      if (!wrap.contains(event.target)) setOpen(false);
    });
    window.addEventListener('resize', function () { if (panel.classList.contains('open')) place(); });
  }

  function safeName(value) {
    return String(value || 'futscout-visual').trim().replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '').toLowerCase();
  }

  function exportLabel(card) {
    var title = card.querySelector('[data-chart-title],.viz-title,.sect-h span,h1,h2,h3');
    return title && title.textContent.trim() ? title.textContent.trim() : 'FutScout visual';
  }

  function loadScript(src, ready) {
    if (ready()) return Promise.resolve();
    return new Promise(function (resolve, reject) {
      var existing = document.querySelector('script[src="' + src + '"]');
      var script = existing || document.createElement('script');
      function done() { ready() ? resolve() : reject(new Error('Export library did not initialize')); }
      script.addEventListener('load', done, {once: true});
      script.addEventListener('error', function () { reject(new Error('Could not load the export library')); }, {once: true});
      if (!existing) { script.src = src; document.head.appendChild(script); }
    });
  }

  async function ensureExportLibraries(format) {
    await loadScript('https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js', function () { return !!window.html2canvas; });
    if (format === 'pdf') {
      await loadScript('https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js', function () { return !!(window.jspdf && window.jspdf.jsPDF); });
    }
  }

  async function captureCard(card, format, button) {
    var label = exportLabel(card);
    button.closest('.fs-card-export').classList.add('fs-exporting');
    try {
      await ensureExportLibraries(format);
    } catch (error) {
      button.closest('.fs-card-export').classList.remove('fs-exporting');
      alert('Export unavailable: ' + error.message);
      return;
    }
    var stage = document.createElement('div');
    stage.className = 'fs-export-stage';
    var clone = card.cloneNode(true);
    clone.querySelectorAll('.fs-card-export,.fs-export-bar,.viz-exp,button,input,select').forEach(function (node) { node.remove(); });
    stage.appendChild(clone);
    document.body.appendChild(stage);
    clone.querySelectorAll('*').forEach(function (node) {
      var style = getComputedStyle(node);
      if (style.overflowY === 'auto' || style.overflowY === 'scroll' || style.maxHeight !== 'none') {
        node.style.maxHeight = 'none';
        node.style.height = 'auto';
        node.style.overflow = 'visible';
      }
    });
    clone.style.maxHeight = 'none';
    clone.style.overflow = 'visible';
    try {
      var bg = getComputedStyle(stage).backgroundColor;
      var canvas = await window.html2canvas(stage, {backgroundColor: bg, scale: 2, useCORS: true, windowWidth: stage.scrollWidth, height: stage.scrollHeight, windowHeight: stage.scrollHeight});
      var base = safeName((document.title || 'FutScout') + '-' + label);
      if (format === 'png') {
        var anchor = document.createElement('a');
        anchor.download = base + '.png';
        anchor.href = canvas.toDataURL('image/png');
        anchor.click();
      } else {
        if (!window.jspdf || !window.jspdf.jsPDF) throw new Error('PDF library is unavailable');
        var jsPDF = window.jspdf.jsPDF;
        var landscape = canvas.width >= canvas.height;
        var pdf = new jsPDF({orientation: landscape ? 'l' : 'p', unit: 'pt', format: 'a4'});
        var pw = pdf.internal.pageSize.getWidth();
        var ph = pdf.internal.pageSize.getHeight();
        var ratio = Math.min((pw - 32) / canvas.width, (ph - 32) / canvas.height);
        pdf.addImage(canvas.toDataURL('image/jpeg', .92), 'JPEG', (pw - canvas.width * ratio) / 2, (ph - canvas.height * ratio) / 2, canvas.width * ratio, canvas.height * ratio, undefined, 'FAST');
        pdf.save(base + '.pdf');
      }
    } catch (error) {
      alert('Export failed: ' + error.message);
    } finally {
      stage.remove();
      button.closest('.fs-card-export').classList.remove('fs-exporting');
    }
  }

  function exportable(card) {
    if (card.matches('.studio-controls,.controls') || card.querySelector('.viz-exp')) return false;
    return !!card.querySelector('svg,canvas,table,.pizza-shell,.rankbar');
  }

  function enhanceExports() {
    document.querySelectorAll('.sect').forEach(function (card) {
      if (!exportable(card) || card.querySelector(':scope > .fs-export-bar,:scope > .sect-h .fs-card-export')) return;
      var controls = document.createElement('div');
      controls.className = 'fs-card-export';
      controls.innerHTML = '<button type="button" data-format="png">PNG</button><button type="button" data-format="pdf">PDF</button>';
      controls.querySelectorAll('button').forEach(function (button) {
        button.setAttribute('aria-label', 'Download ' + exportLabel(card) + ' as ' + button.dataset.format.toUpperCase());
        button.addEventListener('click', function () { captureCard(card, button.dataset.format, button); });
      });
      var heading = card.querySelector(':scope > .sect-h');
      if (heading) heading.appendChild(controls);
      else {
        var bar = document.createElement('div');
        bar.className = 'fs-export-bar';
        bar.appendChild(controls);
        card.insertBefore(bar, card.firstChild);
      }
    });
  }

  function init() {
    addStyles();
    groupHomeNavigation();
    installGoto();
    enhanceExports();
    if (document.body) {
      var queued = false;
      new MutationObserver(function () {
        if (queued) return;
        queued = true;
        requestAnimationFrame(function () { queued = false; enhanceExports(); });
      }).observe(document.body, {childList: true, subtree: true});
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
