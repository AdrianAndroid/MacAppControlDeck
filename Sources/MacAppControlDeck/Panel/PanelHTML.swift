import Foundation

enum PanelHTML {
    static let version = "2026-11-24.1"
    static let content = """
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <meta name="apple-mobile-web-app-title" content="应用控制台">
    <meta name="theme-color" content="#0f1220">
    <meta name="panel-version" content="\(version)">
    <title>Mac 应用快捷控制台</title>
    <link rel="apple-touch-icon" href="/apple-touch-icon.png">
    <style>
      :root {
        color-scheme: dark;
        --bg:#0f1220; --card:#1b2036; --line:#2a3152; --fg:#eef1ff; --muted:#8d96c5;
        --ok:#4ade80; --warn:#fbbf24; --err:#f87171;
        --clock:#ff3b30; --clock-glow:rgba(255,59,48,.55);
        --u: clamp(3.2px, 1vmin, 4.8px);
        --gap: calc(var(--u) * 2.5);
        --app-cols: 2;
        --app-rows: 4;
        --sc-cols: 4;
        --sc-rows: 2;
        --sc-cell: clamp(60px, 9vh, 80px);
        --icon: clamp(32px, 10.5vmin, 44px);
        --label: clamp(11px, 3.1vmin, 13px);
        --radius: calc(var(--u) * 4);
        --left-rail: clamp(86px, 11vw, 108px);
        --rail-w: 160px;
        /* 快捷卡片默认与应用卡片同一字号；只在空间不足时等比缩小。 */
        --sc-unit: var(--label);
      }
      * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
      html, body { height:100%; -webkit-text-size-adjust:100%; text-size-adjust:100%; }
      body { margin:0; font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif; background:var(--bg); color:var(--fg);
             position:fixed; inset:0; overflow:hidden; overscroll-behavior:none;
             display:flex; flex-direction:column;
             padding:calc(env(safe-area-inset-top) + 10px) calc(env(safe-area-inset-right) + 12px) 0 calc(env(safe-area-inset-left) + 12px);
             touch-action:manipulation; -webkit-user-select:none; user-select:none; -webkit-touch-callout:none; }
      header { display:flex; justify-content:space-between; align-items:center; gap:8px; margin:0 auto 8px; width:100%; max-width:1280px; flex:0 0 auto; min-width:0; }
      h1 { font-size:clamp(14px,4.2vmin,17px); margin:0; font-weight:600; min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; flex:0 1 auto; }
      /* 竖屏顶部按钮不参与收缩，避免把状态徽标挤出屏幕。 */
      #reload, #fullscreen, #status { flex:0 0 auto; }
      #status { font-size:clamp(11px,3.2vmin,12px); padding:4px 10px; border-radius:999px; background:var(--card); border:1px solid var(--line); color:var(--muted); white-space:nowrap;
                cursor:pointer; -webkit-tap-highlight-color:transparent; }
      #fullscreen, #reload { flex:0 0 auto; border:1px solid var(--line); border-radius:9px; background:var(--card);
                    color:var(--fg); font:inherit; font-size:13px; font-weight:600; line-height:1; padding:6px 9px; cursor:pointer; white-space:nowrap; }
      #fullscreen:active, #reload:active { background:#232a4a; }
      #reload.refreshing { opacity:.55; }
      /* 收起开关仅横屏左轨显示；悬浮把手仅收起态在左上角出现。 */
      #railToggle, #railReveal { display:none; }
      #railReveal { position:fixed; left:calc(env(safe-area-inset-left, 0px) + 10px); top:calc(env(safe-area-inset-top, 0px) + 10px);
                    z-index:25; width:30px; height:30px; border-radius:50%; border:1px solid var(--line);
                    background:rgba(27,32,54,.7); color:var(--muted); font-size:16px; line-height:1;
                    align-items:center; justify-content:center; cursor:pointer; }
      #status:active { background:#232a4a; }
      #status.refreshing { opacity:.55; }
      #status.ok { color:var(--ok); border-color:#1f4d33; }
      #status.err { color:var(--err); border-color:#5c2733; }
      #clock { display:none; font-size:clamp(12px,2.7vmin,14px); font-weight:700; color:var(--clock); white-space:nowrap;
               font-variant-numeric:tabular-nums; letter-spacing:.3px; text-shadow:0 0 10px var(--clock-glow); }
      #toast { position:fixed; left:50%; transform:translateX(-50%); bottom:calc(env(safe-area-inset-bottom) + 20px);
               background:#262c4c; color:var(--fg); padding:10px 16px; border-radius:12px; font-size:14px; max-width:90vw;
               opacity:0; transition:opacity .25s; pointer-events:none; z-index:20; box-shadow:0 6px 24px rgba(0,0,0,.4); }
      #toast.show { opacity:1; }
      #main { display:none; flex-direction:column; flex:1 1 auto; min-height:0; gap:var(--gap); overflow:hidden;
              width:100%; max-width:1280px; margin:0 auto; padding-bottom:calc(env(safe-area-inset-bottom, 0px) + 2px); }
      #main.show { display:flex; }
      .zone { display:flex; flex-direction:column; min-height:0; }
      #appsZone { flex:1 1 auto; min-height:0; overflow:hidden; }
      #shortcutsZone { flex:0 0 auto; border-top:1px solid var(--line); padding-top:calc(var(--gap) - 2px); }
      /* 顶部标题行：左标题、右圆点+页码，横竖屏一致。 */
      .zone-head { flex:0 0 auto; display:flex; justify-content:space-between; align-items:baseline; gap:8px; margin:0 0 4px; }
      .zone-title { font-size:clamp(10px,2.8vmin,11px); color:var(--muted); margin:0; letter-spacing:.5px; }
      .pages { display:flex; overflow-x:auto; overflow-y:hidden; scroll-snap-type:x mandatory; scrollbar-width:none;
               -webkit-overflow-scrolling:touch; touch-action:pan-x; overscroll-behavior-x:contain; }
      #appsPages { flex:1 1 auto; min-height:0; }
      #shortcutPages { flex:0 0 auto; height:calc(var(--sc-rows) * var(--sc-cell) + (var(--sc-rows) - 1) * var(--gap) + 2px); }
      .pages::-webkit-scrollbar { display:none; }
      .page { flex:0 0 100%; width:100%; height:100%; scroll-snap-align:start; display:grid; gap:var(--gap);
              padding:1px; min-height:0; align-content:stretch; }
      #appsPages .page { grid-template-columns:repeat(var(--app-cols),minmax(0,1fr)); grid-template-rows:repeat(var(--app-rows),minmax(0,1fr)); }
      #shortcutPages .page { grid-template-columns:repeat(var(--sc-cols),minmax(0,1fr)); grid-template-rows:repeat(var(--sc-rows),minmax(0,1fr)); }
      .dots { display:flex; justify-content:flex-end; align-items:center; gap:6px; padding:0; min-width:0; }
      .dots:empty { display:none; }
      .dots i { width:6px; height:6px; border-radius:50%; background:#3a4270; }
      .dots i.on { background:var(--muted); }
      .pcount { display:inline; font-size:10px; color:var(--muted); margin-left:2px; font-variant-numeric:tabular-nums; white-space:nowrap; }
      .btn { background:var(--card); border:1px solid var(--line); border-radius:var(--radius); min-height:0; color:var(--fg);
             display:flex; flex-direction:column; align-items:center; justify-content:center; gap:calc(var(--u) * .8);
             padding:clamp(4px,var(--u),8px) clamp(3px,calc(var(--u) * .8),6px); cursor:pointer; position:relative; overflow:hidden; }
      .btn:active { background:#232a4a; }
      .btn img { width:var(--icon); height:var(--icon); border-radius:calc(var(--u) * 2.5); }
      .btn .fallback { width:var(--icon); height:var(--icon); border-radius:calc(var(--u) * 2.5); background:#2d3459;
                       display:flex; align-items:center; justify-content:center; font-size:calc(var(--icon) * .5); }
      .btn .symbol { font-size:calc(var(--label) * 1.55); font-weight:600; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; letter-spacing:1px; line-height:1.1; }
      .btn .label { font-size:var(--label); line-height:1.15; text-align:center; color:var(--fg); word-break:break-all; }
      .btn .state { font-size:calc(var(--label) - 2px); color:var(--muted); min-height:calc(var(--label) - 1px); white-space:nowrap; }
      .btn.placeholder { background:transparent; border:1px dashed var(--line); opacity:.35; pointer-events:none; }
      #shortcutPages .btn:not(.placeholder) { gap:calc(var(--sc-unit) * .22); padding:calc(var(--sc-unit) * .3); }
      #shortcutPages .symbol { flex:none; font-size:calc(var(--sc-unit) * 1.55); line-height:1.05; letter-spacing:0; }
      #shortcutPages .label { flex:none; width:100%; min-width:0; font-size:var(--sc-unit); line-height:1.15;
                              overflow-wrap:anywhere; word-break:break-all; }
      #shortcutPages .state { flex:none; min-height:0; max-width:100%; font-size:calc(var(--sc-unit) - 2px); line-height:1.05; }
      #shortcutPages .state:empty { display:none; }
      .btn .state.busy { color:var(--warn); } .btn .state.done { color:var(--ok); } .btn .state.fail { color:var(--err); }
      #pair { display:none; flex:1 1 auto; min-height:0; flex-direction:column; gap:12px; padding-top:8vh;
              overflow-y:auto; -webkit-overflow-scrolling:touch; }
      #pair.show { display:flex; }
      #pair input { font-size:24px; text-align:center; letter-spacing:8px; padding:12px; border-radius:12px; border:1px solid var(--line); background:var(--card); color:var(--fg); }
      #pair button, #pair input.dev { font-size:16px; padding:12px; border-radius:12px; border:1px solid var(--line); background:var(--card); color:var(--fg); }
      #pair .hint { color:var(--muted); font-size:13px; text-align:center; line-height:1.6; }
      .errtext { color:var(--err); font-size:13px; text-align:center; min-height:18px; }
      .empty { flex:0 0 100%; display:flex; flex-direction:column; align-items:center; justify-content:center;
               gap:8px; padding:24px 18px; text-align:center; color:var(--muted); font-size:15px; line-height:1.8; }
      .empty b { color:var(--fg); font-weight:600; font-size:16px; }
      .empty span { font-size:12px; opacity:.85; line-height:1.9; }
      @media (orientation: landscape) {
        /* 横屏：左侧竖轨（标题/时间/全屏/连接）| 应用 | 快捷操作。 */
        body {
          display:grid;
          grid-template-columns: var(--left-rail) minmax(0,1fr);
          grid-template-rows: 1fr;
          padding-left:calc(env(safe-area-inset-left) + 10px);
          padding-right:calc(env(safe-area-inset-right) + 12px);
        }
        header {
          grid-column:1; grid-row:1;
          flex-direction:column; align-items:flex-start; justify-content:flex-start;
          margin:0; padding:2px 10px 4px 0;
          width:auto; max-width:none; height:100%;
          border-right:1px solid var(--line);
        }
        /* 左轨窄，标题必须允许折行；覆盖基础的 nowrap，恢复「Mac / 应用快捷控制台」两行。 */
        h1 { font-size:clamp(10px, 1.4vw, 12px); line-height:1.45; letter-spacing:.02em; word-break:keep-all; white-space:normal; }
        /* 收起开关在左轨顶部；收起后整条左轨隐藏，只留左上角悬浮把手。 */
        #railToggle { display:block; flex:0 0 auto; align-self:stretch; border:1px solid var(--line); border-radius:8px;
                      background:var(--card); color:var(--muted); font:inherit; font-size:11px; line-height:1;
                      padding:5px 4px; margin-bottom:8px; cursor:pointer; white-space:nowrap; }
        #railToggle:active { background:#232a4a; }
        body.rail-collapsed { grid-template-columns:0 minmax(0,1fr); }
        body.rail-collapsed header { display:none; }
        body.rail-collapsed #railReveal { display:flex; }
        /* 收起态给左上角悬浮把手留出位置，避免压住应用区标题。 */
        body.rail-collapsed #appsZone .zone-head { padding-left:34px; }
        #clock { display:block; margin-top:12px; white-space:normal; }
        #clock .clock-date, #clock .clock-weekday { display:block; font-size:10px; line-height:1.5; font-weight:500; color:var(--muted); text-shadow:none; white-space:nowrap; }
        #clock .clock-time { display:block; margin-top:2px; font-size:16px; line-height:1.2; font-weight:700; color:var(--clock); text-shadow:0 0 10px var(--clock-glow); }
        /* 底部三件套顺序：刷新 → 全屏 → 连接状态。刷新紧挨全屏上方。 */
        #reload { margin-top:auto; align-self:stretch; text-align:center; font-size:11px; padding:6px 4px; }
        #reload::after { content:" 刷新"; }
        #fullscreen { margin-top:4px; align-self:stretch; text-align:center; font-size:11px; padding:6px 4px; }
        #fullscreen::after { content:" 全屏"; }
        #status { align-self:stretch; text-align:center; font-size:11px; padding:5px 4px; margin-top:4px; }
        #main {
          grid-column:2; grid-row:1;
          flex-direction:row;
          width:100%; max-width:none; margin:0;
          padding:0 0 0 var(--gap);
          padding-bottom:calc(env(safe-area-inset-bottom, 0px) + 2px);
        }
        #pair.show { grid-column:2; grid-row:1; }
        #appsZone { flex:1 1 auto; }
        #shortcutsZone { flex:0 0 var(--rail-w, 160px); border-top:0; border-left:1px solid var(--line); padding:0 0 0 var(--gap); }
        /* 标题与圆点都在顶部标题行，按钮区独占下方，不再为竖排标题留 26px 列。 */
        .zone-title { font-size:11px; letter-spacing:.18em; }
        #shortcutPages { flex:1 1 auto; height:auto; min-height:0; }
        #shortcutPages .page { grid-template-columns:repeat(2,minmax(0,1fr)); grid-template-rows:repeat(4,minmax(0,1fr)); }
        #shortcutPages .btn { width:auto; height:100%; max-width:100%; aspect-ratio:1; justify-self:center; align-self:center; }
      }
      @media (max-height: 360px) {
        :root { --u:3px; --gap:5px; --sc-cell:52px; --icon:32px; --label:11px; }
      }
      @media (orientation: landscape) and (max-width: 640px) {
        /* 极窄横屏：左轨再收窄，把宽度让给应用区。 */
        :root { --left-rail: 70px; }
        h1 { font-size:10px; line-height:1.35; }
        #clock { margin-top:8px; }
        #clock .clock-date, #clock .clock-weekday { font-size:9px; line-height:1.35; }
        #clock .clock-time { font-size:14px; }
        #fullscreen, #status { font-size:10px; padding:5px 3px; }
      }
    </style>
    </head>
    <body>
    <header>
      <button id="railToggle" type="button" aria-label="收起标题栏" title="收起标题栏">‹ 收起</button>
      <h1>Mac 应用快捷控制台</h1><span id="clock"></span>
      <button id="reload" type="button" aria-label="强制刷新面板" title="强制刷新面板">⟳</button>
      <button id="fullscreen" type="button" aria-label="进入全屏" title="进入全屏">⛶</button>
      <span id="status" role="button" tabindex="0" title="点击强制刷新面板">检测中…</span>
    </header>
    <button id="railReveal" type="button" aria-label="展开标题栏" title="展开标题栏">›</button>
    <div id="toast"></div>
    <div id="main">
      <section class="zone" id="appsZone">
        <div class="zone-head"><div class="zone-title">应用</div><div class="dots" id="appsDots"></div></div>
        <div class="pages" id="appsPages"></div>
      </section>
      <section class="zone" id="shortcutsZone">
        <div class="zone-head"><div class="zone-title">快捷操作</div><div class="dots" id="shortcutDots"></div></div>
        <div class="pages" id="shortcutPages"></div>
      </section>
    </div>
    <div id="pair">
      <div class="hint">输入 Mac 端菜单栏「生成配对码」显示的 6 位数字<br>有效时间 2 分钟，错误 3 次将作废</div>
      <input id="code" inputmode="numeric" pattern="[0-9]*" maxlength="6" placeholder="配对码">
      <input id="devname" class="dev" value="iPhone" placeholder="设备名称（可选）">
      <button id="pairBtn">配 对</button>
      <div class="errtext" id="pairErr"></div>
    </div>
    <script>
      const $ = s => document.querySelector(s);
      const appsZone=$('#appsZone'), shortcutsZone=$('#shortcutsZone');
      const appsPagesEl=$('#appsPages'), shortcutPagesEl=$('#shortcutPages');
      const appsDotsEl=$('#appsDots'), shortcutDotsEl=$('#shortcutDots');
      const mainEl=$('#main'), pairEl=$('#pair'), statusEl=$('#status'), toast=$('#toast');
      const railToggleEl=$('#railToggle'), railRevealEl=$('#railReveal'), reloadEl=$('#reload');
      let token=localStorage.getItem('deck_token');
      const deviceName=localStorage.getItem('deck_device')||'iPhone';
      if (location.search.includes('debug=1')) {
        setTimeout(updateDebug, 600);
        setTimeout(updateDebug, 1500);
      }

      (function(){
        const m=document.querySelector('meta[name="panel-version"]');
        const d=document.createElement('div');
        d.style.cssText='position:fixed;right:6px;top:calc(env(safe-area-inset-top, 0px) + 4px);font:9px ui-monospace;color:#555c85;z-index:50;pointer-events:none';
        d.textContent = (m?m.content:'?');
        document.body.appendChild(d);
      })();

      const debugMode = location.search.includes('debug=1');
      function updateDebug(){
        if(!debugMode) return;
        let el=document.getElementById('dbg');
        if(!el){ el=document.createElement('div'); el.id='dbg';
          el.style.cssText='position:fixed;left:8px;bottom:8px;background:#000a;color:#0f0;font:11px ui-monospace;padding:6px;border-radius:6px;white-space:pre;z-index:99;';
          document.body.appendChild(el);
        }
        const vv=window.visualViewport;
        el.innerHTML =
          'inner=' + window.innerHeight + ' vv=' + (vv?Math.round(vv.height):'-') +
          '<br>body=' + Math.round(document.body.getBoundingClientRect().height) +
          '<br>appsPages=' + Math.round(appsPagesEl.clientHeight) +
          ' scPages=' + Math.round(shortcutPagesEl.getBoundingClientRect().height) +
          '<br>pageBottom=' + Math.round(shortcutPagesEl.getBoundingClientRect().bottom);
      }

      const queues = new Map();   // id -> { items: [], running: false, el }
      const TIMEOUT = { shortcut: 2500, command: 4000, app: 12000 };
      const clockEl = $('#clock');
      const WEEKDAYS = ['星期日','星期一','星期二','星期三','星期四','星期五','星期六'];
      const pad2 = n => n < 10 ? '0' + n : '' + n;
      function tickClock(){
        const d = new Date();
        const date = d.getFullYear() + '/' + pad2(d.getMonth() + 1) + '/' + pad2(d.getDate());
        const weekday = WEEKDAYS[d.getDay()];
        const time = pad2(d.getHours()) + ':' + pad2(d.getMinutes()) + ':' + pad2(d.getSeconds());
        clockEl.innerHTML = '<span class="clock-date">' + date + '</span>' +
          '<span class="clock-weekday">' + weekday + '</span>' +
          '<span class="clock-time">' + time + '</span>';
      }
      tickClock();
      setInterval(tickClock, 1000);
      // 禁用双击缩放/双击选中（iOS Safari 与桌面浏览器行为一致）
      document.addEventListener('dblclick', e => e.preventDefault());
      document.addEventListener('gesturestart', e => e.preventDefault());
      document.addEventListener('dragstart', e => e.preventDefault());
      document.addEventListener('contextmenu', e => { if(!e.target.closest('input,textarea')) e.preventDefault(); });
      document.addEventListener('selectstart', e => { if(!e.target.closest('input,textarea')) e.preventDefault(); });
      let lastTapAt = 0;
      document.addEventListener('touchend', e => {
        const now = Date.now();
        if (now - lastTapAt < 300) { e.preventDefault(); }
        lastTapAt = now;
      }, { passive: false });

      function toastMsg(t,ms=2600){ toast.textContent=t; toast.classList.add('show'); clearTimeout(toast._t); toast._t=setTimeout(()=>toast.classList.remove('show'),ms); }
      function setStatus(t,cls){ statusEl.textContent=t; statusEl.className=cls||''; }
      const fullscreenBtn=$('#fullscreen');
      function fullscreenElement(){ return document.fullscreenElement || document.webkitFullscreenElement; }
      function updateFullscreen(){
        const active=!!fullscreenElement();
        fullscreenBtn.textContent=active?'退出':'⛶';
        fullscreenBtn.title=active?'退出全屏':'进入全屏';
        fullscreenBtn.setAttribute('aria-label',fullscreenBtn.title);
        scheduleLayout(80);
      }
      fullscreenBtn.addEventListener('click',async()=>{
        try {
          if(fullscreenElement()) {
            const exit=document.exitFullscreen || document.webkitExitFullscreen;
            if(!exit) throw new Error('unsupported');
            await exit.call(document);
          } else {
            const root=document.documentElement;
            const enter=root.requestFullscreen || root.webkitRequestFullscreen;
            if(!enter || document.fullscreenEnabled===false) throw new Error('unsupported');
            await enter.call(root);
          }
          updateFullscreen();
        } catch(e) {
          toastMsg('浏览器未允许全屏，请在浏览器菜单开启全屏或添加到主屏幕', 4500);
        }
      });
      document.addEventListener('fullscreenchange',updateFullscreen);
      document.addEventListener('webkitfullscreenchange',updateFullscreen);
      let refreshing=false;
      async function forceRefresh(){
        if(refreshing) return;
        refreshing=true;
        statusEl.classList.add('refreshing');
        statusEl.textContent='刷新中…';
        let version='';
        try{
          const res=await fetch('/api/panel-version',{cache:'no-store'});
          if(res.ok){ const data=await res.json(); version=(data&&data.version)||''; }
        }catch(e){}
        const url='/panel/?v='+encodeURIComponent(version||'0')+'&t='+Date.now();
        location.replace(url);
      }
      statusEl.addEventListener('click',forceRefresh);
      statusEl.addEventListener('keydown',e=>{ if(e.key==='Enter'||e.key===' '){ e.preventDefault(); forceRefresh(); } });

      /* 强制刷新按钮：复用与状态徽标相同的刷新逻辑。 */
      reloadEl.addEventListener('click',forceRefresh);

      /* 左轨收起/展开：状态写入 localStorage，刷新页面后保持。
         仅横屏有效；竖屏下开关与把手都由 CSS 隐藏。 */
      function setRailCollapsed(collapsed){
        document.body.classList.toggle('rail-collapsed',collapsed);
        try{ localStorage.setItem('deck.rail.collapsed',collapsed?'1':'0'); }catch(e){}
        // 左轨宽度变化会改变可用高度/宽度，重排一次布局。
        requestAnimationFrame(()=>{ if(typeof layoutNow==='function') layoutNow(); });
      }
      try{ if(localStorage.getItem('deck.rail.collapsed')==='1') setRailCollapsed(true); }catch(e){}
      railToggleEl.addEventListener('click',()=>setRailCollapsed(true));
      railRevealEl.addEventListener('click',()=>setRailCollapsed(false));
      function saveToken(t){ token=t; localStorage.setItem('deck_token',t); localStorage.setItem('deck_device',deviceName); }
      function escapeText(s){ const d=document.createElement('div'); d.textContent=s; return d.innerHTML; }

      async function api(path,opts={}){
        const headers=Object.assign({'X-Device-Token':token||''},opts.headers||{});
        const res=await fetch(path,Object.assign({},opts,{headers}));
        if(res.status===401&&token){ token=null; localStorage.removeItem('deck_token'); showPair(); throw new Error('凭证已失效'); }
        return res;
      }
      async function checkHealth(){
        try{ const res=await fetch('/api/health',{cache:'no-store'}); if(res.ok){ setStatus('已连接','ok'); return true; } }catch(e){}
        setStatus('Mac 未连接','err'); return false;
      }
      let lastButtonsKey='';
      function renderIfChanged(buttons){
        const key=JSON.stringify(buttons||[]);
        if(key===lastButtonsKey) return;
        lastButtonsKey=key;
        render(buttons);
      }

      async function loadButtons(){
        try{
          const res=await api('/api/buttons');
          if(!res.ok){ showPair(); return; }
          const data=await res.json();
          localStorage.setItem('deck_buttons',JSON.stringify(data.buttons));
          renderIfChanged(data.buttons);
        }catch(e){ const cached=localStorage.getItem('deck_buttons'); if(cached) renderIfChanged(JSON.parse(cached)); }
      }

      function chunk(list,n){ const out=[]; for(let i=0;i<list.length;i+=n) out.push(list.slice(i,i+n)); return out; }

      let renderedApps=[], renderedShortcuts=[];

      function clamp(n,a,b){ return Math.max(a, Math.min(b,n)); }
      function px(v){ const n=parseFloat(v); return Number.isFinite(n)?n:0; }
      function pageIndex(el){ return el&&el.clientWidth ? Math.round(el.scrollLeft/el.clientWidth) : 0; }
      function restorePage(el,idx){
        requestAnimationFrame(()=>{
          const max=Math.max(0,el.children.length-1);
          el.scrollLeft=Math.min(idx,max)*el.clientWidth;
        });
      }

      function render(buttons){
        buttons=buttons||[];
        renderedApps=buttons.filter(b=>b.kind==='app'||!b.kind);
        renderedShortcuts=buttons.filter(b=>b.kind==='shortcut'||b.kind==='command'||b.kind==='builtin');
        if(!token){ mainEl.classList.remove('show'); pairEl.classList.add('show'); return; }
        // 已配对：始终进入主界面（即使还没有按钮），否则会出现"配对成功却退回配对页"
        mainEl.classList.add('show');
        pairEl.classList.remove('show');

        if(!buttons.length){
          appsPagesEl.innerHTML=''; appsDotsEl.innerHTML='';
          shortcutPagesEl.innerHTML=''; shortcutDotsEl.innerHTML='';
          shortcutsZone.style.display='none';
          const tip=document.createElement('div');
          tip.className='empty';
          tip.innerHTML='<b>还没有按钮</b>'+
            '<span>请在 Mac 端「添加应用按钮」或「添加快捷操作」，<br>添加后面板会自动刷新。</span>';
          appsPagesEl.appendChild(tip);
          return;
        }
        layoutNow();
      }

      function layoutNow(){
        if(!token) return;
        const landscape=matchMedia('(orientation: landscape)').matches;
        const narrow=innerWidth<700;
        // 横屏固定每页 12 个应用；窄横屏 3×4，常规横屏 4×3。竖屏保持 2 列自适应。
        const appCols=landscape?(narrow?3:4):2;
        const scCols=landscape?2:4;
        const scRows=landscape?4:2;
        const rootStyle=document.documentElement.style;
        rootStyle.setProperty('--app-cols',String(appCols));
        rootStyle.setProperty('--sc-cols',String(scCols));
        rootStyle.setProperty('--sc-rows',String(scRows));
        shortcutsZone.style.display=renderedShortcuts.length?'':'none';

        if(landscape){
          // 快捷栏宽度由 4 行方形按钮反推；标题已横排到顶部，不再额外留竖排标题列宽。
          const gap0=px(getComputedStyle(mainEl).gap)||8;
          rootStyle.setProperty('--rail-w','160px');
          const pagesH=shortcutPagesEl.clientHeight||0;
          if(pagesH>0){
            const card=Math.max(52,(pagesH-gap0*(scRows-1))/scRows);
            const railW=card*scCols+gap0*(scCols+1)+gap0;
            rootStyle.setProperty('--rail-w',railW+'px');
          }
        }

        const h=appsPagesEl.clientHeight;
        const gap=px(getComputedStyle(mainEl).gap)||8;
        const vmin=Math.min(innerWidth,innerHeight);
        const minH=Math.max(64,Math.min(88,vmin*0.20));
        const measured=h>0?clamp(Math.floor((h+gap)/(minH+gap)),2,landscape?4:6):(landscape?3:4);
        const appRows=landscape?Math.round(12/appCols):measured;
        rootStyle.setProperty('--app-rows',String(appRows));

        const appPage=pageIndex(appsPagesEl);
        const scPage=pageIndex(shortcutPagesEl);
        renderZone(appsPagesEl,appsDotsEl,renderedApps,appCols,appRows,'app');
        if(renderedShortcuts.length){
          renderZone(shortcutPagesEl,shortcutDotsEl,renderedShortcuts,scCols,scRows,'shortcut');
        } else {
          shortcutPagesEl.innerHTML=''; shortcutDotsEl.innerHTML='';
        }
        restorePage(appsPagesEl,appPage);
        restorePage(shortcutPagesEl,scPage);
        fitShortcutContent();
      }

      // 同一快捷区共用字号，按最拥挤卡片缩放；上限与应用按钮字号一致，只缩小、不放大。
      function fitShortcutContent(){
        const cards=[...shortcutPagesEl.querySelectorAll('.btn:not(.placeholder)')];
        if(!cards.length || !cards[0].clientWidth || !cards[0].clientHeight) return;
        const root=document.documentElement.style;
        const size=Math.min(...cards.map(card=>Math.min(card.clientWidth,card.clientHeight)));
        const appLabel=document.querySelector('#appsPages .btn .label');
        const cap=appLabel?parseFloat(getComputedStyle(appLabel).fontSize):11;
        const maxUnit=Math.min(cap, size*.23);
        let lo=Math.min(2,maxUnit), hi=maxUnit, best=lo;
        function fits(unit){
          root.setProperty('--sc-unit',unit+'px');
          return cards.every(card=>{
            const box=card.getBoundingClientRect(), style=getComputedStyle(card);
            const top=box.top+px(style.borderTopWidth)+px(style.paddingTop);
            const bottom=box.bottom-px(style.borderBottomWidth)-px(style.paddingBottom);
            const left=box.left+px(style.borderLeftWidth)+px(style.paddingLeft);
            const right=box.right-px(style.borderRightWidth)-px(style.paddingRight);
            return [...card.children].filter(child=>getComputedStyle(child).display!=='none').every(child=>{
              const rect=child.getBoundingClientRect();
              return rect.top>=top-.5 && rect.bottom<=bottom+.5 && rect.left>=left-.5 && rect.right<=right+.5
                && child.scrollWidth<=child.clientWidth+1 && child.scrollHeight<=child.clientHeight+1;
            });
          });
        }
        for(let i=0;i<9;i++){
          const mid=(lo+hi)/2;
          if(fits(mid)){ best=mid; lo=mid; } else { hi=mid; }
        }
        root.setProperty('--sc-unit',best.toFixed(2)+'px');
      }

      function renderZone(pagesEl,dotsEl,items,cols,rows,kind){
        const prev=pageIndex(pagesEl);
        pagesEl.innerHTML=''; dotsEl.innerHTML='';
        if(!items.length){ return; }
        const per=cols*rows;
        const pages=chunk(items,per);
        pages.forEach(itemsInPage=>{
          const page=document.createElement('div');
          page.className='page';
          itemsInPage.forEach(b=>page.appendChild(makeButton(b,kind)));
          for(let i=itemsInPage.length;i<per;i++){
            const ph=document.createElement('div');
            ph.className='btn placeholder';
            page.appendChild(ph);
          }
          pagesEl.appendChild(page);
        });
        if(pages.length>1){
          const pcount=document.createElement('span');
          pcount.className='pcount';
          pcount.textContent='1/'+pages.length;
          const sync=idx=>{
            dots.forEach((d,i)=>d.className=i===idx?'on':'');
            pcount.textContent=(idx+1)+'/'+pages.length;
          };
          const dots=[...Array(pages.length)].map((_,i)=>{
            const d=document.createElement('i');
            if(i===0)d.className='on';
            d.style.cursor='pointer';
            d.addEventListener('click',()=>{
              pagesEl.scrollTo({left:i*pagesEl.clientWidth,behavior:'smooth'});
              sync(i);
            });
            dotsEl.appendChild(d); return d;
          });
          dotsEl.appendChild(pcount);
          pagesEl.onscroll=()=>{ const idx=Math.round(pagesEl.scrollLeft/pagesEl.clientWidth); sync(idx); };
        } else {
          pagesEl.onscroll=null;
        }
        restorePage(pagesEl,Math.min(prev,pages.length-1));
      }

      function makeButton(b,kind){
        const el=document.createElement('div');
        el.className='btn '+(kind==='shortcut'?'shortcut':'app');
        el.dataset.bid=b.id;
        if(kind==='shortcut'||kind==='command'||kind==='builtin'){
          el.innerHTML=`<div class="symbol">${escapeText(b.symbol||'—')}</div><div class="label">${escapeText(b.name)}</div><div class="state"></div>`;
        } else {
          el.innerHTML=(b.iconUrl?`<img src="${b.iconUrl}" alt="">`:'<div class="fallback">▸</div>')+
            `<div class="label">${escapeText(b.name)}${b.installed?'':'<br><span style="color:var(--warn);font-size:10px">应用缺失</span>'}</div><div class="state"></div>`;
        }
        el.addEventListener('click',()=>enqueue(b,el,kind));
        return el;
      }

      function setState(el,text,cls){ const s=el.querySelector('.state'); s.textContent=text; s.className='state '+(cls||''); if(el.classList.contains('shortcut')) fitShortcutContent(); }

      function queueOf(button, el){
        let q = queues.get(button.id);
        if (!q) { q = { items: [], running: false, el }; queues.set(button.id, q); }
        q.el = el;
        return q;
      }
      function queueLabel(q){ return q.items.length ? ' · 排队×' + q.items.length : ''; }

      function enqueue(button, el, kind){
        const q = queueOf(button, el);
        if (q.items.length >= 8) q.items.shift();   // 队列上限，丢最旧
        q.items.push(kind);
        if (!q.running) {
          setState(el, kind==='shortcut'?'正在发送…':(kind==='command'?'正在执行…':'正在打开…'), 'busy');
          runQueue(button.id);
        } else {
          setState(el, (q.running? '处理中' : '') + queueLabel(q), 'busy');
        }
      }

      async function runQueue(id){
        const q = queues.get(id);
        if (!q || q.running) return;
        q.running = true;
        while (q.items.length) {
          const kind = q.items.shift();
          const el = q.el;
          const baseText = kind==='shortcut'?'正在发送…':(kind==='command'?'正在执行…':'正在打开…');
          setState(el, baseText + queueLabel(q), 'busy');
          const controller = new AbortController();
          const timeoutMs = TIMEOUT[kind] || 20000;
          const timer = setTimeout(()=>controller.abort(), timeoutMs);
          try{
            const res = await api('/api/activate', {method:'POST', headers:{'Content-Type':'application/json'},
              body: JSON.stringify({buttonId: id}), signal: controller.signal});
            clearTimeout(timer);
            const data = await res.json().catch(()=>({}));
            if(res.ok&&data.status==='sent'){ setState(el, (kind==='command'||kind==='builtin')?'已执行':'已发送','done'); }
            else if(res.ok&&(data.status==='launched'||data.status==='activated')){ setState(el, data.status==='launched'?'已启动':'已切换','done'); }
            else if(res.ok&&data.status==='unconfirmed'){ setState(el,'未确认','busy'); }
            else if(res.status===401){ showPair(); }
            else { setState(el,'失败','fail'); toastMsg(data.message||'请求失败', 3000); }
          }catch(err){
            clearTimeout(timer);
            if (err.name === 'AbortError') { setState(el,'已超时，放弃','fail'); }
            else { setState(el,'失败','fail'); toastMsg(navigator.onLine?'Mac 未连接，请检查局域网':'网络不可用', 3000); }
          }
          if (q.items.length) setState(q.el, baseText + queueLabel(q), 'busy');
        }
        q.running = false;
        setTimeout(()=>{ const st=q.el&&q.el.querySelector('.state'); if(st && !q.running && !q.items.length && !st.classList.contains('busy')) { st.textContent=''; fitShortcutContent(); } }, 900);
        setTimeout(()=>{ const st=q.el&&q.el.querySelector('.state'); if(st && !q.running && !q.items.length && !st.classList.contains('fail')) { st.textContent=''; fitShortcutContent(); } }, 2600);
      }

      function anyRunning(){ return [...queues.values()].some(q=>q.running || q.items.length); }


      function showPair(){ pairEl.classList.add('show'); mainEl.classList.remove('show'); token&&localStorage.removeItem('deck_token'); token=null; }

      async function doPair(){
        const code=$('#code').value.trim(); const name=$('#devname').value.trim()||'iPhone';
        $('#pairErr').textContent='';
        if(!/^\\d{6}$/.test(code)){ $('#pairErr').textContent='请输入 6 位配对码'; return; }
        try{
          const res=await fetch('/api/pair',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({code,deviceName:name})});
          const data=await res.json();
          if(res.ok){ saveToken(data.token); $('#code').value=''; await loadButtons(); toastMsg('配对成功'); }
          else $('#pairErr').textContent=data.message||'配对失败';
        }catch(e){ $('#pairErr').textContent='无法连接 Mac，请确认同一局域网'; }
      }
      $('#pairBtn').addEventListener('click',doPair);
      $('#code').addEventListener('keydown',e=>{ if(e.key==='Enter') doPair(); });

      let layoutTimer=0;
      function scheduleLayout(delay=80){
        clearTimeout(layoutTimer);
        layoutTimer=setTimeout(()=>{ layoutNow(); },delay);
      }
      window.addEventListener('resize',()=>scheduleLayout(80));
      window.addEventListener('orientationchange',()=>scheduleLayout(200));
      if(window.visualViewport) window.visualViewport.addEventListener('resize',()=>scheduleLayout(120));
      if(document.fonts && document.fonts.ready) document.fonts.ready.then(()=>scheduleLayout(0));

      document.addEventListener('visibilitychange',()=>{ if(!document.hidden){ checkPanelVersion(); checkHealth().then(ok=>{ if(ok||token) loadButtons(); }); } });
      setInterval(()=>{ checkHealth().then(ok=>{ if(ok&&token&&!anyRunning()) loadButtons(); }); },2000);

      async function checkPanelVersion(){
        try{
          const res=await fetch('/api/panel-version',{cache:'no-store'});
          if(!res.ok) return;
          const data=await res.json();
          const mine=document.querySelector('meta[name="panel-version"]');
          const pageVer=mine?mine.content:'';
          if(data.version && data.version!==pageVer){
            location.replace('/panel/?v=' + encodeURIComponent(data.version));
          }
        }catch(e){}
      }

      (async function init(){
        checkPanelVersion();
        await checkHealth();
        if(token){ mainEl.classList.add('show'); await loadButtons(); } else { showPair(); }
      })();
    </script>
    </body>
    </html>
    """
}
