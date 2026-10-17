(function () {
  "use strict";

  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var ORDER = ["claude", "codex", "cursor", "grok", "openrouter", "deepseek", "moonshot"];

  // Same marks the app draws in ProviderGlyph.swift.
  var GLYPHS = {
    claude: {
      box: "0 0 24 24",
      evenOdd: false,
      d: "m4.7144 15.9555 4.7174-2.6471.079-.2307-.079-.1275h-.2307l-.7893-.0486-2.6956-.0729-2.3375-.0971-2.2646-.1214-.5707-.1215-.5343-.7042.0546-.3522.4797-.3218.686.0608 1.5179.1032 2.2767.1578 1.6514.0972 2.4468.255h.3886l.0546-.1579-.1336-.0971-.1032-.0972L6.973 9.8356l-2.55-1.6879-1.3356-.9714-.7225-.4918-.3643-.4614-.1578-1.0078.6557-.7225.8803.0607.2246.0607.8925.686 1.9064 1.4754 2.4893 1.8336.3643.3035.1457-.1032.0182-.0728-.164-.2733-1.3539-2.4467-1.445-2.4893-.6435-1.032-.17-.6194c-.0607-.255-.1032-.4674-.1032-.7285L6.287.1335 6.6997 0l.9957.1336.419.3642.6192 1.4147 1.0018 2.2282 1.5543 3.0296.4553.8985.2429.8318.091.255h.1579v-.1457l.1275-1.706.2368-2.0947.2307-2.6957.0789-.7589.3764-.9107.7468-.4918.5828.2793.4797.686-.0668.4433-.2853 1.8517-.5586 2.9021-.3643 1.9429h.2125l.2429-.2429.9835-1.3053 1.6514-2.0643.7286-.8196.85-.9046.5464-.4311h1.0321l.759 1.1293-.34 1.1657-1.0625 1.3478-.8804 1.1414-1.2628 1.7-.7893 1.36.0729.1093.1882-.0183 2.8535-.607 1.5421-.2794 1.8396-.3157.8318.3886.091.3946-.3278.8075-1.967.4857-2.3072.4614-3.4364.8136-.0425.0304.0486.0607 1.5482.1457.6618.0364h1.621l3.0175.2247.7892.522.4736.6376-.079.4857-1.2142.6193-1.6393-.3886-3.825-.9107-1.3113-.3279h-.1822v.1093l1.0929 1.0686 2.0035 1.8092 2.5075 2.3314.1275.5768-.3218.4554-.34-.0486-2.2039-1.6575-.85-.7468-1.9246-1.621h-.1275v.17l.4432.6496 2.3436 3.5214.1214 1.0807-.17.3521-.6071.2125-.6679-.1214-1.3721-1.9246L14.38 17.959l-1.1414-1.9428-.1397.079-.674 7.2552-.3156.3703-.7286.2793-.6071-.4614-.3218-.7468.3218-1.4753.3886-1.9246.3157-1.53.2853-1.9004.17-.6314-.0121-.0425-.1397.0182-1.4328 1.9672-2.1796 2.9446-1.7243 1.8456-.4128.164-.7164-.3704.0667-.6618.4008-.5889 2.386-3.0357 1.4389-1.882.929-1.0868-.0062-.1579h-.0546l-6.3385 4.1164-1.1293.1457-.4857-.4554.0608-.7467.2307-.2429 1.9064-1.3114Z"
    },
    codex: {
      box: "0 0 24 24",
      evenOdd: true,
      d: "M8.086.457a6.105 6.105 0 013.046-.415c1.333.153 2.521.72 3.564 1.7a.117.117 0 00.107.029c1.408-.346 2.762-.224 4.061.366l.063.03.154.076c1.357.703 2.33 1.77 2.918 3.198.278.679.418 1.388.421 2.126a5.655 5.655 0 01-.18 1.631.167.167 0 00.04.155 5.982 5.982 0 011.578 2.891c.385 1.901-.01 3.615-1.183 5.14l-.182.22a6.063 6.063 0 01-2.934 1.851.162.162 0 00-.108.102c-.255.736-.511 1.364-.987 1.992-1.199 1.582-2.962 2.462-4.948 2.451-1.583-.008-2.986-.587-4.21-1.736a.145.145 0 00-.14-.032c-.518.167-1.04.191-1.604.185a5.924 5.924 0 01-2.595-.622 6.058 6.058 0 01-2.146-1.781c-.203-.269-.404-.522-.551-.821a7.74 7.74 0 01-.495-1.283 6.11 6.11 0 01-.017-3.064.166.166 0 00.008-.074.115.115 0 00-.037-.064 5.958 5.958 0 01-1.38-2.202 5.196 5.196 0 01-.333-1.589 6.915 6.915 0 01.188-2.132c.45-1.484 1.309-2.648 2.577-3.493.282-.188.55-.334.802-.438.286-.12.573-.22.861-.304a.129.129 0 00.087-.087A6.016 6.016 0 015.635 2.31C6.315 1.464 7.132.846 8.086.457zm-.804 7.85a.848.848 0 00-1.473.842l1.694 2.965-1.688 2.848a.849.849 0 001.46.864l1.94-3.272a.849.849 0 00.007-.854l-1.94-3.393zm5.446 6.24a.849.849 0 000 1.695h4.848a.849.849 0 000-1.696h-4.848z"
    },
    cursor: {
      box: "20 12 459 522",
      evenOdd: false,
      d: "m466.383 137.073-206.469-119.2034c-6.63-3.8287-14.811-3.8287-21.441 0l-206.4586 119.2034c-5.5734 3.218-9.0144 9.169-9.0144 15.615v240.375c0 6.436 3.441 12.397 9.0144 15.615l206.4686 119.203c6.63 3.829 14.811 3.829 21.441 0l206.468-119.203c5.574-3.218 9.015-9.17 9.015-15.615v-240.375c0-6.436-3.441-12.397-9.015-15.615zm-12.969 25.25-199.316 345.223c-1.347 2.326-4.904 1.376-4.904-1.319v-226.048c0-4.517-2.414-8.695-6.33-10.963l-195.7577-113.019c-2.3263-1.347-1.3764-4.905 1.3182-4.905h398.6305c5.661 0 9.199 6.136 6.368 11.041h-.009z"
    },
    grok: {
      box: "0 0 24 24",
      evenOdd: true,
      d: "M7.7 1.5h8.6a6.2 6.2 0 0 1 6.2 6.2v8.6a6.2 6.2 0 0 1-6.2 6.2H7.7a6.2 6.2 0 0 1-6.2-6.2V7.7a6.2 6.2 0 0 1 6.2-6.2ZM9.15 7.2a1.75 1.75 0 0 1 1.75 1.75v2.7a1.75 1.75 0 0 1-3.5 0v-2.7A1.75 1.75 0 0 1 9.15 7.2Zm5.7 0a1.75 1.75 0 0 1 1.75 1.75v2.7a1.75 1.75 0 0 1-3.5 0v-2.7a1.75 1.75 0 0 1 1.75-1.75Z"
    },
    openrouter: {
      box: "0 0 24 24",
      evenOdd: false,
      d: "m15.6 2.2 6 3.8-6.4 2.4Z",
      line: "M17.4 7.1A6.8 6.8 0 1 0 18.2 15"
    },
    deepseek: {
      box: "0 0 24 24",
      evenOdd: true,
      d: "M3.2 13.2c0-3.1 3.1-5.7 7.4-5.7 2.6 0 4.7.9 6.1 2.1.4-1.1 1.5-1.9 2.8-1.9.4 0 .6.4.4.7-.5 1.1-1.6 1.9-2.9 2.1 1.1.7 1.8 1.7 1.8 2.9 0 2.4-2.6 4.3-6.1 4.3-1.1 0-2.1-.2-3-.6-.8 1.3-2.7 2.2-4.6 1.8.5-1.1.2-2.1-.3-2.9-.7-.8-.9-1.7-.9-2.8Zm11.2-.4a.85.85 0 1 0 0-1.7.85.85 0 0 0 0 1.7Z"
    },
    moonshot: {
      box: "0 0 24 24",
      evenOdd: true,
      d: "M14.6 3.1a8.6 8.6 0 1 0 5.9 14.8 6.8 6.8 0 1 1-5.9-14.8Z"
    }
  };

  var GAUGE = '<svg class="glyph" width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 17a8 8 0 1 1 16 0" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M12 17l3.6-4.6" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="17" r="1.8"/></svg>';

  var now = new Date();
  var RESETS = {
    session: resetHint(new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours() + 3)),
    week: resetHint(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 4, 9)),
    month: resetHint(new Date(now.getFullYear(), now.getMonth() + 1, 1))
  };

  // Meter titles match the fetchers. `share` derives the second meter from the slider value.
  var PROVIDERS = {
    claude: { name: "Claude", meters: [["Session (5 hour)", 1, "session"], ["Weekly (7 day)", 0.6, "week"]] },
    codex: { name: "Codex", meters: [["Session (5 hour)", 1, "session"], ["Weekly (7 day)", 0.45, "week"]] },
    cursor: { name: "Cursor", meters: [["Cursor models", 1, "month"], ["Other models", 0.3, "month"]] },
    grok: { name: "Grok Bot", meters: [["Weekly", 1, "week"]] },
    openrouter: { name: "OpenRouter", meters: [["Key limit", 1, "month"]] },
    deepseek: { name: "DeepSeek", meters: [["Balance", 1, "month"]] },
    moonshot: { name: "Moonshot", meters: [["Balance", 1, "month"]] }
  };

  function resetHint(date) {
    var sameDay = date.toDateString() === now.toDateString();
    var options = sameDay ? { timeStyle: "short" } : { dateStyle: "short", timeStyle: "short" };
    return "resets " + new Intl.DateTimeFormat(undefined, options).format(date);
  }

  function heat(percent) {
    if (percent >= 90) return "hot";
    if (percent >= 70) return "warm";
    return "low";
  }

  function glyph(id) {
    var g = GLYPHS[id];
    var paths = "";
    if (g.line) paths += '<path class="line" d="' + g.line + '"/>';
    paths += '<path fill-rule="' + (g.evenOdd ? "evenodd" : "nonzero") + '" d="' + g.d + '"/>';
    return '<svg class="glyph" width="18" height="18" viewBox="' + g.box + '" aria-hidden="true">' + paths + "</svg>";
  }

  function statusItemHTML(readings) {
    if (!readings.length) return GAUGE;
    return readings.map(function (r) {
      var value = r[1] == null ? "–" : Math.round(r[1]) + "%";
      return '<span class="si-r">' + glyph(r[0]) + '<span class="si-v">' + value + "</span></span>";
    }).join("");
  }

  function meterHTML(meter, value) {
    var percent = Math.round(value * meter[1]);
    return '<div class="m"><div class="m-t">' + meter[0] + '</div>' +
      '<div class="m-track ' + heat(percent) + '" style="--f:' + percent / 100 + '"><i class="m-fill"></i><i class="m-knob"></i></div>' +
      '<div class="m-c">' + percent + "% used · " + RESETS[meter[2]] + "</div></div>";
  }

  // Same words and colors as ServiceLevel in the app. A lamp only shows when flagged.
  var STATUS = {
    claude: { word: "Degraded", tone: "degraded" },
    codex: { word: "Down", tone: "down" },
    cursor: { word: "Down", tone: "down" }
  };

  var GEAR = '<svg class="pp-gear" viewBox="0 0 24 24" aria-hidden="true"><path fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3" fill="none" stroke="currentColor" stroke-width="2"/></svg>';

  function sectionHTML(reading, status) {
    var p = PROVIDERS[reading[0]];
    var body = reading[1] == null
      ? '<div class="pp-note"><i class="spin"></i>Updating</div>'
      : p.meters.map(function (m) { return meterHTML(m, reading[1]); }).join("");
    var lamp = status
      ? '<span class="lamp lamp-' + status.tone + '"><i></i>' + status.word + "</span>"
      : "";
    return '<div class="pp-sec"><div class="pp-head">' + glyph(reading[0]) + "<span>" + p.name + "</span>" + lamp + "</div>" + body + "</div>";
  }

  // shortcut: hero Settings shows only the section toggles. The rest of SettingsView would make the loop tall.
  function settingsHTML(enabled) {
    var rows = ORDER.map(function (id) {
      return '<label class="pp-check' + (enabled[id] ? " on" : "") + '" data-id="' + id + '"><i></i>' +
        glyph(id) + "<span>" + PROVIDERS[id].name + "</span></label>";
    }).join("");
    return '<div class="pp-title"><span>Settings</span>' + GEAR.replace("pp-gear", "pp-gear on") + "</div>" +
      '<div class="pp-kicker">Sections</div>' + rows;
  }

  function popoverHTML(readings, flags) {
    var html = '<div class="pp-title"><span>AI Usage</span>' + GEAR + "</div>";
    if (!readings.length) html += '<div class="pp-empty">No sections. Turn one on in Settings.</div>';
    readings.forEach(function (r, i) {
      if (i) html += '<hr class="pp-div">';
      html += sectionHTML(r, flags && flags[r[0]] ? STATUS[r[0]] : null);
    });
    html += '<hr class="pp-div pp-div-foot">' +
      '<div class="pp-foot"><span>Updated 1 min ago</span><span class="pp-actions"><span class="pp-btn">Refresh</span><span class="pp-btn">Quit</span></span></div>';
    return html;
  }

  var SYS =
    '<span class="sys sys-battery"><svg width="28" height="14" viewBox="0 0 26 13"><rect x=".75" y=".75" width="21.5" height="11.5" rx="3.2" fill="none" stroke="currentColor" stroke-opacity=".5" stroke-width="1.2"/><rect x="2.5" y="2.5" width="15" height="8" rx="1.8"/><path d="M24 4.5v4a2 2 0 0 0 0-4Z" fill-opacity=".5"/></svg></span>' +
    '<span class="sys sys-wifi"><svg width="18" height="14" viewBox="0 0 18 14"><path d="M9 13.2 6.5 10.4a3.6 3.6 0 0 1 5 0Zm-4.2-4.6a6.1 6.1 0 0 1 8.4 0l1.6-1.8a8.6 8.6 0 0 0-11.6 0Zm-3.3-3.6a10.8 10.8 0 0 1 15 0L18 3.2a13.3 13.3 0 0 0-18 0Z"/></svg></span>' +
    '<span class="sys sys-search"><svg width="14" height="14" viewBox="0 0 16 16"><circle cx="6.5" cy="6.5" r="4.8" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="m10.2 10.2 4.3 4.3" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg></span>' +
    '<span class="sys sys-cc"><svg width="16" height="14" viewBox="0 0 18 16"><rect x="1" y="2" width="16" height="5" rx="2.5" fill="none" stroke="currentColor" stroke-width="1.4"/><circle cx="4.5" cy="4.5" r="1.6"/><rect x="1" y="9" width="16" height="5" rx="2.5" fill="none" stroke="currentColor" stroke-width="1.4"/><circle cx="13.5" cy="11.5" r="1.6"/></svg></span>';

  var POINTER = '<svg class="pointer" width="20" height="27" viewBox="0 0 22 30" aria-hidden="true"><path d="M2 2v22l5.4-5.2 3.6 8.4 3.6-1.6-3.5-8.2H18Z" fill="#111" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/></svg>';

  function clockText() {
    var d = new Date();
    var date = new Intl.DateTimeFormat(undefined, { weekday: "short", month: "short", day: "numeric" }).format(d).replace(/,/g, "");
    var time = new Intl.DateTimeFormat(undefined, { hour: "numeric", minute: "2-digit" }).format(d);
    return '<span class="clock-date">' + date + "</span>" + time;
  }

  function buildScreen(el) {
    var kind = el.dataset.screen;
    var menus = "<b>Finder</b><span>File</span><span>Edit</span><span>View</span><span>Go</span><span>Window</span><span>Help</span>";
    el.innerHTML =
      '<div class="screen-inner"><div class="wall"></div>' +
      '<div class="mb"><div class="mb-left">' + menus + "</div>" +
      '<div class="mb-right"><span class="si" data-si></span>' + SYS + '<span class="clock" data-clock></span></div></div>' +
      '<div class="pop" data-pop><span class="pop-arrow"></span><div class="pop-body" data-body></div></div>' +
      (kind === "hero" ? POINTER : "") +
      "</div>";
    var screen = {
      el: el,
      kind: kind,
      inner: el.querySelector(".screen-inner"),
      si: el.querySelector("[data-si]"),
      pop: el.querySelector("[data-pop]"),
      body: el.querySelector("[data-body]"),
      clock: el.querySelector("[data-clock]"),
      pointer: el.querySelector(".pointer"),
      scale: 1,
      width: 0
    };
    screen.clock.innerHTML = clockText();
    screens.push(screen);
    return screen;
  }

  function render(screen, state) {
    screen.inner.classList.toggle("light", state.theme === "light");
    screen.si.innerHTML = statusItemHTML(state.readings);
    if (screen.body) screen.body.innerHTML = popoverHTML(state.readings, state.flags);
    place(screen);
  }

  function fit(screen) {
    var width = screen.el.clientWidth;
    if (!width || width === screen.width) return;
    screen.width = width;
    var d = screen.el.dataset;
    screen.scale = Math.min(+d.max, Math.max(+d.min, width / +d.native));
    screen.inner.style.width = width / screen.scale + "px";
    screen.inner.style.transform = "scale(" + screen.scale + ")";
    place(screen);
  }

  function place(screen) {
    var minHeight = +screen.el.dataset.minHeight;
    var height = minHeight;
    if (screen.pop) {
      var inner = screen.inner.getBoundingClientRect();
      var item = screen.si.getBoundingClientRect();
      var center = (item.left - inner.left + item.width / 2) / screen.scale;
      var width = screen.inner.offsetWidth;
      var popWidth = screen.pop.offsetWidth;
      var left = Math.max(10, Math.min(width - popWidth - 10, center - popWidth / 2));
      screen.pop.style.left = left + "px";
      screen.pop.style.setProperty("--ax", center - left + "px");
      height = Math.max(minHeight, screen.pop.offsetTop + screen.pop.offsetHeight + 44);
    }
    screen.inner.style.height = height + "px";
    screen.el.style.height = height * screen.scale + "px";
  }

  function wait(ms) {
    return new Promise(function (resolve) { setTimeout(resolve, ms); });
  }

  function tween(duration, step) {
    return new Promise(function (resolve) {
      var start = performance.now();
      function frame(t) {
        var k = Math.min(1, (t - start) / duration);
        step(1 - Math.pow(1 - k, 3));
        if (k < 1) requestAnimationFrame(frame); else resolve();
      }
      requestAnimationFrame(frame);
    });
  }

  var screens = [];

  // Hero loops one story: click the menu, see Claude and Cursor, change them in Settings, come back to Claude and Codex.
  function hero(el) {
    var screen = buildScreen(el);
    var first = [["claude", 42], ["cursor", 73]];
    var second = [["claude", 42], ["codex", 18]];
    var enabled = { claude: true, codex: false, cursor: true, grok: false, openrouter: false, deepseek: false, moonshot: false };
    var spot = { x: 0, y: 80, opacity: 0 };

    function showUsage(readings, open) {
      render(screen, { theme: "dark", readings: readings });
      screen.si.classList.toggle("active", !!open);
      screen.pop.classList.toggle("open", !!open);
    }

    function showSettings() {
      screen.body.innerHTML = settingsHTML(enabled);
      place(screen);
    }

    function moveTo(target) {
      var inner = screen.inner.getBoundingClientRect();
      var box = target.getBoundingClientRect();
      var next = {
        x: (box.left - inner.left + Math.min(14, box.width * 0.35)) / screen.scale,
        y: (box.top - inner.top + box.height * 0.55) / screen.scale,
        opacity: 1
      };
      var anim = screen.pointer.animate(
        [
          { opacity: spot.opacity, transform: "translate(" + spot.x + "px," + spot.y + "px)" },
          { opacity: 1, transform: "translate(" + next.x + "px," + next.y + "px)" }
        ],
        { duration: spot.opacity ? 520 : 800, easing: "cubic-bezier(.35,.7,.2,1)", fill: "forwards" }
      );
      spot = next;
      return anim.finished;
    }

    function click() {
      var at = "translate(" + spot.x + "px," + spot.y + "px)";
      return screen.pointer.animate(
        [{ transform: at }, { transform: at + " scale(.82)" }, { transform: at }],
        { duration: 180, easing: "ease-out" }
      ).finished;
    }

    function hidePointer() {
      var at = "translate(" + spot.x + "px," + spot.y + "px)";
      spot = { x: spot.x, y: spot.y, opacity: 0 };
      return screen.pointer.animate(
        [{ opacity: 1, transform: at }, { opacity: 0, transform: at }],
        { duration: 250, fill: "forwards" }
      ).finished;
    }

    fit(screen);
    showUsage(first, reduced);
    if (reduced) return;

    var observer = new IntersectionObserver(function (entries) {
      if (!entries[0].isIntersecting) return;
      observer.disconnect();
      play();
    }, { threshold: 0.35 });
    observer.observe(el);

    function play() {
      enabled = { claude: true, codex: false, cursor: true, grok: false, openrouter: false, deepseek: false, moonshot: false };
      screen.pop.classList.remove("grow");
      showUsage(first, false);
      return wait(500)
        .then(function () { return moveTo(screen.si); })
        .then(click)
        .then(function () {
          screen.pop.classList.add("open", "grow");
          screen.si.classList.add("active");
          return wait(1300);
        })
        .then(function () { return moveTo(screen.body.querySelector(".pp-gear")); })
        .then(click)
        .then(function () {
          screen.pop.classList.remove("grow");
          showSettings();
          return wait(500);
        })
        .then(function () { return moveTo(screen.body.querySelector('[data-id="cursor"] i')); })
        .then(click)
        .then(function () {
          enabled.cursor = false;
          screen.body.querySelector('[data-id="cursor"]').classList.remove("on");
          return wait(400);
        })
        .then(function () { return moveTo(screen.body.querySelector('[data-id="codex"] i')); })
        .then(click)
        .then(function () {
          enabled.codex = true;
          screen.body.querySelector('[data-id="codex"]').classList.add("on");
          return wait(550);
        })
        .then(function () { return moveTo(screen.body.querySelector(".pp-gear")); })
        .then(click)
        .then(function () {
          showUsage(second, true);
          screen.pop.classList.add("grow");
          return wait(1500);
        })
        .then(hidePointer)
        .then(function () {
          screen.pop.classList.remove("open", "grow");
          screen.si.classList.remove("active");
          return wait(600);
        })
        .then(play);
    }
  }

  var PRESETS = {
    fresh: { claude: 4, codex: 2, cursor: 11, grok: 1, openrouter: 3, deepseek: 6, moonshot: 2 },
    busy: { claude: 58, codex: 41, cursor: 73, grok: 22, openrouter: 47, deepseek: 36, moonshot: 28 },
    out: { claude: 96, codex: 88, cursor: 91, grok: 79, openrouter: 94, deepseek: 86, moonshot: 90 }
  };

  function studio(el, form) {
    var screen = buildScreen(el);
    var state = {
      theme: "dark",
      on: { claude: true, codex: false, cursor: true, grok: false, openrouter: false, deepseek: false, moonshot: false },
      value: { claude: 42, codex: 18, cursor: 73, grok: 9, openrouter: 25, deepseek: 12, moonshot: 8 },
      flags: { claude: false, codex: false, cursor: false }
    };
    var rows = form.querySelector("[data-rows]");
    rows.innerHTML = ORDER.map(function (id) {
      var name = PROVIDERS[id].name;
      return '<div class="row" data-row="' + id + '">' +
        '<label class="sw"><input type="checkbox" data-on="' + id + '"' + (state.on[id] ? " checked" : "") + '>' +
        '<span class="sw-ui" aria-hidden="true"></span><span class="row-name">' + glyph(id) + name + "</span></label>" +
        '<output data-out="' + id + '"></output>' +
        '<input type="range" min="0" max="100" value="' + state.value[id] + '" data-v="' + id + '" aria-label="' + name + ' usage">' +
        "</div>";
    }).join("");

    function sync() {
      ORDER.forEach(function (id) {
        var v = Math.round(state.value[id]);
        var row = rows.querySelector('[data-row="' + id + '"]');
        var range = row.querySelector("[data-v]");
        row.classList.toggle("off", !state.on[id]);
        row.dataset.heat = heat(v);
        range.value = v;
        range.style.setProperty("--p", v + "%");
        row.querySelector("[data-out]").textContent = v + "%";
      });
      render(screen, {
        theme: state.theme,
        flags: state.flags,
        readings: ORDER.filter(function (id) { return state.on[id]; }).map(function (id) { return [id, state.value[id]]; })
      });
    }

    form.addEventListener("input", function (event) {
      var t = event.target;
      if (t.dataset.on) state.on[t.dataset.on] = t.checked;
      if (t.dataset.flag) state.flags[t.dataset.flag] = t.checked;
      if (t.dataset.v) {
        state.value[t.dataset.v] = +t.value;
        state.on[t.dataset.v] = true;
        rows.querySelector('[data-on="' + t.dataset.v + '"]').checked = true;
      }
      if (t.name === "theme") state.theme = t.value;
      sync();
    });

    form.addEventListener("click", function (event) {
      var button = event.target.closest("[data-preset]");
      if (!button) return;
      var from = Object.assign({}, state.value);
      var to = PRESETS[button.dataset.preset];
      ORDER.forEach(function (id) {
        state.on[id] = true;
        rows.querySelector('[data-on="' + id + '"]').checked = true;
      });
      if (reduced) {
        state.value = Object.assign({}, to);
        sync();
        return;
      }
      tween(450, function (k) {
        ORDER.forEach(function (id) { state.value[id] = from[id] + (to[id] - from[id]) * k; });
        sync();
      });
    });

    screen.si.classList.add("active");
    screen.pop.classList.add("open");
    fit(screen);
    sync();
  }

  function releaseLinks() {
    var slot = document.querySelector("[data-version]");
    if (!window.fetch) return;
    fetch("https://api.github.com/repos/hgrafa/ai-usage-tracker/releases/latest")
      .then(function (response) {
        if (!response.ok) throw new Error("release");
        return response.json();
      })
      .then(function (release) {
        var disk = (release.assets || []).filter(function (a) { return a.name === "AI-Usage.dmg"; })[0];
        if (disk && disk.browser_download_url) {
          document.querySelectorAll("[data-download]").forEach(function (link) {
            link.href = disk.browser_download_url;
          });
        }
        if (slot && release.tag_name) {
          slot.textContent = release.tag_name;
          slot.parentNode.setAttribute("aria-label", "Version " + release.tag_name + " on GitHub");
        }
      })
      .catch(function () {});
  }

  function start() {
    var heroEl = document.querySelector('[data-screen="hero"]');
    if (heroEl) hero(heroEl);
    var studioEl = document.querySelector('[data-screen="studio"]');
    var form = document.querySelector("[data-controls]");
    if (studioEl && form) studio(studioEl, form);

    var resize = new ResizeObserver(function () { screens.forEach(fit); });
    screens.forEach(function (s) { resize.observe(s.el); });

    setInterval(function () {
      screens.forEach(function (s) { s.clock.innerHTML = clockText(); });
    }, 30000);

    releaseLinks();
    slideProviders();
  }

  function slideProviders() {
    if (reduced) return;
    var track = document.querySelector(".providers-track");
    var list = track && track.querySelector(".providers");
    if (!track || !list) return;
    var copy = list.cloneNode(true);
    copy.setAttribute("aria-hidden", "true");
    track.appendChild(copy);
    track.classList.add("sliding");
  }

  if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(start);
  } else {
    start();
  }
})();
