(function () {
  window.initCitationHelper = function initCitationHelper() {
    const modal = document.getElementById('item_form');
    if (!modal) return;

    const q  = (sel, root = modal) => root.querySelector(sel);

    const textEl    = q('#citation_text');
    const applyBtn  = q('#citation_apply_btn');
    const clearBtn  = q('#citation_clear_btn');
    const statusEl  = q('#citation_status');
    const formWrap  = q('#item_form_container');
    const showBtn   = q('#show_item_form_btn');

    const titleEl   = q('#item_title');
    const authorEl  = q('#item_author');
    const yearEl    = q('#item_publication_date');
    const pubEl     = q('#item_publisher');
    const editionEl = q('#item_edition');
    const isbnEl    = q('#item_isbn');
    const otherEl   = q('#item_other_isbn_issn');
    const callEl    = q('#item_callnumber');
    const urlEl     = q('#item_url');
    const descEl    = q('#item_description');

    const srcHidden = q('input[name="item[metadata_source]"]');
    const rawHidden = q('#raw_citation');
    const csrf      = document.querySelector('meta[name="csrf-token"]')?.content;

    if (srcHidden) srcHidden.value = 'manual';

    const fields = [titleEl, authorEl, yearEl, pubEl, editionEl, isbnEl, otherEl, callEl, urlEl, descEl].filter(Boolean);
    function clearBiblio() { fields.forEach(el => { el.value = ''; }); }

    function showForm() {
      if (formWrap?.classList.contains('d-none')) formWrap.classList.remove('d-none');
      showBtn?.classList.add('d-none');
    }
    function setStatus(msg) { if (statusEl) statusEl.textContent = msg || ''; }

    async function applyCitation() {
      const raw = (textEl?.value || '').trim();
      if (!raw) { textEl?.focus(); return; }

      clearBiblio();
      setStatus('Parsing…');
      if (rawHidden) rawHidden.value = raw;

      try {
        const res  = await fetch('/citations/parse', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf },
          body: JSON.stringify({ citation: raw })
        });
        const data = await res.json();
        if (!res.ok || data.error) throw new Error(data.error || 'Parse failed');

        showForm();

        if (data.title)            titleEl   && (titleEl.value   = data.title);
        if (data.author)           authorEl  && (authorEl.value  = Array.isArray(data.author) ? data.author.join('; ') : data.author);
        if (data.publication_date) yearEl    && (yearEl.value    = data.publication_date);
        if (data.publisher)        pubEl     && (pubEl.value     = data.publisher);
        if (data.edition)          editionEl && (editionEl.value = data.edition);
        if (data.isbn)             isbnEl    && (isbnEl.value    = Array.isArray(data.isbn) ? data.isbn[0] : data.isbn);
        if (data.other_isbn_issn)  otherEl   && (otherEl.value   = Array.isArray(data.other_isbn_issn) ? data.other_isbn_issn.join(', ') : data.other_isbn_issn);
        if (data.callnumber)       callEl    && (callEl.value    = data.callnumber);
        if (data.url)              urlEl     && (urlEl.value     = data.url);

        // Keep the original raw citation somewhere
        if (descEl) descEl.value = data.raw_citation || raw;

        (titleEl?.value ? authorEl : titleEl)?.focus();
        setStatus('Parsed ✔'); setTimeout(() => setStatus(''), 1200);
      } catch (e) {
        // Keep the form cleared, but stash the raw into Description
        showForm();
        if (descEl) descEl.value = raw;
        (titleEl?.value ? authorEl : titleEl)?.focus();
        setStatus('Couldn’t parse; raw citation copied to Description.');
        console.warn('[citation] parse error', e);
      }
    }

    // Prevent double wiring
    if (applyBtn && applyBtn.dataset.wired !== '1') {
      applyBtn.dataset.wired = '1';
      applyBtn.addEventListener('click', applyCitation);
    }
    clearBtn?.addEventListener('click', () => { if (textEl) textEl.value = ''; setStatus(''); textEl?.focus(); });

    textEl?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); applyCitation(); }
    });
  };
})();