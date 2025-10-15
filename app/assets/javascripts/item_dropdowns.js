(function () {
  function closeAll(except) {
    document.querySelectorAll('.stick-on-click.force-open').forEach((el) => {
      if (el !== except) {
        el.classList.remove('force-open');
      }
    });
  }

  document.addEventListener('click', (event) => {
    const toggle = event.target.closest('.stick-on-click > .dropdown-toggle');
    if (toggle) {
      event.preventDefault();
      event.stopPropagation();
      const container = toggle.closest('.stick-on-click');
      if (!container) return;
      const willOpen = !container.classList.contains('force-open');
      closeAll(container);
      if (willOpen) {
        container.classList.add('force-open');
      } else {
        container.classList.remove('force-open');
      }
      return;
    }

    if (!event.target.closest('.stick-on-click')) {
      closeAll();
    }
  });
})();
