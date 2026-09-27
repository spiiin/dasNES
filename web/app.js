"use strict";
const $ = id => document.getElementById(id);
let runtime, romBytes, running = false, ended = false, paused = false, restartPending = false;
let userPaused = false, muted = false;
function log(text) {
  const line = String(text);
  const match = line.match(/^FPS ([\d.]+); frames (\d+)/);
  if (match) { $('fps').textContent = Number(match[1]).toFixed(1) + ' FPS'; }
  $('output').textContent = ($('output').textContent + line + '\n').slice(-16000);
}
function failed(error) {
  log(error); $('status').textContent = 'Ошибка — подробности в журнале';
  $('start').disabled = true; $('stop').disabled = !running; $('restart').disabled = false;
}
function wireCanvas() {
  $('canvas').addEventListener('contextmenu', event => event.preventDefault());
  $('canvas').addEventListener('keydown', event => {
    if (['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Space','Enter'].includes(event.code)) event.preventDefault();
  });
}
async function prepare() {
  $('start').disabled = true; $('restart').disabled = true;
  $('status').textContent = 'Загрузка эмулятора…';
  runtime = await createDasNES({canvas:$('canvas'),print:log,printErr:log,onAbort:failed,
    onSessionEnd(code) {
      running = false; ended = true; paused = false;
      $('status').textContent = code ? 'Ошибка — подробности в журнале' : 'Остановлено';
      $('pause').disabled = true; $('stop').disabled = true; $('sound').disabled = true;
      $('restart').disabled = false; $('rom').disabled = false; $('zapper').disabled = false;
      if (restartPending) { restartPending = false; restart(); }
    }
  });
  ended = false; $('status').textContent = 'Готово'; $('start').disabled = false;
  wireCanvas();
}
function start() {
  if (!runtime || running || ended) return;
  const bytes = romBytes || runtime.FS.readFile('/demo.nes');
  runtime.FS.mkdirTree('/roms'); runtime.FS.writeFile('/roms/game.nes',bytes);
  runtime.ENV.DASNES_ZAPPER = $('zapper').checked ? '1' : '0';
  running = true; paused = false; userPaused = false;
  $('start').disabled = true; $('rom').disabled = true; $('zapper').disabled = true; $('pause').disabled = false;
  $('stop').disabled = false; $('restart').disabled = false; $('sound').disabled = false;
  $('status').textContent = 'Игра'; $('canvas').focus();
  try { runtime.callMain([]); }
  catch (error) { if (error !== 'unwind') failed(error); }
  updateAudio();
}
async function updateAudio() {
  const context = runtime?.SDL3?.audioContext;
  if (!context || context.state === 'closed') return;
  try {
    if (paused || muted) await context.suspend(); else await context.resume();
    $('sound').textContent = muted ? 'Включить звук' : context.state === 'running' ? 'Выключить звук' : 'Включить звук';
  } catch (error) { log('Аудио: ' + error); }
}
function updatePause() {
  if (!running) return;
  paused = userPaused || document.hidden;
  runtime._web_pause(paused ? 1 : 0);
  $('pause').textContent = userPaused ? 'Продолжить' : 'Пауза';
  $('status').textContent = paused ? 'Пауза' : 'Игра';
  updateAudio();
}
async function restart() {
  if (running) { restartPending = true; runtime._web_stop(); return; }
  const oldCanvas = $('canvas'); oldCanvas.replaceWith(oldCanvas.cloneNode(false));
  runtime = null; $('output').textContent = ''; $('fps').textContent = '— FPS';
  try { await prepare(); start(); } catch (error) { failed(error); }
}
$('rom').onchange = async () => {
  const file = $('rom').files[0]; if (!file) return;
  if (file.size > 16 * 1024 * 1024) { $('status').textContent = 'ROM больше 16 MiB'; return; }
  const bytes = new Uint8Array(await file.arrayBuffer());
  if (bytes.length < 16 || bytes[0] !== 78 || bytes[1] !== 69 || bytes[2] !== 83 || bytes[3] !== 26) {
    $('status').textContent = 'Нужен извлечённый iNES .nes файл'; return;
  }
  romBytes = bytes; $('filename').textContent = file.name;
  $('zapper').checked = /duck hunt/i.test(file.name);
  if (runtime && !ended) { $('status').textContent = 'ROM готов'; $('start').disabled = false; }
};
$('start').onclick = start;
$('stop').onclick = () => { if (running) runtime._web_stop(); };
$('restart').onclick = restart;
$('pause').onclick = () => { userPaused = !userPaused; updatePause(); if (!paused) $('canvas').focus(); };
$('sound').onclick = () => { if (muted || runtime?.SDL3?.audioContext?.state !== 'suspended') muted = !muted; updateAudio(); $('canvas').focus(); };
document.addEventListener('visibilitychange',updatePause);
prepare().catch(failed);
