/* جنتي — سلوك الصفحة. بلا مكتبات، وبلا تتبّع. */
(function () {
  "use strict";

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- الشريط العلوي: حد يظهر بعد التمرير ---------- */
  var head = document.getElementById("siteHead");
  if (head) {
    var onScroll = function () {
      head.classList.toggle("is-scrolled", window.scrollY > 8);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  /* ---------- ظهور العناصر عند التمرير ---------- */
  var targets = document.querySelectorAll(".reveal");
  if (reduceMotion || !("IntersectionObserver" in window)) {
    for (var i = 0; i < targets.length; i++) targets[i].classList.add("is-in");
  } else {
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          /* تأخير بسيط متتابع داخل نفس الصف */
          var delay = Math.min(entry.target.dataset.delay || 0, 240);
          setTimeout(function () {
            entry.target.classList.add("is-in");
          }, delay);
          io.unobserve(entry.target);
        });
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0.08 }
    );

    /* ترتيب تتابعي: كل ثلاثة عناصر متجاورة تتأخر ٠ / ٨٠ / ١٦٠ms */
    var groups = {};
    for (var j = 0; j < targets.length; j++) {
      var t = targets[j];
      var parent = t.parentElement;
      if (!parent) continue;
      var key = parent.tagName + "|" + (parent.className || "") + "|" + j;
      groups[key] = true;
      io.observe(t);
    }
  }

  /* ---------- شريط التحميل السفلي (الجوال) ---------- */
  var sticky = document.getElementById("stickyCta");
  if (sticky) {
    var hero = document.querySelector(".hero");
    var foot = document.querySelector(".site-foot");
    var update = function () {
      var pastHero = hero
        ? window.scrollY > hero.offsetTop + hero.offsetHeight - 120
        : window.scrollY > 480;
      var atFoot = false;
      if (foot) {
        var r = foot.getBoundingClientRect();
        atFoot = r.top < window.innerHeight - 40;
      }
      sticky.classList.toggle("is-visible", pastHero && !atFoot);
    };
    update();
    window.addEventListener("scroll", update, { passive: true });
    window.addEventListener("resize", update);
  }

  /* ---------- روابط التمرير داخل الصفحة: إزاحة الشريط ---------- */
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest('a[href^="#"]');
    if (!a) return;
    var id = a.getAttribute("href");
    if (!id || id === "#") return;
    var el = document.querySelector(id);
    if (!el) return;
    e.preventDefault();
    var top = el.getBoundingClientRect().top + window.scrollY - 84;
    window.scrollTo({ top: top, behavior: reduceMotion ? "auto" : "smooth" });
    if (history.replaceState) history.replaceState(null, "", id);
  });

  /* ---------- تكبير اللقطات ---------- */
  var ZOOM_SEL = ".ui-panel img, .shot img, .tl-media img";
  var zoomables = document.querySelectorAll(ZOOM_SEL);
  if (zoomables.length) {
    var lb = document.createElement("div");
    lb.className = "lightbox";
    lb.setAttribute("role", "dialog");
    lb.setAttribute("aria-modal", "true");
    lb.setAttribute("aria-label", "الصورة بحجم أكبر");
    lb.innerHTML =
      '<button class="lightbox-x" type="button" aria-label="إغلاق">' +
      '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18"/></svg>' +
      "</button><figure><img alt=\"\"><figcaption></figcaption></figure>";
    document.body.appendChild(lb);

    var lbImg = lb.querySelector("img");
    var lbCap = lb.querySelector("figcaption");
    var lbX = lb.querySelector(".lightbox-x");
    var opener = null;

    var closeZoom = function () {
      lb.classList.remove("is-open");
      document.documentElement.classList.remove("is-locked");
      if (opener) opener.focus();
      opener = null;
    };
    var openZoom = function (img) {
      opener = img;
      lbImg.src = img.currentSrc || img.src;
      lbImg.alt = img.alt || "";
      lbCap.textContent = img.alt || "";
      lb.classList.add("is-open");
      document.documentElement.classList.add("is-locked");
      lbX.focus();
    };

    for (var z = 0; z < zoomables.length; z++) {
      zoomables[z].tabIndex = 0;
      zoomables[z].setAttribute("role", "button");
      zoomables[z].setAttribute("aria-haspopup", "dialog");
    }

    document.addEventListener("click", function (e) {
      var img = e.target.closest && e.target.closest(ZOOM_SEL);
      if (img && lb.classList.contains("is-open") === false) {
        openZoom(img);
        return;
      }
      if (!lb.classList.contains("is-open")) return;
      if (e.target === lb || (e.target.closest && e.target.closest(".lightbox-x"))) {
        closeZoom();
      }
    });

    document.addEventListener("keydown", function (e) {
      if (lb.classList.contains("is-open") && e.key === "Escape") {
        closeZoom();
        return;
      }
      if (e.key !== "Enter" && e.key !== " ") return;
      var el = document.activeElement;
      if (!el || !el.matches || !el.matches(ZOOM_SEL)) return;
      e.preventDefault();
      openZoom(el);
    });
  }

  /* ---------- علامة السنة في التذييل إن وُجدت ---------- */
  var year = document.querySelector("[data-year]");
  if (year) year.textContent = new Date().getFullYear();
})();

  /* ---------- مسبحة الويب التفاعلية الحية ---------- */
  var tasbeehBtn = document.getElementById("webTasbeehBtn");
  if (tasbeehBtn) {
    var count = 0;
    var trees = 0;
    var display = document.getElementById("webCounterDisplay");
    var treesDisplay = document.getElementById("webTreesPlanted");
    var cycleDisplay = document.getElementById("webCycleDisplay");
    var feedback = document.getElementById("webTasbeehFeedback");

    var toArabic = function(n) {
      var ar = ["٠","١","٢","٣","٤","٥","٦","٧","٨","٩"];
      return String(n).replace(/[0-9]/g, function(d) { return ar[+d]; });
    };

    var onTasbeehClick = function() {
      count++;
      if (count % 10 === 0) {
        trees++;
        if (treesDisplay) treesDisplay.textContent = toArabic(trees);
        if (feedback) feedback.textContent = "مبارك! اكتملت عشر تسبيحات وغُرست نخلة يانعة 🌴✨";
      } else {
        if (feedback) feedback.textContent = "تقبل الله ذكرك وطاعتك.. استمر 🌱";
      }

      var currentInCycle = count % 33;
      if (currentInCycle === 0 && count > 0) {
        currentInCycle = 33;
        if (feedback) feedback.textContent = "أتممت دورة مباركة (٣٣) تسبيحة! هنيئاً لك 🌿✨";
      }

      if (display) display.textContent = toArabic(count);
      if (cycleDisplay) cycleDisplay.textContent = toArabic(currentInCycle) + " / ٣٣";

      if (navigator.vibrate) {
        navigator.vibrate(20);
      }
    };

    tasbeehBtn.addEventListener("click", onTasbeehClick);
    tasbeehBtn.addEventListener("keydown", function(e) {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        onTasbeehClick();
      }
    });
  }
