/* Applied before first paint so a stored preference never flashes the wrong
 * ground. Absence of a stored value is meaningful: it means "follow the
 * system", so nothing is written to the element and the prefers-color-scheme
 * media query in the stylesheet stays in charge. */
(function () {
  var el = document.documentElement;
  el.classList.remove("no-js");
  try {
    var stored = localStorage.getItem("lucid-theme");
    if (stored === "light" || stored === "dark") {
      el.setAttribute("data-theme", stored);
    }
  } catch (e) {
    /* Private browsing can throw on access; following the system is the
     * correct fallback, so there is nothing to recover. */
  }
})();
