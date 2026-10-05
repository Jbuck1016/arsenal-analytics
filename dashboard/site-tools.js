(function () {
  'use strict';

  var DESTINATIONS = [
    ['Home', [['Home', 'index.html']]],
    ['Analyze', [
      ['Match analysis', 'match.html'],
      ['Possession sequences', 'sequences.html']
    ]],
    ['Scout', [
      ['Player fingerprints', 'players.html'],
      ['Team profiles', 'teams.html'],
      ['Scouting insights', 'insights.html'],
      ['Player search', 'search.html'],
      ['Market values', 'market-values.html']
    ]],
    ['Models', [
      ['Domestic forecasts', 'model-review.html'],
      ['Model laboratory', 'model-lab.html'],
      ['Worked match review', 'match-review.html']
    ]],
    ['Write', [['Writing lab', 'writing-lab.html'], ['Quick ingest', 'quick-ingest.html']]],
    ['Learn', [
      ['Field guide', 'guide.html'],
      ['Metric reference', 'glossary.html'],
      ['Evidence definitions', 'evidence-contracts.html'],
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
      '.fs-goto-btn,.fs-card-export button{appearance:none;border:1px solid var(--border,var(--line2,#34404f));background:var(--surface,var(--bg2,var(--paper,#fff)));color:var(--text,var(--ink,#151922));font:700 11.5px/1.2 var(--f-body,Arial,sans-serif);letter-spacing:.035em;text-transform:uppercase;border-radius:6px;padding:9px 11px;cursor:pointer;white-space:nowrap}' +
      '.fs-goto-btn:hover,.fs-card-export button:hover{border-color:var(--accent,var(--red,#e4573d));color:var(--accent,var(--red,#e4573d))}' +
      '.fs-goto-btn:focus-visible,.fs-card-export button:focus-visible,.fs-goto-panel a:focus-visible{outline:2px solid var(--accent,var(--red,#e4573d));outline-offset:2px}' +
      '.fs-goto-btn:after{content:"";display:inline-block;margin-left:7px;vertical-align:2px;border:3.5px solid transparent;border-top-color:currentColor}' +
      '.fs-goto-btn[aria-expanded="true"]:after{transform:rotate(180deg);vertical-align:4px}' +
      '.fs-goto-panel{display:none;position:fixed;z-index:9999;width:244px;max-height:calc(100vh - 70px);overflow:auto;padding:7px;background:var(--bg2,var(--paper,#fff));color:var(--text,var(--ink,#151922));border:1px solid var(--border2,var(--line2,#34404f));border-radius:9px;box-shadow:0 18px 48px rgba(0,0,0,.34)}' +
      '.fs-goto-panel.open{display:block}.fs-goto-group{padding:8px 9px 5px;color:var(--text3,var(--dim,#8995a5));font:800 10.5px/1.2 var(--f-body,Arial,sans-serif);letter-spacing:.1em;text-transform:uppercase}' +
      '.fs-goto-panel a{display:block;padding:8px 9px;border-radius:6px;color:var(--text2,var(--text,var(--ink,#151922)));text-decoration:none;font:650 12px/1.15 var(--f-body,Arial,sans-serif)}' +
      '.fs-goto-panel a:hover,.fs-goto-panel a:focus-visible{background:#dce8f5;color:#132b43;outline:2px solid #53799d;outline-offset:-2px}html.dark .fs-goto-panel a:hover,html.dark .fs-goto-panel a:focus-visible{background:#304963;color:#ffffff}.fs-goto-panel a[aria-current="page"]{color:var(--accent,var(--red,#e4573d));background:var(--accent-dim,rgba(228,87,61,.1))}' +
      '.fs-export-bar{display:flex;justify-content:flex-end;margin:0 0 10px}.fs-card-export{display:inline-flex;gap:5px;margin-left:auto}.fs-card-export button{padding:9px 10px;font-size:10.5px}' +
      '.fs-exporting{opacity:.62;pointer-events:none}.fs-export-stage{position:fixed;left:-20000px;top:0;width:1120px;padding:28px;background:var(--bg2,var(--paper,#fff));color:var(--text,var(--ink,#111));z-index:-1}' +
      '@media(max-width:720px){.fs-goto-panel{width:min(244px,calc(100vw - 16px))}.fs-goto-btn{padding:7px 8px}}';
    style.textContent += '.fs-goto-panel,.fs-export-stage{background:var(--overlay,#fffdf8);color:var(--overlay-text,#16191f)}.fs-goto-panel a{color:var(--overlay-text,#16191f);min-height:32px;box-sizing:border-box;display:flex;align-items:center}.fs-goto-panel a:hover,.fs-goto-panel a:focus-visible,html.dark .fs-goto-panel a:hover,html.dark .fs-goto-panel a:focus-visible{background:var(--selection);color:var(--selection-text);outline-color:var(--focus)}@media(max-width:640px){.fs-goto-panel a{min-height:44px}}';
    style.textContent += '.fs-export-stage table td,.fs-export-stage table th,.fs-export-stage .row,.fs-export-stage .row-lbl,.fs-export-stage .row-val,.fs-export-stage .row-pct{font-size:18px!important;line-height:1.45!important}.fs-export-stage .row{min-height:28px}.fs-export-stage table th{letter-spacing:.02em!important}.fs-export-stage table{table-layout:auto!important}';
    style.textContent+='.fs-goto-panel a[aria-current="page"]{background:var(--selection);color:var(--selection-text)}.fs-export-stage *{animation:none!important;transition:none!important}.fs-export-stage .match{opacity:1!important;transform:none!important}.fs-export-stage .frow{font-size:18px!important;min-height:32px}.fs-export-stage .frow>span{overflow-wrap:anywhere}';
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
    var groups = DESTINATIONS.filter(function(group){return group[0]!=='Home';}).map(function(group){return [group[0],'',group[1].map(function(item){return item[1];})];});
    var cards = Array.from(modules.querySelectorAll(':scope > .mod'));
    var byHref = new Map(cards.map(function (card) { return [card.getAttribute('href'), card]; }));
    DESTINATIONS.forEach(function(group){group[1].forEach(function(item){
      if(item[1]==='index.html')return;
      var card=byHref.get(item[1]);
      if(!card){card=document.createElement('a');card.className='mod';card.href=item[1];card.innerHTML='<h2>'+esc(item[0])+'</h2>';byHref.set(item[1],card);}
      var title=card.querySelector('h2,h3,.mod-title,.mod-t');if(title)title.textContent=item[0];
      var numbering=card.querySelector('.mod-k,.mod-num,.mod-i');if(numbering)numbering.remove();
    });});
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
    return document.querySelector('[data-fs-navigation]') || document.getElementById('navMenu') ||
      document.querySelector('.hdr-right') ||
      document.querySelector('header .actions') ||
      document.querySelector('.mast-actions') ||
      document.querySelector('.sys-top .nav') ||
      document.querySelector('.top .nav') ||
      document.querySelector('.hdr .nav') ||
      document.querySelector('header .nav') ||
      document.querySelector('.sys-top') ||
      document.querySelector('.hdr') ||
      document.querySelector('body > nav') ||
      document.querySelector('header');
  }

  function installGoto() {
    var host = gotoHost();
    if(!host){host=document.createElement('nav');host.setAttribute('aria-label','Site navigation');host.style.cssText='display:flex;justify-content:flex-end;padding:8px';document.body.prepend(host)}host.setAttribute('data-fs-navigation','');
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
    wrap.innerHTML = '<button type="button" class="fs-goto-btn" aria-controls="fsDestinationLinks" aria-expanded="false">Go to</button>' +
      '<nav class="fs-goto-panel" id="fsDestinationLinks" aria-label="All FutScout destinations">' + links + '</nav>';
    if (host.id === 'navMenu') host.replaceChildren(wrap);
    else host.appendChild(wrap);
    var button = wrap.querySelector('button');
    var panel = wrap.querySelector('.fs-goto-panel');
    // Stable shared control size; never inherit geometry from an arbitrary neighbour.
    button.style.cssText='min-height:32px;padding:7px 10px;font-size:12px';

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
    var label = exportLabel(card),sourceURL=location.href,exportTime=new Date().toISOString(),clone=card.cloneNode(true),metadata={};try{metadata=JSON.parse(JSON.stringify(card.dataset.exportContext?JSON.parse(card.dataset.exportContext):(typeof window.futScoutExportContext==='function'?window.futScoutExportContext(card):{})))}catch(error){metadata={contextError:'Context unavailable'}}card.querySelectorAll('canvas').forEach(function(source,i){var target=clone.querySelectorAll('canvas')[i];target.width=source.width;target.height=source.height;target.getContext('2d').drawImage(source,0,0)});
    var control=button&&(button.closest('.fs-card-export')||button);
    if(control)control.classList.add('fs-exporting');
    try {
      await ensureExportLibraries(format);
    } catch (error) {
      if(control)control.classList.remove('fs-exporting');
      alert('Export unavailable: ' + error.message);
      return;
    }
    var stage = document.createElement('div');
    stage.className = 'fs-export-stage';
    // The card pixels, metadata and URL were captured before the first await.
    // Immutable metadata captured above.
    // Do not consult live page state after export libraries resolve.
    var context=Object.entries(metadata||{}).filter(function(pair){return !(['url','sourceURL'].includes(pair[0])&&pair[1]===sourceURL)}).map(function(pair){return pair[0]+': '+(typeof pair[1]==='object'?JSON.stringify(pair[1]):pair[1]);}).join(' · ');
    clone.querySelectorAll('.fs-card-export,.fs-export-bar,.viz-exp,[data-export],input,select').forEach(function (node) { node.remove(); });
    clone.querySelectorAll('button').forEach(function(node){var text=document.createElement('span');text.innerHTML=node.innerHTML;text.className=node.className;text.style.cssText=node.style.cssText;node.replaceWith(text);});
    clone.querySelectorAll('details').forEach(function(node){node.open=true;});
    stage.appendChild(clone);
    var footer = document.createElement('p');
    footer.style.cssText='font:18px/1.5 sans-serif;border-top:1px solid currentColor;padding-top:12px;overflow-wrap:anywhere';
    footer.textContent='FutScout · '+label+' · '+(context ? context+' · ' : 'Scope is as labelled in this view; additional provenance not supplied. · ')+'Source page: '+sourceURL+' · Exported '+exportTime+' (export time, not data freshness).';
    stage.appendChild(footer);
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
    // Wide tables must expand the capture surface, not disappear beyond its edge.
    stage.style.width=Math.max(1120,stage.scrollWidth)+'px';
    try {
      var bg = getComputedStyle(stage).backgroundColor;
      var canvas = await window.html2canvas(stage, {backgroundColor: bg, scale: 2, useCORS: true, width:stage.scrollWidth, windowWidth: stage.scrollWidth, height: stage.scrollHeight, windowHeight: stage.scrollHeight,
        onclone: function(doc) {
          // html2canvas 1.4 cannot parse modern color()/oklch() output from color-mix.
          // Let the browser resolve those colours, then serialize an sRGB equivalent.
          var pixel=doc.createElement('canvas'); pixel.width=pixel.height=1;
          var ctx=pixel.getContext('2d'), cache={};
          function rgba(value) {
            if(cache[value]) return cache[value];
            ctx.clearRect(0,0,1,1); ctx.fillStyle=value; ctx.fillRect(0,0,1,1);
            var p=ctx.getImageData(0,0,1,1).data;
            return cache[value]='rgba('+p[0]+','+p[1]+','+p[2]+','+(p[3]/255)+')';
          }
          doc.querySelectorAll('*').forEach(function(node){
            var style=doc.defaultView.getComputedStyle(node);
            ['color','backgroundColor','borderTopColor','borderRightColor','borderBottomColor','borderLeftColor','outlineColor','fill','stroke'].forEach(function(prop){
              var value=style[prop]; if(value && /(?:color|oklch|oklab|lab|lch)\(/.test(value))node.style[prop]=rgba(value);
            });
          });
        }});
      var base = safeName((document.title || 'FutScout') + '-' + label);
      if (format === 'png') {
        var anchor = document.createElement('a');
        anchor.download = base + '.png';
        anchor.href = canvas.toDataURL('image/png');
        anchor.click();
      } else {
        if (!window.jspdf || !window.jspdf.jsPDF) throw new Error('PDF library is unavailable');
        var jsPDF = window.jspdf.jsPDF;
        var landscape = canvas.width / canvas.height >= 1.45;
        var pdf = new jsPDF({orientation: landscape ? 'l' : 'p', unit: 'pt', format: 'a4'});
        var pw = pdf.internal.pageSize.getWidth();
        var ph = pdf.internal.pageSize.getHeight();
        var ratio = (pw - 32) / canvas.width;
        var sliceHeight = Math.floor((ph - 48) / ratio);
        var stageTop=stage.getBoundingClientRect().top;
        var boundaries=Array.from(stage.querySelectorAll('tr,.rank-row,.frow,.match')).map(function(node){var r=node.getBoundingClientRect();return {top:Math.round((r.top-stageTop)*2),bottom:Math.round((r.bottom-stageTop)*2)};});
        var headers=Array.from(stage.querySelectorAll('table')).map(function(table){var head=table.querySelector('thead');if(!head)return null;var h=head.getBoundingClientRect(),t=table.getBoundingClientRect();return {top:Math.round((h.top-stageTop)*2),height:Math.round(h.height*2),bottom:Math.round((t.bottom-stageTop)*2)};}).filter(Boolean);
        for (var offset=0,page=1;offset<canvas.height;page++) {
          if (offset) pdf.addPage();
          var header=offset?headers.find(function(h){return offset>h.top+h.height&&offset<h.bottom;}):null;
          var repeat=header?header.height:0;
          var end=Math.min(canvas.height,offset+sliceHeight-repeat);
          var crossing=boundaries.find(function(row){return row.top>offset&&row.top<end&&row.bottom>end;});
          if(crossing)end=crossing.top;
          var slice=document.createElement('canvas');
          slice.width=canvas.width; slice.height=end-offset;
          slice.getContext('2d').drawImage(canvas,0,offset,canvas.width,slice.height,0,0,canvas.width,slice.height);
          if(header){var headCanvas=document.createElement('canvas');headCanvas.width=canvas.width;headCanvas.height=header.height;headCanvas.getContext('2d').drawImage(canvas,0,header.top,canvas.width,header.height,0,0,canvas.width,header.height);pdf.addImage(headCanvas.toDataURL('image/jpeg',.92),'JPEG',16,16,headCanvas.width*ratio,headCanvas.height*ratio,undefined,'FAST');}
          pdf.addImage(slice.toDataURL('image/jpeg',.92),'JPEG',16,16+repeat*ratio,slice.width*ratio,slice.height*ratio,undefined,'FAST');
          pdf.setFontSize(9); pdf.text('FutScout · '+page,16,ph-12);
          offset=end;
        }
        pdf.save(base + '.pdf');
      }
    } catch (error) {
      alert('Export failed: ' + error.message);
    } finally {
      stage.remove();
      if(control)control.classList.remove('fs-exporting');
    }
  }

  window.FutScoutExports={capture:captureCard};
  function exportTable(card){
    var rows=Array.from(card.querySelectorAll('table tr')).map(function(row){return Array.from(row.querySelectorAll('th,td')).map(function(cell){return '"'+cell.textContent.trim().replace(/"/g,'""')+'"';}).join(',');});
    rows.unshift('"FutScout source","'+location.href.replace(/"/g,'""')+'"');
    var meta=typeof window.futScoutExportContext==='function'?window.futScoutExportContext(card):{};
    rows.unshift('"Context","'+JSON.stringify(meta).replace(/"/g,'""')+'"');
    var url=URL.createObjectURL(new Blob(['\uFEFF'+rows.join('\r\n')],{type:'text/csv;charset=utf-8'})),a=document.createElement('a');a.href=url;a.download=safeName(exportLabel(card))+'.csv';a.click();setTimeout(function(){URL.revokeObjectURL(url)},1000);
  }

  function exportable(card) {
    if (card.closest('.fs-export-stage') || card.matches('.studio-controls,.controls,[data-export-manual]') || card.querySelector('.viz-exp,[data-export]')) return false;
    return !!card.querySelector('svg,canvas,table,.pizza-shell,.rankbar');
  }

  function enhanceExports() {
    document.querySelectorAll('.sect,.panel,[data-export-card]').forEach(function (card) {
      if (card.querySelector('.sect,.panel,[data-export-card]')) return;
      if (!exportable(card) || card.querySelector(':scope > .fs-export-bar,:scope > .sect-h .fs-card-export')) return;
      var controls = document.createElement('div');
      controls.className = 'fs-card-export';
      controls.innerHTML = '<button type="button" data-format="png">PNG</button><button type="button" data-format="pdf">PDF</button>';
      if(card.querySelector('table'))controls.insertAdjacentHTML('beforeend','<button type="button" data-format="csv">CSV</button>');
      controls.querySelectorAll('button').forEach(function (button) {
        button.setAttribute('aria-label', 'Download ' + exportLabel(card) + ' as ' + button.dataset.format.toUpperCase());
        button.addEventListener('click', function () { if(button.dataset.format==='csv')exportTable(card);else captureCard(card, button.dataset.format, button); });
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
    if(!document.querySelector('link[href*="theme.css"]')){var theme=document.createElement('link');theme.rel='stylesheet';theme.href='theme.css';document.head.appendChild(theme);}
    addStyles();
    groupHomeNavigation();
    installGoto();
    if(['methodology.html','guide.html','validation.html','evidence-contracts.html'].includes(currentFile())){
      document.querySelectorAll('table').forEach(function(table){if(table.parentElement.classList.contains('fs-table-scroll'))return;var region=document.createElement('div');region.className='fs-table-scroll';region.style.cssText='max-width:100%;overflow:auto';region.tabIndex=0;region.setAttribute('role','region');region.setAttribute('aria-label','Scrollable evidence table');table.before(region);region.appendChild(table);});
    }
    if(currentFile()==='evidence-contracts.html'){
      document.documentElement.classList.toggle('dark',localStorage.getItem('theme')==='dark');
      var themeButton=document.createElement('button');themeButton.type='button';themeButton.textContent='Light / dark';themeButton.onclick=function(){var dark=document.documentElement.classList.toggle('dark');localStorage.setItem('theme',dark?'dark':'light');};document.querySelector('body > nav').appendChild(themeButton);
      document.body.style.background='var(--bg)';
    }
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

