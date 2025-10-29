(function () {
  const DEFAULTS = { runInitializer: true };

  window.setupItemModal = function setupItemModal(modalEl, options) {
    if (!modalEl || modalEl.dataset.itemModalWired === '1') return;

    const opts = Object.assign({}, DEFAULTS, options);
    modalEl.dataset.itemModalWired = '1';

    const initName = (modalEl.dataset.initializer || '').trim();
    if (opts.runInitializer && initName && typeof window[initName] === 'function') {
      try {
        window[initName]();
      } catch (e) {
        console.error(`[item_modal] initializer ${initName} threw`, e);
      }
    }

    const formWrap  = modalEl.querySelector('#item_form_container');
    const primoBox  = modalEl.querySelector('#search_primo');
    const primoForm = primoBox ? (primoBox.querySelector('form.simple_form.search') || primoBox.querySelector('form')) : null;
    const resultsEl = modalEl.querySelector('#search_primo_results');
    const spinnerEl = modalEl.querySelector('.searching');

    const q  = (sel, root = modalEl) => root.querySelector(sel);
    const qa = (sel, root = modalEl) => Array.from(root.querySelectorAll(sel));
    const locks = window.ItemFieldLocks;

    const showSpinner = () => {
      if (!spinnerEl) return;
      spinnerEl.classList.remove('hidden');
      spinnerEl.classList.remove('d-none');
    };
    const hideSpinner = () => {
      if (!spinnerEl) return;
      spinnerEl.classList.add('hidden');
      spinnerEl.classList.add('d-none');
    };

    const hideFormCompletely = () => {
      if (formWrap) formWrap.classList.remove('d-none');
    };
    const showFormCompletely = () => {
      if (formWrap) formWrap.classList.remove('d-none');
      unminimizeForm();
    };

    const keepSelectors = ['#item_loan_period', 'input[name="item[provided_by_requestor]"]'];

    function minimizeForm() {
      if (!formWrap) return;

      const controls = qa('input, select, textarea', formWrap);
      controls.forEach(el => {
        const keep = keepSelectors.some(sel => el.matches(sel));
        if (!keep && el.type !== 'hidden') el.removeAttribute('required');
      });

      const groups = new Set();
      controls.forEach(el => { const g = el.closest('.form-group, .row'); if (g) groups.add(g); });
      groups.forEach(g => {
        const keep = keepSelectors.some(sel => g.querySelector(sel));
        if (!keep) g.classList.add('d-none');
      });

      keepSelectors.forEach(sel => {
        const el = q(sel);
        const g  = el ? el.closest('.form-group, .row') : null;
        if (g) g.classList.remove('d-none');
      });

      q('#item_loan_period')?.focus();
      formWrap.classList.remove('d-none');
    }

    function unminimizeForm() {
      if (!formWrap) return;
      qa('.d-none', formWrap).forEach(el => el.classList.remove('d-none'));
    }

    function onShown() {
      modalEl.removeEventListener('shown.bs.modal', onShown);
      const fn2 = (modalEl.dataset.initializer || '').trim();
      if (fn2 && typeof window[fn2] === 'function') {
        try { window[fn2](); } catch (err) { console.error('[item_modal] secondary initializer error', err); }
      }
      if (typeof searchRecords === 'function') searchRecords();
      if (typeof onClickShow   === 'function') onClickShow();
    }
    modalEl.addEventListener('shown.bs.modal', onShown);

    if (primoForm) {
      primoForm.addEventListener('submit', () => {
        hideFormCompletely();
        showSpinner();
      });
    }

    if (resultsEl) {
      const obs = new MutationObserver(() => {
        showFormCompletely();
      });
      obs.observe(resultsEl, { childList: true, subtree: true });
      modalEl.addEventListener('hidden.bs.modal', () => obs.disconnect(), { once: true });
    }

    modalEl.addEventListener('click', (e) => {
      const a = e.target.closest('a');
      if (!a) return;

      if (a.matches('[onclick^="clear_primo_search"]') || a.textContent.trim().toLowerCase() === 'clear results') {
        setTimeout(showFormCompletely, 0);
        return;
      }

      if (a.matches('a.usethis')) {
        e.preventDefault();
        e.stopPropagation();
        if (typeof e.stopImmediatePropagation === 'function') e.stopImmediatePropagation();

        const srcHidden = q('input[name="item[metadata_source]"]');
        if (srcHidden && !srcHidden.value) srcHidden.value = 'primo';

        showFormCompletely();
        if (locks && typeof locks.lock === 'function') { locks.lock(); }
        return;
      }
    });

    modalEl.addEventListener('hidden.bs.modal', () => {
      if (locks && typeof locks.unlock === 'function') locks.unlock();
    });

    modalEl.addEventListener('alma:mms-linked', () => {
      try {
        showFormCompletely();
      } catch (err) {
        console.error('[item_modal] alma:mms-linked handler error', err);
      }
    });

    modalEl.addEventListener('click', async (e) => {
      const btn = e.target.closest('#alma_apply_btn');
      if (!btn) return;
      if (btn.dataset.wired === '1') return;

      e.preventDefault();

      const input     = q('#alma_mms_id');
      const status    = q('#alma_status');
      const srcHidden = q('input[name="item[metadata_source]"]');
      const idHidden  = q('input[name="item[metadata_source_id]"]');
      if (srcHidden) srcHidden.value = 'alma';

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

      const fields = [titleEl, authorEl, yearEl, pubEl, editionEl, isbnEl, otherEl, callEl, urlEl, descEl].filter(Boolean);
      const clearBiblio = () => fields.forEach(el => { el.value = ''; });

      const mms = (input?.value || '').trim();
      if (!mms) { input?.focus(); return; }
      if (idHidden) idHidden.value = mms;

      clearBiblio();
      if (locks && typeof locks.unlock === 'function') locks.unlock();

      const csrf = document.querySelector('meta[name="csrf-token"]')?.content;
      btn.disabled = true;
      const originalLabel = btn.textContent;
      btn.textContent = 'Linking…';
      if (status) status.textContent = '';

      try {
        const res = await fetch('/alma/lookup', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf },
          body: JSON.stringify({ mms_id: mms })
        });
        const data = await res.json();
        if (!res.ok || data.error) throw new Error(data.error || 'Lookup failed');

        const assign = (el, value) => { if (el && value != null) el.value = value; };
        assign(titleEl, data.title);
        assign(authorEl, data.author);
        assign(yearEl, data.publication_date);
        assign(pubEl, data.publisher);
        assign(editionEl, data.edition);
        assign(isbnEl, data.isbn);
        assign(otherEl, data.other_isbn_issn);
        assign(callEl, data.callnumber || data.call_number);
        assign(urlEl, data.url);
        assign(descEl, data.description);

        if (locks && typeof locks.lockElement === 'function') {
          locks.lockElement(titleEl);
          locks.lockElement(authorEl);
        }

        btn.textContent = 'Linked ✔';
        if (status) status.textContent = `MMS ${mms} loaded`;
        if (locks && typeof locks.lock === 'function') locks.lock();
        showFormCompletely();
      } catch (err) {
        console.warn('[item_modal] alma lookup error', err);
        btn.textContent = 'Linked (unverified)';
        if (status) status.textContent = 'Lookup failed — fields were cleared';
        showFormCompletely();
      } finally {
        btn.disabled = false;
        if (btn.textContent === 'Linked ✔') {
          setTimeout(() => { btn.textContent = originalLabel || 'Use MMS ID'; }, 1200);
        } else {
          btn.textContent = originalLabel || 'Use MMS ID';
        }
        if (btn.textContent !== 'Linked ✔' && locks && typeof locks.unlock === 'function') locks.unlock();
      }
    });

    modalEl.addEventListener('keydown', (e) => {
      if (e.target && e.target.id === 'alma_mms_id' && e.key === 'Enter') {
        const btn = modalEl.querySelector('#alma_apply_btn');
        if (btn && btn.dataset.wired !== '1') {
          e.preventDefault();
          btn.click();
        }
      }
    });

    modalEl.addEventListener('click', async (e) => {
      const btn = e.target.closest('#citation_apply_btn');
      if (!btn) return;
      if (btn.dataset.wired === '1') return;

      e.preventDefault();

      const textEl    = q('#citation_text');
      const statusEl  = q('#citation_status');

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

      const setStatus = (msg) => { if (statusEl) statusEl.textContent = msg || ''; };

      if (srcHidden) srcHidden.value = 'manual';

      const fields = [titleEl, authorEl, yearEl, pubEl, editionEl, isbnEl, otherEl, callEl, urlEl, descEl].filter(Boolean);
      const clearBiblio = () => fields.forEach(el => { el.value = ''; });

      const raw = (textEl?.value || '').trim();
      if (!raw) { textEl?.focus(); return; }

      clearBiblio();
      if (locks && typeof locks.unlock === 'function') locks.unlock();
      if (rawHidden) rawHidden.value = raw;
      setStatus('Parsing…');

      try {
        const res  = await fetch('/citations/parse', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf },
          body: JSON.stringify({ citation: raw })
        });
        const data = await res.json();
        if (!res.ok || data.error) throw new Error(data.error || 'Parse failed');

        showFormCompletely();

        if (data.title)            titleEl   && (titleEl.value   = data.title);
        if (data.author)           authorEl  && (authorEl.value  = Array.isArray(data.author) ? data.author.join('; ') : data.author);
        if (data.publication_date) yearEl    && (yearEl.value    = data.publication_date);
        if (data.publisher)        pubEl     && (pubEl.value     = data.publisher);
        if (data.edition)          editionEl && (editionEl.value = data.edition);
        if (data.isbn)             isbnEl    && (isbnEl.value    = Array.isArray(data.isbn) ? data.isbn[0] : data.isbn);
        if (data.other_isbn_issn)  otherEl   && (otherEl.value   = Array.isArray(data.other_isbn_issn) ? data.other_isbn_issn.join(', ') : data.other_isbn_issn);
        if (data.callnumber)       callEl    && (callEl.value    = data.callnumber);
        if (data.url)              urlEl     && (urlEl.value     = data.url);

        if (descEl) descEl.value = data.raw_citation || raw;

        (titleEl?.value ? authorEl : titleEl)?.focus();
        setStatus('Parsed ✔'); setTimeout(() => setStatus(''), 1200);
        if (locks && typeof locks.lock === 'function') locks.lock();
        if (locks && typeof locks.lockElement === 'function') {
          locks.lockElement(titleEl);
          locks.lockElement(authorEl);
        }
      } catch (err) {
        showFormCompletely();
        if (descEl) descEl.value = raw;
        (titleEl?.value ? authorEl : titleEl)?.focus();
        setStatus('Couldn’t parse; raw citation copied to Description.');
        console.warn('[item_modal] citation parse error', err);
        if (locks && typeof locks.unlock === 'function') locks.unlock();
      }
    });

    modalEl.addEventListener('keydown', (e) => {
      if (e.target && e.target.id === 'citation_text' && e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
        const btn = modalEl.querySelector('#citation_apply_btn');
        if (btn && btn.dataset.wired !== '1') { e.preventDefault(); btn.click(); }
      }
    });

    if (primoForm) {
      primoForm.addEventListener('ajax:success', () => hideSpinner());
      primoForm.addEventListener('ajax:error',   () => hideSpinner());
      primoForm.addEventListener('ajax:complete',() => hideSpinner());
    }
  };
})();
