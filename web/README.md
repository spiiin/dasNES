# dasNES Web

Браузерный frontend использует общее daScript-ядро (`state`, `mapper`, `core`,
`cpu`, `ppu`, `apu`, `pacing`). SDL3 Renderer выводит кадры через WebGL, SDL
AudioStream передаёт mono S16LE 48 kHz в Web Audio. ROM остаётся в локальной
памяти браузера. Коммерческие ROM не входят в сборку; включено только `demo.nes`.

## Сборка и запуск

Нужны Emscripten **5.0.3**, CMake, Ninja, Python и собранный Web-профиль соседнего
dasSDL3. В обвязке dasSDL3 должны присутствовать `web/sdl3_web_aot.h`, поддержка
`aotRequire`, `SDL_Scancode` и `SDL_SetTextureScaleMode` в Web snapshots.
Профиль зависит от закреплённых версий SDL 3.4.16 и daScript в dasSDL3.

```powershell
cd C:\src\dasNES
.\build-web.ps1
python -m http.server 8080 --bind 127.0.0.1 --directory build/web/site
```

Открыть `http://127.0.0.1:8080/`, выбрать извлечённый `.nes`, нажать **Играть**.
Без выбранного файла запускается демо. Файлы `.7z` нужно распаковать заранее.
Можно использовать подготовленные `ROM/selected/*.nes`.

Параметры путей: `-EmSdk C:\path\emsdk`, `-DasSDL3 C:\path\dasSDL3`,
`-DependencyBuild C:\path\dasSDL3\build\web`. Настольные библиотеки и SDK не
переконфигурируются: сборка переиспользует готовые wasm-архивы зависимости.
Если Web-профиль зависимости ещё не собран, сначала выполнить `web/build.cmd`
из dasSDL3 в окружении `emsdk_env.bat` — см. его `web/README.md`.

Для размещения достаточно содержимого `build/web/site`: HTML, CSS, JS, WASM,
data. Требуется HTTP(S) и MIME `application/wasm`; через `file://` запуск не
поддерживается. Желательны gzip/Brotli. SharedArrayBuffer и COOP/COEP не нужны.
Публикация в интернет автоматически не выполняется.

## Управление и жизненный цикл

Enter — Start, правый Shift — Select, Z/X — A/B, стрелки — крестовина.
Щелчок по экрану возвращает ему фокус. Escape завершает сессию.
Duck Hunt автоматически включает Zapper по имени файла; для переименованного
ROM поставить галочку до запуска. ЛКМ — выстрел, ПКМ — выстрел за экран.

Пауза и скрытие вкладки останавливают эмуляцию и приостанавливают AudioContext.
После возобновления часы NES и очередь звука сбрасывают накопленное отставание.
Звук запускается после пользовательского действия. Если браузер его блокирует,
нажать кнопку звука. Факт очереди SDL сам по себе не означает слышимое воспроизведение.

Stop освобождает текстуру, renderer, окно, audio stream, daScript Context и
оставшийся Web Audio context. «Заново» создаёт свежий WASM instance и canvas,
сохраняя выбранные ROM-байты только в JS-памяти этой страницы. Перезагрузка
страницы их удаляет. Battery saves и сохранение состояния пока отсутствуют.

## AOT

Web использует собственный **wasm32** генератор AOT, выполняемый в Node при сборке.
Это важно: разметка указателей/структур Windows x64 не подходит для wasm32.
Все скрипты компилируются по одинаковым виртуальным путям `/app`, `/daslib`,
`/dassdl3` при генерации и в браузере. CMake отслеживает их изменения.

Сначала собирается `generate_web_aot.js`, затем генерируется C++ всех модулей и
импортированных boost-библиотек и компилируется `dasnes_web.wasm`.
Браузерный host проверяет `fail_on_no_aot` и AOT entry points; скрытого перехода
на интерпретатор нет. Runtime-компилятор daScript пока включён для загрузки
программы, поэтому WASM около 28.5 MB, data около 4.5 MB без сжатия.

`web_main.das` экспортирует `app_init/frame/event/quit/resume`.
SDL callbacks возвращаются браузеру каждый кадр, без блокирующего `while` или
`SDL_Delay`. Browser requestAnimationFrame синхронизирует показ; независимые
часы NES сохраняют ~60.0988 кадров/с и темп APU при другой частоте монитора.

## Проверки

```powershell
python -m venv work/web-tests
work/web-tests/Scripts/python -m pip install playwright pillow
work/web-tests/Scripts/python web/test_browser.py --url http://127.0.0.1:8080 --browser edge --roms ROM/selected
work/web-tests/Scripts/python -m playwright install firefox
work/web-tests/Scripts/python web/test_browser.py --url http://127.0.0.1:8080 --browser firefox --roms ROM/selected
```

Проверены Edge и Firefox на Windows: демо, все восемь основных ROM, около 60 FPS,
переход Mario в игру с клавиатуры, ненулевой PCM в реальном выходном буфере Web
Audio, закрытие аудиоконтекста, Pause/Resume, Stop/Restart, повреждённый заголовок
и неподдерживаемый mapper. Снимки сохраняются в `work/web-checks`.
Это ограниченные браузерные прогоны, не полное прохождение игр. Safari, мобильные
браузеры и физическое воспроизведение через колонки отдельно не проверялись.
Точность CPU/PPU/APU и ограничения mapper’ов совпадают с настольным ядром.

## GitHub Pages

Сборка, проверка и публикация: [PAGES.md](PAGES.md). Workflow: `.github/workflows/pages.yml`.
