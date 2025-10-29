(function () {
  const TITLE_SELECTOR = '#item_title';
  const AUTHOR_SELECTOR = '#item_author';
  const LOCK_CLASS = 'locked-field';

  function applyLock(el) {
    if (!el) return;
    el.readOnly = true;
    el.setAttribute('readonly', 'readonly');
    el.classList.add(LOCK_CLASS);
  }

  function removeLock(el) {
    if (!el) return;
    el.readOnly = false;
    el.removeAttribute('readonly');
    el.classList.remove(LOCK_CLASS);
  }

  function setReadOnly(flag) {
    [TITLE_SELECTOR, AUTHOR_SELECTOR].forEach((selector) => {
      document.querySelectorAll(selector).forEach((el) => {
        flag ? applyLock(el) : removeLock(el);
      });
    });
  }

  window.ItemFieldLocks = {
    lock() {
      setReadOnly(true);
    },
    unlock() {
      setReadOnly(false);
    },
    lockElement(el) {
      applyLock(el);
    },
    unlockElement(el) {
      removeLock(el);
    },
    lockElements(elements) {
      (elements || []).forEach(applyLock);
    }
  };
})();
