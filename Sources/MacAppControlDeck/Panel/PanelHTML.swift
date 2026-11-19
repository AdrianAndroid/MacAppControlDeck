import Foundation

enum PanelHTML {
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
    <title>Mac 应用快捷控制台</title>
    <link rel="apple-touch-icon" href="/apple-touch-icon.png">
    <style>
      :root { color-scheme: dark; --bg:#0f1220; --card:#1b2036; --line:#2a3152; --fg:#eef1ff; --muted:#8d96c5; --ok:#4ade80; --warn:#fbbf24; --err:#f87171; }
      * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
      body { margin:0; font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif; background:var(--bg); color:var(--fg);
             padding:calc(env(safe-area-inset-top) + 12px) calc(env(safe-area-inset-right) + 14px) calc(env(safe-area-inset-bottom) + 18px) calc(env(safe-area-inset-left) + 14px); }
      header { display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; }
      h1 { font-size:17px; margin:0; font-weight:600; }
      #status { font-size:12px; padding:4px 10px; border-radius:999px; background:var(--card); border:1px solid var(--line); color:var(--muted); white-space:nowrap; }
      #status.ok { color:var(--ok); border-color:#1f4d33; }
      #status.err { color:var(--err); border-color:#5c2733; }
      #toast { position:fixed; left:50%; transform:translateX(-50%); bottom:calc(env(safe-area-inset-bottom) + 24px);
               background:#262c4c; color:var(--fg); padding:10px 16px; border-radius:12px; font-size:14px; max-width:90vw;
               opacity:0; transition:opacity .25s; pointer-events:none; z-index:10; box-shadow:0 6px 24px rgba(0,0,0,.4); }
      #toast.show { opacity:1; }
      #grid { display:grid; grid-template-columns:repeat(2,1fr); gap:12px; }
      @media (min-width: 700px) { #grid { grid-template-columns:repeat(4,1fr); } }
      .btn { background:var(--card); border:1px solid var(--line); border-radius:16px; min-height:88px; color:var(--fg);
             display:flex; flex-direction:column; align-items:center; justify-content:center; gap:6px; padding:10px 6px; cursor:pointer; }
      .btn:active { background:#232a4a; }
      .btn img { width:52px; height:52px; border-radius:12px; }
      .btn .fallback { width:52px; height:52px; border-radius:12px; background:#2d3459; display:flex; align-items:center; justify-content:center; font-size:26px; }
      .btn .label { font-size:13px; line-height:1.2; text-align:center; color:var(--fg); word-break:break-all; }
      .btn .state { font-size:11px; color:var(--muted); min-height:14px; }
      .btn .state.busy { color:var(--warn); } .btn .state.done { color:var(--ok); } .btn .state.fail { color:var(--err); }
      #pair { display:none; flex-direction:column; gap:12px; padding-top:8vh; }
      #pair.show { display:flex; }
      #pair input { font-size:24px; text-align:center; letter-spacing:8px; padding:12px; border-radius:12px; border:1px solid var(--line); background:var(--card); color:var(--fg); }
      #pair button, #pair input.dev { font-size:16px; padding:12px; border-radius:12px; border:1px solid var(--line); background:var(--card); color:var(--fg); }
      #pair .hint { color:var(--muted); font-size:13px; text-align:center; line-height:1.6; }
      .errtext { color:var(--err); font-size:13px; text-align:center; min-height:18px; }
    </style>
    </head>
    <body>
    <header><h1>Mac 应用快捷控制台</h1><span id="status">检测中…</span></header>
    <div id="toast"></div>
    <div id="main" style="display:none"><div id="grid"></div></div>
    <div id="pair">
      <div class="hint">输入 Mac 端菜单栏「生成配对码」显示的 6 位数字<br>有效时间 2 分钟，错误 3 次将作废</div>
      <input id="code" inputmode="numeric" pattern="[0-9]*" maxlength="6" placeholder="配对码">
      <input id="devname" class="dev" value="iPhone" placeholder="设备名称（可选）">
      <button id="pairBtn">配 对</button>
      <div class="errtext" id="pairErr"></div>
    </div>
    <script>
      const $ = s => document.querySelector(s);
      const grid = $('#grid'), mainEl = $('#main'), pairEl = $('#pair'), statusEl = $('#status'), toast = $('#toast');
      let token = localStorage.getItem('deck_token');
      const deviceName = localStorage.getItem('deck_device') || 'iPhone';
      const inflight = new Set();

      function toastMsg(t, ms=2600){ toast.textContent=t; toast.classList.add('show'); clearTimeout(toast._t); toast._t=setTimeout(()=>toast.classList.remove('show'), ms); }
      function setStatus(text, cls){ statusEl.textContent=text; statusEl.className=cls||''; }
      function saveToken(t){ token=t; localStorage.setItem('deck_token', t); localStorage.setItem('deck_device', deviceName); }

      async function api(path, opts={}){
        const headers = Object.assign({'X-Device-Token': token||''}, opts.headers||{});
        const res = await fetch(path, Object.assign({}, opts, {headers}));
        if (res.status === 401 && token) { token=null; localStorage.removeItem('deck_token'); showPair(); throw new Error('凭证已失效'); }
        return res;
      }

      async function checkHealth(){
        try {
          const res = await fetch('/api/health', {cache:'no-store'});
          if (res.ok) { setStatus('已连接','ok'); return true; }
        } catch(e) {}
        setStatus('Mac 未连接','err'); return false;
      }

      async function loadButtons(){
        try {
          const res = await api('/api/buttons');
          if(!res.ok){ showPair(); return; }
          const data = await res.json();
          localStorage.setItem('deck_buttons', JSON.stringify(data.buttons));
          render(data.buttons);
        } catch(e) { if (localStorage.getItem('deck_buttons')) render(JSON.parse(localStorage.getItem('deck_buttons'))); }
      }

      function render(buttons){
        mainEl.style.display = buttons && buttons.length ? 'block' : 'none';
        pairEl.classList.toggle('show', !(token && buttons && buttons.length));
        if (!token) { pairEl.classList.add('show'); return; }
        grid.innerHTML = '';
        if (!buttons || !buttons.length) { grid.innerHTML = '<div style="grid-column:1/-1;color:var(--muted);text-align:center;padding:32px 0">Mac 端还没有按钮，请在 Mac 应用里添加</div>'; return; }
        for (const b of buttons) {
          const el = document.createElement('div');
          el.className='btn'; el.dataset.bid=b.id;
          el.innerHTML = (b.iconUrl ? `<img src="${b.iconUrl}" alt="">` : '<div class="fallback">▸</div>') +
            `<div class="label">${escapeText(b.name)}${b.installed?'':'<br><span style="color:var(--warn);font-size:11px">应用缺失</span>'}</div><div class="state"></div>`;
          el.addEventListener('click', ()=>activate(b, el));
          grid.appendChild(el);
        }
      }

      function escapeText(s){ const d=document.createElement('div'); d.textContent=s; return d.innerHTML; }

      function setState(el, text, cls){ const s=el.querySelector('.state'); s.textContent=text; s.className='state '+(cls||''); }

      async function activate(button, el){
        if (inflight.has(button.id)) return;
        inflight.add(button.id);
        setState(el, '正在打开…','busy');
        try {
          const res = await api('/api/activate', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({buttonId: button.id})});
          const data = await res.json().catch(()=>({}));
          if (res.ok && (data.status==='launched'||data.status==='activated')) { setState(el, data.status==='launched'?'已启动':'已切换','done'); toastMsg(data.message); }
          else if (res.ok && data.status==='unconfirmed') { setState(el, '未确认','busy'); toastMsg(data.message || '已发送激活请求，但未能确认窗口状态', 5000); }
          else if (res.status===401) { showPair(); toastMsg('请重新配对'); }
          else { setState(el, '失败','fail'); toastMsg(data.message || '请求失败'); }
        } catch(e) {
          setState(el, '失败','fail');
          toastMsg(navigator.onLine ? 'Mac 未连接，请检查局域网' : '网络不可用');
        }
        setTimeout(()=>inflight.delete(button.id), 1200);
        setTimeout(()=>{ const s=el.querySelector('.state'); if(!s.classList.contains('busy')) s.textContent=''; }, 3500);
      }

      function showPair(){
        pairEl.classList.add('show'); mainEl.style.display='none';
        token && localStorage.removeItem('deck_token'); token=null;
      }

      async function doPair(){
        const code = $('#code').value.trim(); const name = $('#devname').value.trim() || 'iPhone';
        $('#pairErr').textContent='';
        if (!/\\d{6}/.test(code)) { $('#pairErr').textContent='请输入 6 位配对码'; return; }
        try {
          const res = await fetch('/api/pair', {method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({code, deviceName: name})});
          const data = await res.json();
          if (res.ok) { saveToken(data.token); $('#code').value=''; await loadButtons(); toastMsg('配对成功'); }
          else $('#pairErr').textContent = data.message || '配对失败';
        } catch(e) { $('#pairErr').textContent = '无法连接 Mac，请确认同一局域网'; }
      }
      $('#pairBtn').addEventListener('click', doPair);
      $('#code').addEventListener('keydown', e=>{ if(e.key==='Enter') doPair(); });

      document.addEventListener('visibilitychange', ()=>{ if(!document.hidden){ checkHealth().then(ok=>{ if(ok||token) loadButtons(); }); } });
      setInterval(()=>{ checkHealth().then(ok=>{ if(ok && token && !inflight.size) loadButtons(); }); }, 5000);

      (async function init(){
        await checkHealth();
        if (token) { mainEl.style.display='block'; await loadButtons(); } else { showPair(); }
      })();
    </script>
    </body>
    </html>
    """
}
