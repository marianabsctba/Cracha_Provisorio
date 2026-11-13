// Joga como uma pessoa: clica em Começar, escolhe o crachá e confere se a página responde.
import { spawn, execSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
const url = process.argv[2];
const porta = 9400 + Math.floor(Math.random() * 500);
const perfil = 'D:/Temp/cracha/cdp/perfil' + Date.now();
const matar = () => { try { execSync(`powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \\"Name='msedge.exe'\\" | Where-Object { $_.CommandLine -like '*cracha/cdp/perfil*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"`, { stdio: 'ignore' }); } catch {} };
const p = spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', ['--headless=new', `--remote-debugging-port=${porta}`, `--user-data-dir=${perfil}`, '--enable-gpu', '--use-angle=d3d11', '--ignore-gpu-blocklist', '--window-size=1280,720', 'about:blank']);
const esperar = ms => new Promise(r => setTimeout(r, ms));
await esperar(2500);
const alvos = await (await fetch(`http://127.0.0.1:${porta}/json`)).json();
const ws = new WebSocket(alvos.find(a => a.type === 'page').webSocketDebuggerUrl);
let id = 0; const pend = {};
const env = (method, params = {}) => new Promise(r => { const i = ++id; pend[i] = r; ws.send(JSON.stringify({ id: i, method, params })); });
ws.onmessage = ev => { const m = JSON.parse(ev.data); if (m.id && pend[m.id]) { pend[m.id](m.result); delete pend[m.id]; } };
await new Promise(r => ws.onopen = r);
await env('Page.enable');
await env('Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
await env('Page.navigate', { url });
await esperar(12000);
const clique = async (x, y) => { for (const type of ['mousePressed', 'mouseReleased']) await env('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 }); };
const responde = async (rotulo) => {
  const r = await Promise.race([env('Runtime.evaluate', { expression: 'new Promise(r => requestAnimationFrame(() => requestAnimationFrame(() => r("ok"))))', awaitPromise: true }), esperar(8000).then(() => null)]);
  console.log(rotulo, r ? 'RESPONDE' : 'TRAVADO');
  return !!r;
};
await responde('menu:');
await clique(292, 462); await esperar(1500);
{ const shot = await env('Page.captureScreenshot', { format: 'png' }); writeFileSync('D:/Temp/cracha/web_escolha.png', Buffer.from(shot.data, 'base64')); }
const cx = Number(process.argv[3] || 372), cy = Number(process.argv[4] || 378);
await clique(cx, cy); await esperar(4000);
const ok = await responde('dia 1:');
if (ok) {
  const shot = await env('Page.captureScreenshot', { format: 'png' });
  writeFileSync('D:/Temp/cracha/web_dia1.png', Buffer.from(shot.data, 'base64'));
}
matar(); process.exit(0);
