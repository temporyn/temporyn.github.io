/* Temporyn — 테마 토글 / 트리 / 검색 */
(function () {
  'use strict';

  var BASE = (document.body && document.body.dataset.baseurl) || '';

  /* ── 테마 토글 (localStorage 저장) ─────────────────────────────────── */
  (function themeToggle() {
    var btn = document.getElementById('theme-toggle');
    if (!btn) return;

    // 기본은 항상 라이트. 시스템 설정은 참조하지 않는다.
    function current() {
      return document.documentElement.getAttribute('data-theme') || 'light';
    }
    btn.addEventListener('click', function () {
      var next = current() === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      try { localStorage.setItem('temporyn-theme', next); } catch (e) {}
    });
  })();

  /* ── 사이드바 트리 ─────────────────────────────────────────────────── */
  var OPEN_KEY = 'temporyn-open';

  function loadOpen() {
    try { return new Set(JSON.parse(localStorage.getItem(OPEN_KEY) || '[]')); }
    catch (e) { return new Set(); }
  }
  function saveOpen(set) {
    try { localStorage.setItem(OPEN_KEY, JSON.stringify(Array.from(set))); }
    catch (e) {}
  }
  function normalize(p) {
    try { p = decodeURIComponent(p); } catch (e) {}
    if (p.charAt(p.length - 1) !== '/') p += '/';
    return p;
  }

  (function tree() {
    var nav = document.getElementById('nav-tree');
    if (!nav) return;

    var open = loadOpen();

    // 1) 저장된 펼침 상태 복원
    nav.querySelectorAll('.tree-dir').forEach(function (li) {
      if (open.has(li.dataset.path)) li.classList.add('open');
    });

    // 2) 현재 문서 경로 → active 표시 + 조상 폴더 펼침(상태 저장)
    var cur = normalize(location.pathname);
    var changed = false;
    nav.querySelectorAll('.tree-file').forEach(function (li) {
      var full = normalize(BASE + li.dataset.url);
      if (full === cur) {
        li.classList.add('active');
        var p = li.parentElement;
        while (p && p !== nav) {
          if (p.classList && p.classList.contains('tree-dir')) {
            p.classList.add('open');
            if (!open.has(p.dataset.path)) { open.add(p.dataset.path); changed = true; }
          }
          p = p.parentElement;
        }
        li.scrollIntoView({ block: 'center' });
      }
    });
    if (changed) saveOpen(open);

    // 3) 폴더 토글
    nav.addEventListener('click', function (e) {
      var btn = e.target.closest('.tree-toggle');
      if (!btn) return;
      var li = btn.parentElement;
      li.classList.toggle('open');
      if (li.classList.contains('open')) open.add(li.dataset.path);
      else open.delete(li.dataset.path);
      saveOpen(open);
    });
  })();

  /* ── 전문 검색 ─────────────────────────────────────────────────────── */
  (function search() {
    var input = document.getElementById('search-input');
    var results = document.getElementById('search-results');
    var navTree = document.getElementById('nav-tree');
    if (!input || !results || !navTree) return;

    var index = null, loading = false;

    function ensureIndex(cb) {
      if (index) return cb();
      if (loading) return;
      loading = true;
      fetch(BASE + '/assets/search-index.json')
        .then(function (r) { return r.json(); })
        .then(function (data) { index = data; loading = false; cb(); })
        .catch(function () { loading = false; });
    }

    function showTree() {
      results.hidden = true;
      results.innerHTML = '';
      navTree.hidden = false;
    }
    function snippet(text, q) {
      var i = text.toLowerCase().indexOf(q);
      if (i < 0) return '';
      var start = Math.max(0, i - 25);
      return (start > 0 ? '…' : '') + text.substr(start, 70) + '…';
    }
    function render(q) {
      var ql = q.toLowerCase();
      var hits = index.filter(function (d) {
        return d.title.toLowerCase().indexOf(ql) >= 0 ||
               (d.content && d.content.toLowerCase().indexOf(ql) >= 0);
      }).slice(0, 30);

      navTree.hidden = true;
      results.hidden = false;
      if (!hits.length) {
        results.innerHTML = '<li class="sr-empty">검색 결과 없음</li>';
        return;
      }
      results.innerHTML = hits.map(function (d) {
        var s = snippet(d.content || '', ql);
        return '<li><a href="' + d.url + '">' +
               escapeHtml(d.title) +
               '<span class="sr-cat">' + escapeHtml(d.category || '') +
               (s ? ' · ' + escapeHtml(s) : '') + '</span></a></li>';
      }).join('');
    }
    function escapeHtml(s) {
      return String(s).replace(/[&<>"]/g, function (c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
      });
    }

    input.addEventListener('input', function () {
      var q = input.value.trim();
      if (!q) { showTree(); return; }
      ensureIndex(function () { render(q); });
    });
    input.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') { input.value = ''; showTree(); input.blur(); }
    });
  })();

  /* ── 모바일 사이드바 ───────────────────────────────────────────────── */
  (function mobileSidebar() {
    var btn = document.getElementById('sidebar-toggle');
    var sidebar = document.getElementById('sidebar');
    if (!btn || !sidebar) return;
    btn.addEventListener('click', function () { sidebar.classList.toggle('open'); });
    sidebar.addEventListener('click', function (e) {
      if (e.target.closest('a')) sidebar.classList.remove('open');
    });
  })();
})();
