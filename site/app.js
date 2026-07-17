(() => {
  const buttons = [...document.querySelectorAll('[data-set-lang]')];
  const setLanguage = (language) => {
    document.documentElement.lang = language;
    buttons.forEach((button) => button.setAttribute('aria-pressed', String(button.dataset.setLang === language)));
    try { localStorage.setItem('rosid-language', language); } catch (_) {}
  };
  buttons.forEach((button) => button.addEventListener('click', () => setLanguage(button.dataset.setLang)));
  let saved = 'en';
  try { saved = localStorage.getItem('rosid-language') || 'en'; } catch (_) {}
  setLanguage(saved === 'bn' ? 'bn' : 'en');
})();
