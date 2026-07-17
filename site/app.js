(() => {
  const buttons = [...document.querySelectorAll('[data-set-lang]')];
  const setLanguage = (language) => {
    document.documentElement.lang = language;
    buttons.forEach((button) => button.setAttribute('aria-pressed', String(button.dataset.setLang === language)));
    document.querySelectorAll('[data-aria-en]').forEach((element) => {
      element.setAttribute('aria-label', language === 'bn' ? element.dataset.ariaBn : element.dataset.ariaEn);
    });
    const title = document.querySelector('title[data-title-en]');
    if (title) title.textContent = language === 'bn' ? title.dataset.titleBn : title.dataset.titleEn;
    const description = document.querySelector('meta[name="description"][data-content-en]');
    if (description) description.content = language === 'bn' ? description.dataset.contentBn : description.dataset.contentEn;
    try { localStorage.setItem('rosid-language', language); } catch (_) {}
  };
  buttons.forEach((button) => button.addEventListener('click', () => setLanguage(button.dataset.setLang)));
  let saved = 'en';
  try { saved = localStorage.getItem('rosid-language') || 'en'; } catch (_) {}
  setLanguage(saved === 'bn' ? 'bn' : 'en');
})();
