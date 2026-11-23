import Foundation

/// 只读副屏页面：模拟时钟 + 当月月历。
/// 页面不包含 token、不调用任何 /api/* 接口，拿到地址也只能看时间与日期。
enum ScreenHTML {
    static let version = "2026-11-23.10"
    static let content = """
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black">
    <meta name="apple-mobile-web-app-title" content="副屏">
    <meta name="theme-color" content="#000000">
    <meta name="color-scheme" content="dark">
    <meta name="screen-version" content="\(version)">
    <title>副屏 · 时钟与月历</title>
    <link rel="apple-touch-icon" href="/apple-touch-icon.png">
    <style>
      :root {
        color-scheme: dark;
        --bg: #000;
        --ink: #fff;
        --muted: #8e8e93;
        --accent: #ff3b30;
        --second: #ff9f0a;
        --frame: rgba(255, 255, 255, .14);
      }
      * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
      html, body {
        height: 100%; margin: 0;
        background: var(--bg); color: var(--ink);
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "PingFang SC", "Helvetica Neue", Arial, sans-serif;
        -webkit-font-smoothing: antialiased;
      }
      body {
        position: fixed; inset: 0; overflow: hidden;
        overscroll-behavior: none;
        -webkit-user-select: none; user-select: none;
        touch-action: manipulation;
      }
      #frame {
        --scale: 1;
        --u: calc(clamp(3.2px, 1.55vmin, 6.4px) * var(--scale));
        position: fixed; inset: 0;
        padding: calc(env(safe-area-inset-top, 0px) + var(--u) * 3)
                 calc(env(safe-area-inset-right, 0px) + var(--u) * 3)
                 calc(env(safe-area-inset-bottom, 0px) + var(--u) * 3)
                 calc(env(safe-area-inset-left, 0px) + var(--u) * 3);
        display: flex;
        cursor: default;
      }
      #frame[data-size="s"] { --scale: .82; }
      #frame[data-size="m"] { --scale: 1; }
      #frame[data-size="l"] { --scale: 1.18; }

      .stage {
        flex: 1 1 auto;
        display: flex;
        flex-direction: column;
        gap: calc(var(--u) * 2.2);
        min-width: 0; min-height: 0;
      }
      .col {
        min-width: 0; min-height: 0;
        display: flex; flex-direction: column;
      }
      .clock-col { flex: 0 0 30%; }
      .cal-col { flex: 1 1 auto; justify-content: center; }
      .wx-col { flex: 0 0 auto; }

      /* 三栏共用同一套头部节奏：kicker + 1px 分隔线。 */
      .kicker {
        color: var(--muted);
        font-size: calc(var(--u) * 1.85);
        font-weight: 500;
        letter-spacing: .14em;
        text-transform: uppercase;
        line-height: 1.15;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        flex: 0 0 auto;
      }
      .kicker.right { text-align: right; }
      .kicker.center { text-align: center; }
      .rule {
        flex: 0 0 auto;
        height: 1px;
        background: rgba(255, 255, 255, .14);
        margin: calc(var(--u) * 1.1) 0 calc(var(--u) * 1.7);
      }

      .clock {
        flex: 1 1 auto;
        min-height: 0;
        display: flex; flex-direction: column;
        align-items: center; justify-content: center;
        gap: calc(var(--u) * .8);
      }
      .clock canvas {
        display: block;
        width: 100%;
        max-height: 100%;
        aspect-ratio: 1 / 1;
        height: auto;
      }
      .date-line {
        flex: 0 0 auto;
        text-align: center;
        color: var(--muted);
        font-size: calc(var(--u) * 2.3);
        letter-spacing: .12em;
        font-variant-numeric: tabular-nums;
        white-space: nowrap;
      }

      .cal {
        flex: 1 1 auto;
        min-height: 0; min-width: 0;
        display: flex; flex-direction: column;
        justify-content: center;
      }
      .mon {
        display: flex; align-items: baseline; justify-content: center;
        gap: calc(var(--u) * 1.4);
        margin-bottom: calc(var(--u) * 1.6);
      }
      .mon .title {
        color: var(--accent);
        font-size: 2.6vw;
        font-weight: 700;
        letter-spacing: .11em;
        line-height: 1;
        border: 0; background: none; padding: 0;
        font-family: inherit;
        cursor: pointer;
      }
      .mon .year {
        color: var(--muted);
        font-size: 1.5vw;
        letter-spacing: .1em;
        font-variant-numeric: tabular-nums;
      }
      .nav {
        appearance: none; border: 0; background: none;
        color: rgba(255, 255, 255, .38);
        font-size: 2vw;
        line-height: 1; padding: calc(var(--u) * .5) calc(var(--u) * .9);
        font-family: inherit; cursor: pointer;
        transition: color .2s;
      }
      .nav:active { color: var(--ink); }
      .dow, .grid {
        display: grid;
        grid-template-columns: repeat(7, minmax(0, 1fr));
      }
      .dow {
        color: var(--muted);
        font-size: calc(var(--u) * 2.2);
        letter-spacing: .05em;
        text-align: center;
        margin-bottom: calc(var(--u) * .8);
      }
      .grid {
        grid-template-rows: repeat(5, minmax(0, 1fr));
        flex: 1 1 auto;
        min-height: 0;
      }
      .cell {
        display: flex; align-items: center; justify-content: center;
        font-size: calc(var(--u) * 2.8);
        line-height: 1;
        font-variant-numeric: tabular-nums;
        color: var(--ink);
        min-width: 0;
      }
      .cell span {
        display: grid; place-items: center;
        width: 1.9em; height: 1.9em;
        border-radius: 999px;
      }
      .cell.today span {
        background: var(--accent);
        color: #000;
        font-weight: 700;
      }
      .cell.blank span { visibility: hidden; }

      /* ---- 天气：城市 / 概览 / 预报表（MagicMirror 右上角结构）---- */
      .wx-col { gap: 0; }
      .wx-status {
        display: none;
        color: #ff9f0a;
        font-size: calc(var(--u) * 2.4);
        padding-bottom: calc(var(--u) * .8);
      }
      #frame[data-weather="error"] .wx-status { display: block; }
      .wx { display: none; min-width: 0; }
      .wx-now { flex: 0 0 auto; flex-direction: column; }
      .wx-block { display: none; flex: 0 0 auto; margin-top: calc(var(--u) * 1.6); }
      #frame[data-weather="on"] .wx-now { display: flex; }
      #frame[data-weather="on"] .wx-block { display: block; }
      #frame[data-weather="off"] .wx-col { display: none; }

      .wx-meta {
        display: flex; justify-content: space-between;
        gap: calc(var(--u) * 1.2);
        color: var(--muted);
        font-size: calc(var(--u) * 2.3);
        font-variant-numeric: tabular-nums;
        white-space: nowrap;
      }
      .wx-hero {
        display: flex; align-items: center; justify-content: flex-end;
        gap: calc(var(--u) * 1.2);
        margin-top: calc(var(--u) * .8);
      }
      .wx-icon {
        flex: 0 0 auto;
        width: calc(var(--u) * 9);
        height: calc(var(--u) * 9);
        color: var(--ink);
      }
      .wx-icon svg { width: 100%; height: 100%; display: block; }
      .wx-temp {
        margin-left: auto;
        font-size: calc(var(--u) * 7.4);
        font-weight: 200;
        line-height: .95;
        letter-spacing: -.03em;
        font-variant-numeric: tabular-nums;
        white-space: nowrap;
      }
      .wx-feels {
        text-align: right;
        color: var(--muted);
        font-size: calc(var(--u) * 3);
        font-variant-numeric: tabular-nums;
        margin-top: calc(var(--u) * .2);
        white-space: nowrap;
      }
      .wx-feels b { color: var(--ink); font-weight: 400; }

      /* 未来几小时：两行紧凑条（时间 / 图标+温度），不额外占用太多高度。 */
      .wx-hours {
        display: none;
        grid-template-columns: repeat(5, minmax(0, 1fr));
        column-gap: calc(var(--u) * .4);
        border-top: 1px solid rgba(255, 255, 255, .12);
        margin-top: calc(var(--u) * 1.2);
        padding-top: calc(var(--u) * .9);
      }
      #frame[data-weather="on"] .wx-hours { display: grid; }
      .wx-hours[hidden] { display: none !important; }
      .wx-hour {
        display: flex; flex-direction: column; align-items: center;
        gap: calc(var(--u) * .3);
        min-width: 0;
      }
      .wx-hour .t {
        color: var(--muted);
        font-size: calc(var(--u) * 2.1);
        white-space: nowrap;
      }
      .wx-hour .v {
        display: flex; align-items: center;
        gap: calc(var(--u) * .3);
        font-size: calc(var(--u) * 2.3);
        font-variant-numeric: tabular-nums;
        white-space: nowrap;
      }
      .wx-hour .v svg { width: calc(var(--u) * 3); height: calc(var(--u) * 3); display: block; }

      .wx-block .kicker { margin-top: calc(var(--u) * 1.2); }

      .wx-days { display: none; }
      #frame[data-weather="on"] .wx-days {
        display: flex; flex-direction: column;
        gap: calc(var(--u) * .7);
      }
      .wx-day {
        display: grid;
        grid-template-columns: minmax(0, 1fr) auto auto auto;
        align-items: center;
        column-gap: calc(var(--u) * 1.4);
        font-size: calc(var(--u) * 2.5);
        font-variant-numeric: tabular-nums;
      }
      .wx-day .d { color: var(--ink); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
      .wx-day .i {
        width: calc(var(--u) * 3.6);
        height: calc(var(--u) * 3.6);
        display: block;
        color: var(--ink);
      }
      .wx-day .i svg { width: 100%; height: 100%; display: block; }
      .wx-day .hi { text-align: right; min-width: 2.5em; }
      .wx-day .lo { text-align: right; min-width: 2.5em; color: var(--muted); }
      .wx-foot {
        flex: 0 0 auto;
        margin-top: calc(var(--u) * 1.2);
        color: var(--muted);
        font-size: calc(var(--u) * 2.05);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }
      .wx-foot a { color: inherit; text-decoration: none; }
      .wx-foot b { color: #ff9f0a; font-weight: 500; }

      .chrome {
        position: fixed;
        left: 50%;
        bottom: calc(env(safe-area-inset-bottom, 0px) + var(--u) * 4);
        transform: translate(-50%, calc(var(--u) * 2));
        display: flex; align-items: center; gap: calc(var(--u) * 1.4);
        padding: calc(var(--u) * 1.6) calc(var(--u) * 2);
        border-radius: 999px;
        background: rgba(28, 28, 30, .88);
        border: 1px solid rgba(255, 255, 255, .12);
        box-shadow: 0 12px 32px rgba(0, 0, 0, .55);
        backdrop-filter: blur(18px);
        -webkit-backdrop-filter: blur(18px);
        opacity: 0;
        pointer-events: none;
        transition: opacity .24s ease, transform .24s ease;
        z-index: 10;
      }
      #frame.ui .chrome {
        opacity: 1;
        pointer-events: auto;
        transform: translate(-50%, 0);
      }
      .seg {
        display: flex; gap: calc(var(--u) * .4);
        padding: calc(var(--u) * .5);
        border-radius: 999px;
        background: rgba(255, 255, 255, .07);
      }
      .seg button, .tool {
        appearance: none; border: 0;
        background: none; color: rgba(255, 255, 255, .72);
        font-family: inherit; font-size: calc(var(--u) * 2.7);
        padding: calc(var(--u) * 1.3) calc(var(--u) * 2.2);
        border-radius: 999px;
        cursor: pointer;
        white-space: nowrap;
      }
      .seg button.on {
        background: var(--accent);
        color: #000;
        font-weight: 600;
      }
      .tool.on { color: var(--ink); background: rgba(255, 255, 255, .1); }
      .status {
        color: var(--muted);
        font-size: calc(var(--u) * 2.45);
        padding: 0 calc(var(--u) * 1.2) 0 calc(var(--u) * .6);
        white-space: nowrap;
      }
      .status b { color: #34c759; font-weight: 600; }
      .status b.off { color: #ff9f0a; }

      @media (orientation: landscape) {
        /* 横屏三栏严格等宽：时钟 | 月历 | 天气。 */
        .stage {
          display: grid;
          grid-template-columns: repeat(3, minmax(0, 1fr));
          grid-template-rows: 1fr;
          gap: calc(var(--u) * 2.4);
          align-items: stretch;
        }
        .clock-col, .cal-col, .wx-col { grid-row: 1; }
        .clock-col { grid-column: 1; }
        .cal-col { grid-column: 2; }
        .wx-col { grid-column: 3; }
        #frame[data-weather="off"] .stage { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        #frame[data-weather="off"] .cal-col { grid-column: 2; }
        .cell { font-size: calc(var(--u) * 3); }
      }
      @media (orientation: portrait) {
        /* 竖屏：时钟 → 天气（含小时条/预报）→ 月历，压缩天气块给日历留足行高。 */
        .stage { flex-direction: column; gap: calc(var(--u) * 1.8); }
        .clock-col { flex: 0 0 20%; }
        #frame[data-weather="off"] .clock-col { flex-basis: 44%; }
        .mon { gap: 1.4vw; margin-bottom: calc(var(--u) * 1); }
        .mon .title { font-size: calc(6.4vw * var(--scale)); }
        .mon .year { font-size: calc(3.2vw * var(--scale)); }
        .nav { font-size: calc(4vw * var(--scale)); padding: .8vw 1.2vw; }
        .dow { font-size: calc(3.2vw * var(--scale)); }
        .cell { font-size: calc(4vw * var(--scale)); }
        .cell span { width: 1.5em; height: 1.5em; }
        .rule { margin: calc(var(--u) * .8) 0 calc(var(--u) * 1.2); }
        .wx-icon { width: calc(var(--u) * 7); height: calc(var(--u) * 7); }
        .wx-temp { font-size: calc(var(--u) * 5.8); }
        .wx-feels { font-size: calc(var(--u) * 2.5); }
        .wx-meta { font-size: calc(var(--u) * 2.1); }
        .wx-block .kicker { margin-top: calc(var(--u) * .6); }
        .wx-hours { margin-top: calc(var(--u) * .8); padding-top: calc(var(--u) * .6); }
        .wx-hour .t { font-size: calc(var(--u) * 1.9); }
        .wx-hour .v { font-size: calc(var(--u) * 2.1); }
        .wx-hour .v svg { width: calc(var(--u) * 2.8); height: calc(var(--u) * 2.8); }
        #frame[data-weather="on"] .wx-days { gap: calc(var(--u) * .3); }
        .wx-day { font-size: calc(var(--u) * 2.1); column-gap: calc(var(--u) * .8); }
        .wx-day .i { width: calc(var(--u) * 2.9); height: calc(var(--u) * 2.9); }
        .wx-foot { font-size: calc(var(--u) * 1.9); margin-top: calc(var(--u) * .6); }
      }
      /* 平板/桌面窗口等大屏上，别让月历网格无限拉伸；保持接近方形单元格并整体居中。 */
      @media (min-height: 700px) {
        .grid { max-height: calc(var(--u) * 46); }
      }
      @media (min-width: 640px) and (min-height: 520px) {
        #frame { inset: calc(var(--u) * 2.6); border-radius: calc(var(--u) * 6); border: 1px solid var(--frame); }
      }
      @media (max-height: 430px) {
        .mon { margin-bottom: calc(var(--u) * .8); }
        .dow { margin-bottom: calc(var(--u) * .4); }
        /* 很矮的横屏：压缩天气主视觉和预报行，给小时条腾空间。 */
        .wx-icon { width: calc(var(--u) * 7.6); height: calc(var(--u) * 7.6); }
        .wx-temp { font-size: calc(var(--u) * 6.6); }
        .wx-feels { font-size: calc(var(--u) * 2.7); }
        #frame[data-weather="on"] .wx-days { gap: calc(var(--u) * .4); }
        .wx-day { font-size: calc(var(--u) * 2.3); column-gap: calc(var(--u) * 1); }
        .wx-day .i { width: calc(var(--u) * 3); height: calc(var(--u) * 3); }
        .wx-hour .v svg { width: calc(var(--u) * 2.7); height: calc(var(--u) * 2.7); }
      }
    </style>
    </head>
    <body>
    <div id="frame" data-size="m" data-weather="off">
      <div class="stage">
        <section class="col clock-col">
          <div class="kicker">LOCAL TIME</div>
          <div class="rule"></div>
          <div class="clock">
            <canvas id="dial" aria-label="模拟时钟"></canvas>
            <div class="date-line" id="dateLine">—</div>
          </div>
        </section>

        <section class="col wx-col">
          <div class="kicker right" id="wxCity">WEATHER</div>
          <div class="rule"></div>
          <div class="wx-status" id="wxStatus">天气暂不可用</div>
          <div class="wx wx-now" id="wxNow">
            <div class="wx-meta" id="wxMeta"></div>
            <div class="wx-hero">
              <span class="wx-icon" id="wxIcon"></span>
              <span class="wx-temp" id="wxTemp">--°</span>
            </div>
            <div class="wx-feels" id="wxFeels"></div>
          </div>
          <div class="wx-hours" id="wxHours" hidden></div>
          <div class="wx-block">
            <div class="kicker">WEATHER FORECAST</div>
            <div class="rule"></div>
            <div class="wx-days" id="wxDays"></div>
          </div>
          <div class="wx-foot" id="wxFoot"></div>
        </section>

        <section class="col cal-col">
          <div class="kicker center">CALENDAR</div>
          <div class="rule"></div>
          <div class="cal">
            <div class="mon">
              <button class="nav" id="prev" aria-label="上个月">‹</button>
              <button class="title" id="month" aria-label="回到当月"></button>
              <span class="year" id="year"></span>
              <button class="nav" id="next" aria-label="下个月">›</button>
            </div>
            <div class="dow" aria-hidden="true">
              <span>S</span><span>M</span><span>T</span><span>W</span><span>T</span><span>F</span><span>S</span>
            </div>
            <div class="grid" id="grid" role="grid" aria-label="当月月历"></div>
          </div>
        </section>
      </div>
      <div class="chrome" id="chrome">
        <div class="seg" role="group" aria-label="尺寸">
          <button data-size="s">小</button>
          <button data-size="m">中</button>
          <button data-size="l">大</button>
        </div>
        <button class="tool" id="refresh" aria-label="强制刷新">↻</button>
        <button class="tool" id="fullscreen" hidden>全屏</button>
        <span class="status" id="awake">常亮：<b class="off">待授权</b></span>
      </div>
    </div>
    <script>
    (function () {
      var frame = document.getElementById('frame');
      var canvas = document.getElementById('dial');
      var ctx = canvas.getContext('2d');
      var grid = document.getElementById('grid');
      var monthLabel = document.getElementById('month');
      var yearLabel = document.getElementById('year');
      var awakeLabel = document.getElementById('awake');
      var fullscreenBtn = document.getElementById('fullscreen');
      var refreshBtn = document.getElementById('refresh');
      var dateLine = document.getElementById('dateLine');
      var wxCity = document.getElementById('wxCity');
      var wxStatus = document.getElementById('wxStatus');
      var wxMeta = document.getElementById('wxMeta');
      var wxIcon = document.getElementById('wxIcon');
      var wxTemp = document.getElementById('wxTemp');
      var wxFeels = document.getElementById('wxFeels');
      var wxHours = document.getElementById('wxHours');
      var wxFoot = document.getElementById('wxFoot');
      var wxDays = document.getElementById('wxDays');
      var MONTHS = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
                    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
      var WEEKDAYS = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
      var MONTHS_SHORT = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                          'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      var SIZE_KEY = 'deck_screen_size';

      // ---- Mac 墙钟 ----
      // 手机日期/时区可能与 Mac 不同；这里把 Mac 的 epoch 平移到“Mac 本地墙钟”，
      // 之后统一用 UTC getter 读取年月日时分秒。
      var macEpochSeconds = Date.now() / 1000;
      var macOffsetMinutes = -new Date().getTimezoneOffset();
      var macFetchedAt = Date.now();
      var screenVersionMeta = document.querySelector('meta[name="screen-version"]');
      var screenVersion = screenVersionMeta ? screenVersionMeta.content : '';

      function macWall() {
        var ms = (macEpochSeconds + macOffsetMinutes * 60) * 1000 + (Date.now() - macFetchedAt);
        return new Date(ms);
      }

      function updateDateLine(wall) {
        var date = wall || macWall();
        dateLine.textContent = WEEKDAYS[date.getUTCDay()] + ' ' + date.getUTCDate() + ' ' +
          MONTHS_SHORT[date.getUTCMonth()];
      }

      function loadMacTime() {
        fetch('/api/time', { cache: 'no-store' }).then(function (response) {
          if (!response.ok) { throw new Error('HTTP ' + response.status); }
          return response.json();
        }).then(function (data) {
          if (!data || typeof data.epoch !== 'number') { return; }
          if (data.screenVersion && screenVersion && data.screenVersion !== screenVersion) {
            location.replace('/screen/?v=' + encodeURIComponent(data.screenVersion) + '&t=' + Date.now());
            return;
          }
          var previous = macWall();
          var wasCurrentMonth = viewYear === previous.getUTCFullYear() &&
                                viewMonth === previous.getUTCMonth();
          macEpochSeconds = data.epoch;
          macOffsetMinutes = typeof data.offsetMinutes === 'number' ? data.offsetMinutes : 0;
          macFetchedAt = Date.now();
          var current = macWall();
          if (wasCurrentMonth) {
            viewYear = current.getUTCFullYear();
            viewMonth = current.getUTCMonth();
          }
          updateDateLine(current);
          drawDial(current);
          renderCalendar();
        }).catch(function () {});
      }

      // ---- 尺寸 ----
      var savedSize = null;
      try { savedSize = localStorage.getItem(SIZE_KEY); } catch (e) {}
      setSize(savedSize === 's' || savedSize === 'l' ? savedSize : 'm');

      function setSize(size) {
        frame.dataset.size = size;
        var buttons = frame.querySelectorAll('.seg button');
        for (var i = 0; i < buttons.length; i++) {
          buttons[i].classList.toggle('on', buttons[i].dataset.size === size);
        }
        try { localStorage.setItem(SIZE_KEY, size); } catch (e) {}
        drawDial(macWall());
      }

      var sizeButtons = frame.querySelectorAll('.seg button');
      for (var i = 0; i < sizeButtons.length; i++) {
        sizeButtons[i].addEventListener('click', function (event) {
          setSize(event.currentTarget.dataset.size);
          keepUIVisible();
        });
      }

      // ---- 控制条 ----
      var hideTimer = null;
      function showUI() {
        frame.classList.add('ui');
        keepUIVisible();
      }
      function keepUIVisible() {
        frame.classList.add('ui');
        if (hideTimer) { clearTimeout(hideTimer); }
        hideTimer = setTimeout(function () { frame.classList.remove('ui'); }, 5000);
      }
      frame.addEventListener('pointerdown', function (event) {
        if (event.target.closest && event.target.closest('.chrome')) { return; }
        showUI();
        requestWakeLock();
      });

      // ---- 常亮 ----
      var wakeLock = null;
      function setAwake(kind) {
        var text = kind === 'on' ? '<b>开</b>'
                 : (kind === 'off' ? '<b class="off">不可用</b>' : '<b class="off">待授权</b>');
        awakeLabel.innerHTML = '常亮：' + text;
      }
      function requestWakeLock() {
        if (!('wakeLock' in navigator) || !navigator.wakeLock) {
          setAwake('off');
          return;
        }
        if (wakeLock && !wakeLock.released) { setAwake('on'); return; }
        navigator.wakeLock.request('screen').then(function (lock) {
          wakeLock = lock;
          setAwake('on');
          lock.addEventListener('release', function () {
            wakeLock = null;
            if (document.visibilityState === 'visible') { requestWakeLock(); }
          });
        }).catch(function () {
          setAwake('wait');
        });
      }
      document.addEventListener('visibilitychange', function () {
        if (document.visibilityState === 'visible') {
          requestWakeLock();
          renderCalendar();
          drawDial(macWall());
        }
      });
      requestWakeLock();

      // ---- 全屏 ----
      if (document.documentElement.requestFullscreen) {
        fullscreenBtn.hidden = false;
        fullscreenBtn.addEventListener('click', function () {
          if (document.fullscreenElement) {
            document.exitFullscreen();
          } else {
            document.documentElement.requestFullscreen().catch(function () {});
          }
          keepUIVisible();
        });
      }

      // ---- 月历 ----
      var initialWall = macWall();
      var today = initialWall;
      var viewYear = initialWall.getUTCFullYear();
      var viewMonth = initialWall.getUTCMonth();
      var lastTouched = Date.now();

      function isToday(year, month, day) {
        var wall = macWall();
        return wall.getUTCFullYear() === year &&
               wall.getUTCMonth() === month &&
               wall.getUTCDate() === day;
      }

      function renderCalendar() {
        today = macWall();
        var first = new Date(viewYear, viewMonth, 1);
        var startDow = first.getDay();
        var days = new Date(viewYear, viewMonth + 1, 0).getDate();
        var total = 42;
        var out = '';
        for (var i = 0; i < total; i++) {
          var day = i - startDow + 1;
          if (day < 1 || day > days) {
            out += '<div class="cell blank" role="gridcell"><span>·</span></div>';
            continue;
          }
          var cls = isToday(viewYear, viewMonth, day) ? 'cell today' : 'cell';
          out += '<div class="' + cls + '" role="gridcell"><span>' + day + '</span></div>';
        }
        grid.innerHTML = out;
        var rows = Math.max(4, Math.ceil((startDow + days) / 7));
        grid.style.gridTemplateRows = 'repeat(' + rows + ', minmax(0, 1fr))';
        monthLabel.textContent = MONTHS[viewMonth];
        yearLabel.textContent = String(viewYear);
      }

      function shiftMonth(delta) {
        var total = viewYear * 12 + viewMonth + delta;
        viewYear = Math.floor(total / 12);
        viewMonth = ((total % 12) + 12) % 12;
        lastTouched = Date.now();
        renderCalendar();
      }

      function goToday() {
        var wall = macWall();
        viewYear = wall.getUTCFullYear();
        viewMonth = wall.getUTCMonth();
        lastTouched = Date.now();
        renderCalendar();
      }

      document.getElementById('prev').addEventListener('click', function () { shiftMonth(-1); keepUIVisible(); });
      document.getElementById('next').addEventListener('click', function () { shiftMonth(1); keepUIVisible(); });
      monthLabel.addEventListener('click', function () { goToday(); keepUIVisible(); });

      // 浏览他月超过 60 秒自动回到当月；跨日/跨月自动刷新。
      var lastDayKey = '';
      setInterval(function () {
        var wall = macWall();
        var key = wall.getUTCFullYear() + '-' + wall.getUTCMonth() + '-' + wall.getUTCDate();
        var isCurrentMonth = viewYear === wall.getUTCFullYear() && viewMonth === wall.getUTCMonth();
        if (key !== lastDayKey) {
          lastDayKey = key;
          if (isCurrentMonth) { renderCalendar(); }
        }
        if (!isCurrentMonth && Date.now() - lastTouched > 60000) { goToday(); }
      }, 5000);
      renderCalendar();

      // ---- 模拟时钟 ----
      var lastDraw = 0;
      var pendingFrame = null;

      function hand(cx, cy, angleDeg, length, width, color) {
        var angle = (angleDeg - 90) * Math.PI / 180;
        ctx.beginPath();
        ctx.strokeStyle = color;
        ctx.lineWidth = width;
        ctx.lineCap = 'round';
        ctx.moveTo(cx, cy);
        ctx.lineTo(cx + Math.cos(angle) * length, cy + Math.sin(angle) * length);
        ctx.stroke();
      }

      function drawDial(now) {
        var dpr = window.devicePixelRatio || 1;
        var w = canvas.clientWidth;
        var h = canvas.clientHeight;
        if (!w || !h) { return; }
        var pw = Math.round(w * dpr);
        var ph = Math.round(h * dpr);
        if (canvas.width !== pw || canvas.height !== ph) {
          canvas.width = pw;
          canvas.height = ph;
        }
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.clearRect(0, 0, w, h);

        var cx = w / 2;
        var cy = h / 2;
        var R = Math.min(w, h) / 2 * 0.96;

        for (var i = 0; i < 60; i++) {
          var major = i % 5 === 0;
          var angle = (i * 6 - 90) * Math.PI / 180;
          var outer = R * 0.985;
          var inner = R * (major ? 0.9 : 0.945);
          ctx.beginPath();
          ctx.strokeStyle = major ? 'rgba(255,255,255,.92)' : 'rgba(255,255,255,.38)';
          ctx.lineWidth = major ? R * 0.022 : R * 0.0085;
          ctx.lineCap = 'round';
          ctx.moveTo(cx + Math.cos(angle) * inner, cy + Math.sin(angle) * inner);
          ctx.lineTo(cx + Math.cos(angle) * outer, cy + Math.sin(angle) * outer);
          ctx.stroke();
        }

        ctx.fillStyle = '#fff';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.font = '600 ' + (R * 0.185) + 'px -apple-system, "SF Pro Display", "Helvetica Neue", Arial, sans-serif';
        var numberR = R * 0.735;
        for (var n = 1; n <= 12; n++) {
          var na = (n * 30 - 90) * Math.PI / 180;
          ctx.fillText(String(n), cx + Math.cos(na) * numberR, cy + Math.sin(na) * numberR + R * 0.008);
        }

        var hours = now.getUTCHours() % 12;
        var minutes = now.getUTCMinutes();
        var seconds = now.getUTCSeconds() + now.getUTCMilliseconds() / 1000;

        hand(cx, cy, (hours + minutes / 60) * 30, R * 0.46, R * 0.055, '#fff');
        hand(cx, cy, (minutes + seconds / 60) * 6, R * 0.68, R * 0.036, '#fff');
        hand(cx, cy, seconds * 6, R * 0.82, R * 0.011, '#ff9f0a');

        ctx.beginPath();
        ctx.fillStyle = '#ff9f0a';
        ctx.arc(cx, cy, R * 0.03, 0, Math.PI * 2);
        ctx.fill();
        ctx.beginPath();
        ctx.fillStyle = '#7a4a00';
        ctx.arc(cx, cy, R * 0.012, 0, Math.PI * 2);
        ctx.fill();
      }

      function loop(timestamp) {
        if (timestamp - lastDraw > 66) {
          drawDial(macWall());
          lastDraw = timestamp;
        }
        pendingFrame = requestAnimationFrame(loop);
      }

      function startClock() {
        if (pendingFrame === null) {
          drawDial(macWall());
          pendingFrame = requestAnimationFrame(loop);
        }
      }
      function stopClock() {
        if (pendingFrame !== null) {
          cancelAnimationFrame(pendingFrame);
          pendingFrame = null;
        }
      }
      document.addEventListener('visibilitychange', function () {
        if (document.visibilityState === 'visible') { startClock(); } else { stopClock(); }
      });
      if (window.ResizeObserver) {
        new ResizeObserver(function () { drawDial(macWall()); }).observe(canvas);
      } else {
        window.addEventListener('resize', function () { drawDial(macWall()); });
      }
      startClock();

      // ---- 天气 ----
      var weatherTimer = null;
      var lastWeatherFetch = 0;

      function weatherIcon(code) {
        var c = String(code == null ? '' : code).toLowerCase();
        var n = parseInt(c, 10);
        var kind = 'cloud';
        if (/thunder|storm/.test(c) || (n >= 200 && n < 300)) { kind = 'thunder'; }
        else if (/snow/.test(c) || (n >= 400 && n < 500)) { kind = 'snow'; }
        else if (/rain/.test(c) || (n >= 300 && n < 400)) { kind = 'rain'; }
        else if (/fog|haze|mist|smoke/.test(c) || (n >= 500 && n < 600)) { kind = 'fog'; }
        else if (/clear|sun/.test(c) || n === 100 || n === 150) { kind = 'sun'; }
        var open = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">';
        var cloud = '<path d="M7 16.5h9.1a3.7 3.7 0 0 0 .2-7.4A5 5 0 0 0 6.8 10.6 3.5 3.5 0 0 0 7 16.5Z"/>';
        if (kind === 'sun') {
          return open + '<circle cx="12" cy="12" r="4"/><path d="M12 2.6v2M12 19.4v2M2.6 12h2M19.4 12h2M5.4 5.4l1.4 1.4M17.2 17.2l1.4 1.4M18.6 5.4l-1.4 1.4M6.8 17.2l-1.4 1.4"/>' + '</svg>';
        }
        if (kind === 'rain') {
          return open + cloud + '<path d="M8.5 18.5l-.6 2M12.2 18.5l-.6 2M15.9 18.5l-.6 2"/>' + '</svg>';
        }
        if (kind === 'snow') {
          return open + cloud + '<path d="M9 19v2.4M7.9 20.2h2.2M15 19v2.4M13.9 20.2h2.2"/>' + '</svg>';
        }
        if (kind === 'fog') {
          return open + cloud + '<path d="M7 19.5h10M8.5 21.5h7"/>' + '</svg>';
        }
        if (kind === 'thunder') {
          return open + cloud + '<path d="M12.6 17.5l-1.8 3.2h2.4l-1.1 2.3 3.4-3.6h-2.2l1-1.9Z"/>' + '</svg>';
        }
        return open + cloud + '</svg>';
      }

      function dayLabel(dateString) {
        if (!dateString) { return ''; }
        var parts = String(dateString).split('-');
        if (parts.length < 3) { return ''; }
        var dateUTC = Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        var wall = macWall();
        var todayUTC = Date.UTC(wall.getUTCFullYear(), wall.getUTCMonth(), wall.getUTCDate());
        var diff = Math.round((dateUTC - todayUTC) / 86400000);
        if (diff === 0) { return '今天'; }
        if (diff === 1) { return '明天'; }
        if (diff === 2) { return '后天'; }
        return '周' + '日一二三四五六'.charAt(new Date(dateUTC).getUTCDay());
      }

      function formatUpdated(value) {
        if (!value) { return ''; }
        var date = new Date(value);
        if (isNaN(date.getTime())) { return ''; }
        var wall = new Date(date.getTime() + macOffsetMinutes * 60000);
        var hh = String(wall.getUTCHours()).padStart(2, '0');
        var mm = String(wall.getUTCMinutes()).padStart(2, '0');
        return hh + ':' + mm;
      }

      function formatHour(value) {
        if (!value) { return ''; }
        var date = new Date(value);
        if (isNaN(date.getTime())) { return ''; }
        var wall = new Date(date.getTime() + macOffsetMinutes * 60000);
        return wall.getUTCHours() + '时';
      }

      function renderWeather(data) {
        frame.dataset.weather = 'on';
        wxStatus.textContent = '';
        var now = data.now || {};
        var today = data.today || {};

        wxCity.textContent = data.city || 'WEATHER';
        var humidity = now.humidity == null ? '—' : now.humidity + '%';
        var rain = today.precipProbability == null ? '—' : today.precipProbability + '%';
        wxMeta.innerHTML = '<span>湿度 ' + humidity + '</span><span>降水 ' + rain + '</span>';
        wxIcon.innerHTML = weatherIcon(now.icon);
        wxTemp.textContent = now.temp == null ? '—' : now.temp + '°';
        wxFeels.innerHTML = now.feelsLike == null ? '' : '体感 <b>' + now.feelsLike + '°</b>';

        var hours = Array.isArray(data.hourly) ? data.hourly : [];
        if (hours.length) {
          var cells = [{ label: '现在', icon: now.icon, temp: now.temp }];
          hours.slice(0, 4).forEach(function (hour) {
            cells.push({ label: formatHour(hour.time), icon: hour.icon, temp: hour.temp });
          });
          wxHours.innerHTML = cells.map(function (cell) {
            return '<div class="wx-hour">' +
              '<div class="t">' + cell.label + '</div>' +
              '<div class="v">' + weatherIcon(cell.icon) +
                '<span>' + (cell.temp == null ? '—' : cell.temp + '°') + '</span>' +
              '</div></div>';
          }).join('');
          wxHours.hidden = false;
        } else {
          wxHours.innerHTML = '';
          wxHours.hidden = true;
        }

        var updated = formatUpdated(data.updatedAt);
        wxFoot.innerHTML = (updated ? '更新 ' + updated + ' · ' : '') +
          '<a href="https://www.qweather.com" target="_blank" rel="noreferrer">' + (data.attribution || '和风天气') + '</a>' +
          (data.stale ? ' · <b>已过期</b>' : '');

        var days = Array.isArray(data.daily) ? data.daily.slice(0, 5) : [];
        wxDays.innerHTML = days.map(function (day) {
          var max = day.max == null ? '—' : day.max + '°';
          var min = day.min == null ? '—' : day.min + '°';
          return '<div class="wx-day">' +
            '<div class="d">' + dayLabel(day.date) + '</div>' +
            '<div class="i">' + weatherIcon(day.icon) + '</div>' +
            '<div class="hi">' + max + '</div>' +
            '<div class="lo">' + min + '</div>' +
            '</div>';
        }).join('');
      }

      function renderWeatherError(message) {
        frame.dataset.weather = 'error';
        wxStatus.textContent = message || '天气暂不可用';
        wxHours.hidden = true;
      }

      function clearWeather() {
        frame.dataset.weather = 'off';
        wxStatus.style.display = 'none';
        wxStatus.textContent = '';
        wxCity.textContent = 'WEATHER';
        wxMeta.innerHTML = '';
        wxIcon.innerHTML = '';
        wxTemp.textContent = '--°';
        wxFeels.innerHTML = '';
        wxHours.innerHTML = '';
        wxHours.hidden = true;
        wxFoot.innerHTML = '';
        wxDays.innerHTML = '';
      }

      function loadWeather() {
        lastWeatherFetch = Date.now();
        fetch('/api/weather', { cache: 'no-store' }).then(function (response) {
          if (!response.ok) { throw new Error('HTTP ' + response.status); }
          return response.json();
        }).then(function (data) {
          if (data && data.ok) {
            renderWeather(data);
            return;
          }
          if (data && data.reason === 'not-configured') {
            clearWeather();
            return;
          }
          renderWeatherError(data && data.message ? data.message : '天气暂不可用');
        }).catch(function () {
          renderWeatherError('天气暂不可用');
        });
      }

      function scheduleWeather() {
        if (weatherTimer) { clearInterval(weatherTimer); }
        weatherTimer = setInterval(function () {
          if (document.visibilityState === 'visible') { loadWeather(); }
        }, 30 * 1000);
      }

      document.addEventListener('visibilitychange', function () {
        if (document.visibilityState === 'visible') {
          loadMacTime();
          loadWeather();
        }
      });
      var screenEventRevision = 0;
      var eventInFlight = false;
      function watchScreenEvents() {
        if (eventInFlight) { return; }
        if (document.visibilityState !== 'visible') {
          setTimeout(watchScreenEvents, 2000);
          return;
        }
        eventInFlight = true;
        fetch('/api/screen/events?since=' + screenEventRevision, { cache: 'no-store' })
          .then(function (response) {
            if (!response.ok) { throw new Error('HTTP ' + response.status); }
            return response.json();
          })
          .then(function (data) {
            if (!data || typeof data.revision !== 'number') { return; }
            if (data.revision !== screenEventRevision) {
              screenEventRevision = data.revision;
              loadMacTime();
              loadWeather();
            }
          })
          .catch(function () {})
          .finally(function () {
            eventInFlight = false;
            setTimeout(watchScreenEvents, 800);
          });
      }

      updateDateLine(macWall());
      loadMacTime();
      watchScreenEvents();
      setInterval(function () {
        if (document.visibilityState === 'visible') { loadMacTime(); }
      }, 60 * 1000);
      loadWeather();
      scheduleWeather();

      // 首次进入短暂展示控制条，提示可点按。
      setTimeout(showUI, 400);
    })();
    </script>
    </body>
    </html>
    """
}
