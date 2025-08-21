(function () {
    window.initAlmaLink = function initAlmaLink() {
        const modal = document.getElementById('item_form');
        if (!modal) return;

        const q = (sel, root = modal) => root.querySelector(sel);

        const input     = q('#alma_mms_id');
        const btn       = q('#alma_apply_btn');
        const status    = q('#alma_status');

        if (!btn) { console.warn('[alma] #alma_apply_btn not found at init'); return; }
        if (btn.dataset.wired === '1') return;           // prevent double wiring
        btn.dataset.wired = '1';

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

        function clearBiblio() {
            fields.forEach(el => { el.value = ''; });
        }

        // Remove trailing " / …" and dangling ISBD punctuation from a display title
        function tidyIsbdTitle(s) {
            if (!s) return s;
            s = s.trim();
            // Remove trailing " / …" OR " /" at end (ISBD SOR), but only if there's whitespace before the slash.
            s = s.replace(/\s+\/\s*[^/]*$/, '');
            // Remove dangling ISBD punctuation if left over at the very end.
            s = s.replace(/\s+[;:=]\s*$/, '');
            return s.trim();
        }
        

        async function apply() {
        const mms = (input?.value || '').trim();
        if (!mms) { input?.focus(); return; }
        if (idHidden) idHidden.value = mms;

        // Always clear before populating with a new record
        clearBiblio();

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

            const title = data.title_clean || tidyIsbdTitle(data.title);

            if (title)            titleEl   && (titleEl.value   = title);
            if (data.author)      authorEl  && (authorEl.value  = data.author);
            if (data.publication_date) yearEl && (yearEl.value  = data.publication_date);
            if (data.publisher)   pubEl     && (pubEl.value     = data.publisher);
            if (data.edition)     editionEl && (editionEl.value = data.edition);
            if (data.isbn)        isbnEl    && (isbnEl.value    = data.isbn);
            if (data.other_isbn_issn) otherEl && (otherEl.value = data.other_isbn_issn);
            if (data.callnumber || data.call_number) callEl && (callEl.value = (data.callnumber || data.call_number));
            if (data.url)         urlEl     && (urlEl.value     = data.url);
            if (data.description) descEl    && (descEl.value    = data.description);

            btn.textContent = 'Linked ✔';
            if (status) status.textContent = `MMS ${mms} loaded`;

            try {
                modal.dispatchEvent(new CustomEvent('alma:mms-linked', { bubbles: true, detail: { mmsId: mms, payload: data } }));
            } catch (_) {}
        } catch (e) {
            console.warn('[alma] lookup error', e);
            btn.textContent = 'Linked (unverified)';
            if (status) status.textContent = 'Lookup failed — fields were cleared';
        } finally {
            setTimeout(() => { btn.disabled = false; btn.textContent = originalLabel || 'Use MMS ID'; }, 1200);
        }
        }


        btn.addEventListener('click', apply);
        input?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') { e.preventDefault(); apply(); }
        });
    };
})();  