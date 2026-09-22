/* Progressive enhancement only. Without JavaScript the navigation is a
 * plain list and the colour scheme follows the system: nothing here is
 * required to read the documentation. */
(function () {
  "use strict";

  var root = document.documentElement;

  /* ---- measured layout chrome -------------------------------------------
   * Two offsets cannot be known from the stylesheet. The masthead's height
   * depends on how many rows it wraps to, which depends on the length of the
   * translated labels; and the generator injects its search button after load
   * as position:fixed, so its size is not ours to declare. Both were
   * hardcoded in rem, and both were wrong: the masthead measured 69px at
   * 1280 and 236px at 320 while headings assumed a fixed 5.5rem, so a
   * contents link on a phone landed the heading underneath the header.
   * Measuring them keeps 2.4.11 and 2.4.12 true at any width, in any
   * language, without the theme needing to know either in advance. */
  function syncChrome() {
    var head = document.querySelector(".masthead");
    if (head) {
      var h = head.getBoundingClientRect().height;
      root.style.setProperty("--masthead-h", Math.ceil(h) + "px");
      // A sticky bar taller than a quarter of the viewport takes more
      // reading room than the convenience is worth. It becomes relative
      // rather than static so it still positions the search button.
      root.style.setProperty(
        "--masthead-pos",
        h > window.innerHeight * 0.25 ? "relative" : "sticky"
      );
    }
    var btn = document.getElementById("ssg-search-btn");
    var tools = document.querySelector(".masthead-tools");
    if (btn && tools && btn.parentNode !== tools) {
      // Adopting the button into the header takes it out of the fixed layer,
      // so it can no longer sit on top of focused content, and frees the
      // strip the header was reserving for it.
      tools.appendChild(btn);
      root.style.setProperty("--search-gutter", "0px");
    }
  }

  syncChrome();
  window.addEventListener("resize", syncChrome, { passive: true });
  if (window.ResizeObserver && document.querySelector(".masthead")) {
    new ResizeObserver(syncChrome).observe(document.querySelector(".masthead"));
  }
  // The search button is injected after load, so watch for it rather than
  // assuming it is present when this runs.
  if (window.MutationObserver) {
    var mo = new MutationObserver(function () {
      if (document.getElementById("ssg-search-btn")) { syncChrome(); mo.disconnect(); }
    });
    mo.observe(document.body, { childList: true, subtree: true });
    setTimeout(function () { mo.disconnect(); }, 10000);
  }

  /* 2.4.12 for elements taller than the viewport.
   *
   * scroll-padding-top only applies when the browser decides to scroll at
   * all. An element taller than the screen is always partly in view, so on
   * focus the browser judges it visible and does not scroll - leaving its top
   * edge, and the start of its focus ring, underneath the sticky masthead.
   * The generator turns any wide table into a focusable scroll region, and
   * the criteria tables on this theme's own accessibility page are exactly
   * that shape, so this is reachable by the second tab on a real page.
   *
   * Nudging on focusin covers the case the CSS property cannot. */
  document.addEventListener("focusin", function (event) {
    var el = event.target;
    if (!el || typeof el.getBoundingClientRect !== "function") return;
    var head = document.querySelector(".masthead");
    if (!head) return;
    var pos = window.getComputedStyle(head).position;
    if (pos !== "sticky" && pos !== "fixed") return;
    var clear = head.getBoundingClientRect().bottom + 8;
    var top = el.getBoundingClientRect().top;
    if (top < clear) window.scrollBy(0, top - clear);
  });

  var toggle = document.getElementById("nav-toggle");
  var nav = document.getElementById("site-nav");
  if (toggle && nav) {
    toggle.addEventListener("click", function () {
      var open = nav.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });
  }

  var mode = document.getElementById("mode-toggle");
  var state = document.getElementById("mode-state");
  if (!mode || !state) return;

  // The cycle includes "system" deliberately: a two-way switch gives no way
  // back to following the operating system once it has been touched.
  var order = ["system", "light", "dark"];
  var labels = {
    system: state.textContent.trim(),
    light: mode.getAttribute("data-label-light") || "Light",
    dark: mode.getAttribute("data-label-dark") || "Dark"
  };

  function current() {
    var set = root.getAttribute("data-theme");
    return set === "light" || set === "dark" ? set : "system";
  }

  function apply(next) {
    if (next === "system") {
      root.removeAttribute("data-theme");
      try { localStorage.removeItem("lucid-theme"); } catch (e) {}
    } else {
      root.setAttribute("data-theme", next);
      try { localStorage.setItem("lucid-theme", next); } catch (e) {}
    }
    state.textContent = labels[next];
  }

  state.textContent = labels[current()];
  mode.addEventListener("click", function () {
    apply(order[(order.indexOf(current()) + 1) % order.length]);
  });
})();
