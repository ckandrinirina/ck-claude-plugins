/* ck-claude-plugins — interactions: theme, nav, copy, reveal, changelog */
(function () {
  'use strict';

  /* ---------- Theme (persisted, defaults dark) ---------- */
  var root = document.documentElement;
  try {
    var saved = localStorage.getItem('ckp-theme');
    if (saved) root.setAttribute('data-theme', saved);
  } catch (e) {}

  function toggleTheme() {
    var cur = root.getAttribute('data-theme') === 'light' ? 'light' : 'dark';
    var next = cur === 'light' ? 'dark' : 'light';
    root.setAttribute('data-theme', next);
    try { localStorage.setItem('ckp-theme', next); } catch (e) {}
  }

  /* ---------- Mobile nav ---------- */
  function bind() {
    var tBtn = document.querySelector('[data-theme-toggle]');
    if (tBtn) tBtn.addEventListener('click', toggleTheme);

    var navToggle = document.querySelector('[data-nav-toggle]');
    var navLinks = document.querySelector('[data-nav-links]');
    if (navToggle && navLinks) {
      navToggle.addEventListener('click', function () { navLinks.classList.toggle('open'); });
      navLinks.addEventListener('click', function (e) {
        if (e.target.tagName === 'A') navLinks.classList.remove('open');
      });
    }

    /* ---------- Copy buttons ---------- */
    document.querySelectorAll('[data-copy]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var text = btn.getAttribute('data-copy');
        var done = function () {
          btn.classList.add('copied');
          btn.innerHTML = CHECK_SVG;
          setTimeout(function () { btn.classList.remove('copied'); btn.innerHTML = COPY_SVG; }, 1600);
        };
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(done).catch(fallbackCopy.bind(null, text, done));
        } else { fallbackCopy(text, done); }
      });
    });

    /* ---------- Scroll reveal ---------- */
    var reveals = document.querySelectorAll('.reveal');
    if ('IntersectionObserver' in window && reveals.length) {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (en) {
          if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); }
        });
      }, { threshold: 0.12, rootMargin: '0px 0px -8% 0px' });
      reveals.forEach(function (el) { io.observe(el); });
    } else {
      reveals.forEach(function (el) { el.classList.add('in'); });
    }

    /* ---------- Changelog ---------- */
    if (document.querySelector('[data-changelog]')) initChangelog();
  }

  function fallbackCopy(text, done) {
    var ta = document.createElement('textarea');
    ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.appendChild(ta); ta.select();
    try { document.execCommand('copy'); done(); } catch (e) {}
    document.body.removeChild(ta);
  }

  var COPY_SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>';
  var CHECK_SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>';

  /* ===================== Changelog renderer ===================== */
  function initChangelog() {
    var tabs = document.querySelectorAll('[data-cl-tab]');
    tabs.forEach(function (tab) {
      tab.addEventListener('click', function () {
        tabs.forEach(function (t) { t.classList.remove('active'); });
        document.querySelectorAll('[data-cl-panel]').forEach(function (p) { p.classList.remove('active'); });
        tab.classList.add('active');
        var panel = document.querySelector('[data-cl-panel="' + tab.getAttribute('data-cl-tab') + '"]');
        if (panel) { panel.classList.add('active'); loadChangelog(panel); }
      });
    });
    var first = document.querySelector('[data-cl-panel].active');
    if (first) loadChangelog(first);
  }

  function loadChangelog(panel) {
    if (panel.getAttribute('data-loaded')) return;
    panel.setAttribute('data-loaded', '1');
    var src = panel.getAttribute('data-src');
    var repo = panel.getAttribute('data-repo');
    fetch(src, { cache: 'no-cache' })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.text(); })
      .then(function (md) {
        panel.querySelector('.cl-doc').innerHTML = renderMarkdown(md);
      })
      .catch(function () {
        panel.querySelector('.cl-doc').innerHTML =
          '<p class="cl-error">Could not load the changelog here. ' +
          'View the full history on <a href="' + repo + '/blob/main/CHANGELOG.md">GitHub</a>.</p>';
      });
  }

  /* Minimal, safe Keep-a-Changelog markdown -> HTML (no external deps) */
  function esc(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

  function inline(s) {
    s = esc(s);
    s = s.replace(/`([^`]+)`/g, '<code>$1</code>');
    s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" rel="noopener" target="_blank">$1</a>');
    return s;
  }

  function renderMarkdown(md) {
    var lines = md.replace(/\r\n/g, '\n').split('\n');
    var html = [];
    var inList = false;
    function closeList() { if (inList) { html.push('</ul>'); inList = false; } }

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var m;
      if (/^#\s+/.test(line)) { closeList(); continue; } // skip top title
      if ((m = line.match(/^##\s+(.*)$/))) {
        closeList();
        var head = m[1];
        var vm = head.match(/\[([^\]]+)\]\s*(?:[—\-–]\s*(.*))?/);
        if (vm) {
          var ver = vm[1];
          var date = vm[2] ? vm[2].trim() : '';
          var pill = '<span class="ver-pill">' + esc(ver) + '</span>';
          var dateHtml = date ? '<span class="cl-meta" style="margin:0">' + esc(date) + '</span>' : '';
          var anchor = ver.replace(/[^a-z0-9.]/gi, '-');
          html.push('<h2 id="v-' + anchor + '">' + pill + dateHtml + '</h2>');
        } else {
          html.push('<h2>' + inline(head) + '</h2>');
        }
        continue;
      }
      if ((m = line.match(/^###\s+(.*)$/))) { closeList(); html.push('<h3>' + inline(m[1]) + '</h3>'); continue; }
      if ((m = line.match(/^\s*[-*]\s+(.*)$/))) {
        if (!inList) { html.push('<ul>'); inList = true; }
        html.push('<li>' + inline(m[1]) + '</li>');
        continue;
      }
      if (/^\s*$/.test(line)) { closeList(); continue; }
      if (/^\[.*\]:\s/.test(line)) { continue; } // reference defs
      closeList();
      html.push('<p>' + inline(line) + '</p>');
    }
    closeList();
    return html.join('\n');
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind);
  else bind();
})();
