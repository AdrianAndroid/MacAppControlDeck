import Foundation

enum PanelHTML {
    static let version = "2026-11-20.1"
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
      :root { color-scheme: dark; --bg:#0f1220; --card:#1b2036; --line:#2a3152; --fg:#eef1ff; --muted:#8d96c5; --ok:#4ade80; --warn:#fbbf24; --err:#f87171; }
      * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
      body { touch-action: manipulation; -webkit-user-select: none; user-select: none; -webkit-touch-callout: none; }
      .btn, .page, .pages { touch-action: manipulation; }
      html, body { height: 100%; }
      body { margin:0; font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif; background:var(--bg); color:var(--fg);
             display:flex; flex-direction:column; height:100vh; height:-webkit-fill-available; height:100dvh;
             padding:calc(env(safe-area-inset-top) + 10px) calc(env(safe-area-inset-right) + 12px) 0 calc(env(safe-area-inset-left) + 12px); }
      header { display:flex; justify-content:space-between; align-items:center; margin-bottom:8px; flex:0 0 auto; }
      h1 { font-size:16px; margin:0; font-weight:600; }
      #status { font-size:12px; padding:4px 10px; border-radius:999px; background:var(--card); border:1px solid var(--line); color:var(--muted); white-space:nowrap; }
      #status.ok { color:var(--ok); border-color:#1f4d33; }
      #status.err { color:var(--err); border-color:#5c2733; }
      #toast { position:fixed; left:50%; transform:translateX(-50%); bottom:calc(env(safe-area-inset-bottom) + 20px);
               background:#262c4c; color:var(--fg); padding:10px 16px; border-radius:12px; font-size:14px; max-width:90vw;
               opacity:0; transition:opacity .25s; pointer-events:none; z-index:20; box-shadow:0 6px 24px rgba(0,0,0,.4); }
      #toast.show { opacity:1; }
      #main { display:none; flex-direction:column; flex:1 1 auto; min-height:0; gap:6px; overflow:hidden;
              padding-bottom:var(--quick-h, 0px); }
      #main.show { display:flex; }
      .zone { display:flex; flex-direction:column; min-height:0; }
      #appsZone { flex:1 1 auto; min-height:0; overflow:hidden; }
      #shortcutsZone { position:fixed; left:calc(env(safe-area-inset-left, 0px) + 12px); right:calc(env(safe-area-inset-right, 0px) + 12px);
                       bottom:0; z-index:5; background:var(--bg);
                       border-top:1px solid var(--line); padding-top:6px;
                       padding-bottom:calc(env(safe-area-inset-bottom, 0px) + 6px); }
      .zone-title { font-size:11px; color:var(--muted); margin:2px 0 4px; letter-spacing:.5px; }
      .pages { display:flex; overflow-x:auto; overflow-y:hidden; scroll-snap-type:x mandatory; scrollbar-width:none; -webkit-overflow-scrolling:touch; }
      #appsPages { flex:1 1 auto; min-height:0; }
      #shortcutPages { flex:0 0 auto; overflow-y:visible; }
      .pages::-webkit-scrollbar { display:none; }
      .page { flex:0 0 100%; width:100%; height:100%; scroll-snap-align:start; display:grid; gap:10px; padding:2px; align-content:start; }
      .dots { display:flex; justify-content:center; gap:6px; padding:4px 0 2px; min-height:14px; }
      .dots i { width:6px; height:6px; border-radius:50%; background:#3a4270; }
      .dots i.on { background:var(--muted); }
      .btn { background:var(--card); border:1px solid var(--line); border-radius:16px; min-height:76px; color:var(--fg);
             display:flex; flex-direction:column; align-items:center; justify-content:center; gap:4px; padding:8px 6px; cursor:pointer; position:relative; }
      .btn:active { background:#232a4a; }
      .btn img { width:44px; height:44px; border-radius:10px; }
      .btn .fallback { width:44px; height:44px; border-radius:10px; background:#2d3459; display:flex; align-items:center; justify-content:center; font-size:22px; }
      .btn .symbol { font-size:20px; font-weight:600; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; letter-spacing:1px; }
      .btn .label { font-size:12px; line-height:1.2; text-align:center; color:var(--fg); word-break:break-all; }
      .btn .state { font-size:10px; color:var(--muted); min-height:12px; }
      .btn.placeholder { background:transparent; border:1px dashed var(--line); opacity:.35; pointer-events:none; }
      .btn .state.busy { color:var(--warn); } .btn .state.done { color:var(--ok); } .btn .state.fail { color:var(--err); }
      #pair { display:none; flex-direction:column; gap:12px; padding-top:8vh; }
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
        body { padding-left:calc(env(safe-area-inset-left) + 16px); padding-right:calc(env(safe-area-inset-right) + 16px); }
        .btn { min-height:66px; }
      }
    </style>
    </head>
    <body>
    <header><h1>Mac 应用快捷控制台</h1><span id="status">检测中…</span></header>
    <div id="toast"></div>
    <div id="main">
      <section class="zone" id="appsZone">
        <div class="zone-title">应用</div>
        <div class="pages" id="appsPages"></div>
        <div class="dots" id="appsDots"></div>
      </section>
      <section class="zone" id="shortcutsZone">
        <div class="zone-title">快捷操作</div>
        <div class="pages" id="shortcutPages"></div>
        <div class="dots" id="shortcutDots"></div>
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
      let token=localStorage.getItem('deck_token');
      const deviceName=localStorage.getItem('deck_device')||'iPhone';
      if (location.search.includes('debug=1')) {
        setTimeout(updateDebug, 600);
        setTimeout(updateDebug, 1500);
      }

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
      const TIMEOUT = { shortcut: 2500, command: 4000, app: 20000 };
      // 禁用双击缩放/双击选中（iOS Safari 与桌面浏览器行为一致）
      document.addEventListener('dblclick', e => e.preventDefault());
      document.addEventListener('gesturestart', e => e.preventDefault());
      let lastTapAt = 0;
      document.addEventListener('touchend', e => {
        const now = Date.now();
        if (now - lastTapAt < 300) { e.preventDefault(); }
        lastTapAt = now;
      }, { passive: false });

      function toastMsg(t,ms=2600){ toast.textContent=t; toast.classList.add('show'); clearTimeout(toast._t); toast._t=setTimeout(()=>toast.classList.remove('show'),ms); }
      function setStatus(t,cls){ statusEl.textContent=t; statusEl.className=cls||''; }
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
      async function loadButtons(){
        try{
          const res=await api('/api/buttons');
          if(!res.ok){ showPair(); return; }
          const data=await res.json();
          localStorage.setItem('deck_buttons',JSON.stringify(data.buttons));
          render(data.buttons);
        }catch(e){ const cached=localStorage.getItem('deck_buttons'); if(cached) render(JSON.parse(cached)); }
      }

      function chunk(list,n){ const out=[]; for(let i=0;i<list.length;i+=n) out.push(list.slice(i,i+n)); return out; }

      function render(buttons){
        buttons=buttons||[];
        const apps=buttons.filter(b=>b.kind==='app'||!b.kind);
        const shortcuts=buttons.filter(b=>b.kind==='shortcut'||b.kind==='command');
        if(!token){ mainEl.classList.remove('show'); pairEl.classList.add('show'); return; }
        // 已配对：始终进入主界面（即使还没有按钮），否则会出现"配对成功却退回配对页"
        mainEl.classList.add('show');
        pairEl.classList.remove('show');

        if(!buttons.length){
          appsPagesEl.innerHTML=''; appsDotsEl.innerHTML='';
          shortcutPagesEl.innerHTML=''; shortcutDotsEl.innerHTML='';
          shortcutsZone.style.display='none';
          document.documentElement.style.setProperty('--quick-h','0px');
          const tip=document.createElement('div');
          tip.className='empty';
          tip.innerHTML='<b>还没有按钮</b>'+
            '<span>请在 Mac 端「添加应用按钮」或「添加快捷操作」，<br>添加后面板会自动刷新。</span>';
          appsPagesEl.appendChild(tip);
          return;
        }

        const landscape=matchMedia('(orientation: landscape)').matches;
        const appCols=landscape?4:2;
        const scCols=landscape?6:4;
        const scRows=3;   // 固定 3 排，不足用空白占位补齐，贴底显示

        // 快捷操作区高度固定为行数 × 行高，避免最后一行被截断
        const scCell=72, scGap=10;
        shortcutPagesEl.style.height=(scRows*scCell+(scRows-1)*scGap+10)+'px';

        const renderAll=()=>{
          const h=appsPagesEl.clientHeight;
          const measured=h>0 ? Math.max(2, Math.min(6, Math.floor((h+10)/102))) : (landscape?3:4);
          renderZone(appsPagesEl,appsDotsEl,apps,appCols,measured,'app');
        };
        renderAll();
        if(shortcuts.length){
          shortcutsZone.style.display='flex';
          renderZone(shortcutPagesEl,shortcutDotsEl,shortcuts,scCols,scRows,'shortcut');
        } else {
          shortcutsZone.style.display='none';
        }
        const syncFooter=()=>{
          const h = shortcuts.length ? Math.ceil(shortcutsZone.getBoundingClientRect().height) : 0;
          document.documentElement.style.setProperty('--quick-h', (h + 6) + 'px');
          renderAll();
        };
        syncFooter();
        requestAnimationFrame(()=>setTimeout(syncFooter, 60));
        window.addEventListener('resize', $=>setTimeout(syncFooter, 80));
        window.addEventListener('orientationchange', ()=>setTimeout(syncFooter, 200));
      }

      function renderZone(pagesEl,dotsEl,items,cols,rows,kind){
        pagesEl.innerHTML=''; dotsEl.innerHTML='';
        if(!items.length){ return; }
        const per=cols*rows;
        const pages=chunk(items,per);
        pages.forEach(itemsInPage=>{
          const page=document.createElement('div');
          page.className='page';
          page.style.gridTemplateColumns='repeat('+cols+',1fr)';
          page.style.gridAutoRows= kind==='shortcut' ? '72px' : '92px';
          itemsInPage.forEach(b=>page.appendChild(makeButton(b,kind)));
          if (kind==='shortcut') {
            // 空白占位卡片：补满整页（固定 3 排的视觉）
            for (let i=itemsInPage.length; i<per; i++) {
              const ph=document.createElement('div');
              ph.className='btn placeholder';
              page.appendChild(ph);
            }
          }
          pagesEl.appendChild(page);
        });
        if(pages.length>1){
          const dots=[...Array(pages.length)].map((_,i)=>{ const d=document.createElement('i'); if(i===0)d.className='on'; dotsEl.appendChild(d); return d; });
          pagesEl.onscroll=()=>{ const idx=Math.round(pagesEl.scrollLeft/pagesEl.clientWidth); dots.forEach((d,i)=>d.className=i===idx?'on':''); };
        } else {
          pagesEl.onscroll=null;
        }
      }

      function makeButton(b,kind){
        const el=document.createElement('div');
        el.className='btn '+(kind==='shortcut'?'shortcut':'app');
        el.dataset.bid=b.id;
        if(kind==='shortcut'||kind==='command'){
          el.innerHTML=`<div class="symbol">${escapeText(b.symbol||'—')}</div><div class="label">${escapeText(b.name)}</div><div class="state"></div>`;
        } else {
          el.innerHTML=(b.iconUrl?`<img src="${b.iconUrl}" alt="">`:'<div class="fallback">▸</div>')+
            `<div class="label">${escapeText(b.name)}${b.installed?'':'<br><span style="color:var(--warn);font-size:10px">应用缺失</span>'}</div><div class="state"></div>`;
        }
        el.addEventListener('click',()=>enqueue(b,el,kind));
        return el;
      }

      function setState(el,text,cls){ const s=el.querySelector('.state'); s.textContent=text; s.className='state '+(cls||''); }

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
            if(res.ok&&data.status==='sent'){ setState(el, kind==='command'?'已执行':'已发送','done'); }
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
        setTimeout(()=>{ const st=q.el&&q.el.querySelector('.state'); if(st && !q.running && !q.items.length && !st.classList.contains('busy')) st.textContent=''; }, 900);
        setTimeout(()=>{ const st=q.el&&q.el.querySelector('.state'); if(st && !q.running && !q.items.length && !st.classList.contains('fail')) st.textContent=''; }, 2600);
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

      let lastOrientation=matchMedia('(orientation: landscape)').matches;
      function onResize(){
        const now=matchMedia('(orientation: landscape)').matches;
        if(now!==lastOrientation){ lastOrientation=now; const cached=localStorage.getItem('deck_buttons'); if(cached) render(JSON.parse(cached)); }
      }
      window.addEventListener('resize',onResize);
      window.addEventListener('orientationchange',()=>setTimeout(onResize,200));

      document.addEventListener('visibilitychange',()=>{ if(!document.hidden){ checkPanelVersion(); checkHealth().then(ok=>{ if(ok||token) loadButtons(); }); } });
      setInterval(()=>{ checkHealth().then(ok=>{ if(ok&&token&&!anyRunning()) loadButtons(); }); },5000);

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
