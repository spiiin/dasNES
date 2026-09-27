"""Local browser checks. Install playwright + pillow; pass --browser edge/firefox."""
import argparse
from io import BytesIO
from pathlib import Path
import re
from PIL import Image
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--url', default='http://127.0.0.1:8086')
parser.add_argument('--browser', choices=['edge', 'firefox'], default='edge')
parser.add_argument('--roms', type=Path)
parser.add_argument('--output', type=Path, default=Path('work/web-checks'))
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)

def wait_frames(page, count):
    page.wait_for_function("n => [...document.querySelector('#output').textContent.matchAll(/frames (\\d+)/g)].some(m => +m[1] >= n)", arg=count, timeout=60000)

def log(page):
    return page.locator('#output').text_content()

def open_game(browser, rom=None):
    page = browser.new_page(viewport={'width':1000,'height':1100})
    page.goto(args.url)
    page.wait_for_function("!document.querySelector('#start').disabled", timeout=120000)
    if rom:
        page.locator('#rom').set_input_files(str(rom))
        page.wait_for_function("document.querySelector('#status').textContent === 'ROM готов'")
    page.locator('#start').click()
    wait_frames(page, 120)
    assert 'wasm32 AOT, interpreter fallback disabled; standalone, no compiler' in log(page), log(page)
    assert page.evaluate("['/app', '/daslib', '/dassdl3'].every(p => !runtime.FS.analyzePath(p).exists)")
    return page

with sync_playwright() as pw:
    browser = pw.firefox.launch(headless=True) if args.browser == 'firefox' else pw.chromium.launch(channel='msedge', headless=True)
    page = open_game(browser)
    image = Image.open(BytesIO(page.locator('canvas').screenshot())).convert('RGB')
    assert len(image.getcolors(image.width * image.height)) > 1
    page.locator('#pause').click()
    page.wait_for_timeout(250)
    before = log(page)
    page.wait_for_timeout(1300)
    assert log(page) == before
    page.locator('#pause').click()
    page.wait_for_timeout(1500)
    assert log(page) != before
    page.locator('#stop').click()
    page.wait_for_function("document.querySelector('#status').textContent === 'Остановлено'")
    assert log(page).count('Session released') == 1
    page.locator('#restart').click()
    wait_frames(page, 120)
    assert log(page).count('wasm32 AOT') == 1
    page.locator('#stop').click()
    page.wait_for_function("document.querySelector('#status').textContent === 'Остановлено'")
    page.close()
    print(args.browser, 'demo, pause/resume, Stop/Restart PASS', flush=True)

    if args.roms:
        for rom in sorted(args.roms.glob('*.nes')):
            page = open_game(browser, rom)
            wait_frames(page, 180)
            page.keyboard.down('Enter'); page.wait_for_timeout(65); page.keyboard.up('Enter')
            if rom.name.startswith('Super Mario Bros. (W)'):
                page.evaluate("""() => {
                  window.probe={peak:0,calls:0,context:runtime.SDL3.audioContext};
                  const node=runtime.SDL3.audio_playback.scriptProcessorNode, original=node.onaudioprocess;
                  node.onaudioprocess=function(e){original.call(this,e);for(const x of e.outputBuffer.getChannelData(0))probe.peak=Math.max(probe.peak,Math.abs(x));probe.calls++;};
                }""")
                page.keyboard.down('ArrowRight'); page.keyboard.down('z')
                page.wait_for_function("probe.peak > 0.01 && probe.calls > 2 && probe.context.state === 'running'", timeout=15000)
                page.keyboard.up('z'); page.keyboard.up('ArrowRight')
            wait_frames(page, 300)
            fps = [float(x) for x in re.findall(r'FPS ([\d.]+);', log(page))]
            assert max(fps[-3:]) > 45, (rom.name, fps)
            assert page.locator('#status').inner_text() == 'Игра', log(page)
            image = Image.open(BytesIO(page.locator('canvas').screenshot())).convert('RGB')
            assert len(image.getcolors(image.width * image.height)) > 1, rom.name
            page.screenshot(path=str(args.output / (args.browser + '-' + rom.stem + '.png')))
            page.locator('#stop').click()
            page.wait_for_function("document.querySelector('#status').textContent === 'Остановлено'")
            if rom.name.startswith('Super Mario Bros. (W)'):
                page.wait_for_function("probe.context.state === 'closed'")
            assert log(page).count('Session released') == 1
            print(args.browser, rom.name, 'PASS', 'FPS', fps[-1], flush=True)
            page.close()

    page = browser.new_page()
    page.goto(args.url); page.wait_for_function("!document.querySelector('#start').disabled", timeout=120000)
    page.locator('#rom').set_input_files({'name':'broken.nes','mimeType':'application/octet-stream','buffer':b'bad'})
    page.wait_for_function("document.querySelector('#status').textContent.includes('извлечённый')")
    bad = b'NES\x1a' + bytes([1, 0, 240, 0]) + bytes(8) + bytes(16384)
    page.locator('#rom').set_input_files({'name':'unsupported.nes','mimeType':'application/octet-stream','buffer':bad})
    page.wait_for_function("document.querySelector('#status').textContent === 'ROM готов'")
    page.locator('#start').click()
    page.wait_for_function("document.querySelector('#status').textContent.startsWith('Ошибка')", timeout=30000)
    assert 'received mapper 15' in log(page), log(page)
    assert log(page).count('Session released') == 1
    print(args.browser, 'invalid ROM and unsupported mapper PASS', flush=True)
    browser.close()
