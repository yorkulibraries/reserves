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

        const itemForm = modal.querySelector('#item_form_container form');
        const fieldMap = {
            title: 'title',
            author: 'author',
            publication_date: 'publication_date',
            publisher: 'publisher',
            edition: 'edition',
            isbn: 'isbn',
            other_isbn_issn: 'other_isbn_issn',
            callnumber: 'callnumber',
            url: 'url',
            description: 'description'
        };

        const findField = (attr) => {
            const name = `item[${attr}]`;
            return (itemForm && itemForm.elements[name]) ||
                q(`#item_${attr}`) ||
                modal.querySelector(`[name="${name}"]`) ||
                modal.querySelector(`[name="item_${attr}"]`);
        };

        const formatDefaultValue = (() => {
            const field = findField('format');
            return field ? field.value : '';
        })();

        function clearBiblio() {
            Object.keys(fieldMap).forEach(attr => {
                const field = findField(attr);
                if (field) field.value = '';
            });

            const formatField = findField('format');
            if (formatField && formatField.readOnly) {
                formatField.value = formatDefaultValue;
            }
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

            const setValue = (attr, value) => {
                const field = findField(attr);
                if (!field || value == null) return;
                field.value = value;
            };

            setValue('title', title);
            setValue('author', data.author);
            setValue('publication_date', data.publication_date);
            setValue('publisher', data.publisher);
            setValue('edition', data.edition);
            setValue('isbn', data.isbn);
            setValue('other_isbn_issn', data.other_isbn_issn);
            setValue('callnumber', data.callnumber || data.call_number);
            setValue('url', data.url);
            setValue('description', data.description);

            const formatField = findField('format');
            if (formatField && data.format) formatField.value = data.format;

            btn.textContent = 'Linked ✔';
            if (status) status.textContent = `MMS ${mms} loaded`;

            if (typeof console !== 'undefined') {
                try {
                    const snapshot = {};
                    Object.keys(fieldMap).forEach(attr => {
                        const field = findField(attr);
                        snapshot[attr] = field ? field.value : null;
                    });
                    console.debug('[alma] applied fields for MMS', mms, snapshot);
                } catch (_) {}
            }

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
