(() => {
  const buttons = [...document.querySelectorAll('[data-set-lang]')];

  const setLanguage = (language) => {
    const selected = language === 'bn' ? 'bn' : 'en';
    document.documentElement.lang = selected;

    buttons.forEach((button) => {
      button.setAttribute('aria-pressed', String(button.dataset.setLang === selected));
    });

    document.querySelectorAll('[data-aria-en]').forEach((element) => {
      element.setAttribute('aria-label', selected === 'bn' ? element.dataset.ariaBn : element.dataset.ariaEn);
    });

    document.querySelectorAll('[data-alt-en]').forEach((image) => {
      image.setAttribute('alt', selected === 'bn' ? image.dataset.altBn : image.dataset.altEn);
    });

    const title = document.querySelector('title[data-title-en]');
    if (title) {
      title.textContent = selected === 'bn' ? title.dataset.titleBn : title.dataset.titleEn;
    }

    const description = document.querySelector('meta[name="description"][data-content-en]');
    if (description) {
      description.content = selected === 'bn' ? description.dataset.contentBn : description.dataset.contentEn;
    }

    try {
      localStorage.setItem('rosid-language', selected);
    } catch (_) {
      // The language toggle remains usable when storage is unavailable.
    }
  };

  buttons.forEach((button) => {
    button.addEventListener('click', () => setLanguage(button.dataset.setLang));
  });

  let savedLanguage = 'en';
  try {
    savedLanguage = localStorage.getItem('rosid-language') || 'en';
  } catch (_) {
    // Use English when storage is unavailable.
  }

  document.querySelectorAll('[data-year]').forEach((element) => {
    element.textContent = String(new Date().getFullYear());
  });

  setLanguage(savedLanguage);
})();
