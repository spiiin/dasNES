# dasNES

Эмулятор **Nintendo Entertainment System (NES)** на **daScript** с настольной и браузерной версиями. CPU, PPU, звук и мапперы реализованы на daScript; [dasSDL3](https://github.com/spiiin/dasSDL3) обеспечивает изображение, аудио и ввод.

Обе версии используют общее ядро и AOT-компиляцию: в нативный код для Windows и в WebAssembly для браузера. В репозиторий входит собственный небольшой демонстрационный ROM — для первого запуска игры не нужны.

[Запуск](#запуск-на-windows) · [Веб-версия](#веб-версия) · [Управление](#управление) · [Совместимость](#совместимость) · [Разработка](#разработка)

## Возможности

- **CPU:** Ricoh 2A03/6502, все 151 официальная инструкция, прерывания NMI/IRQ, учёт тактов и OAM DMA.
- **PPU:** изображение 256×240, фон, палитры, спрайты 8×8 и 8×16, приоритеты, sprite-zero hit и скроллинг.
- **APU:** два импульсных канала, треугольный, шумовой и DMC; вывод монофонического звука 48 кГц.
- **Картриджи:** iNES 1.0, мапперы 0 (NROM), 1 (MMC1), 2 (UxROM), 3 (CNROM), 4 (MMC3), 42 (FDS conversions), переключение PRG/CHR-банков, CHR RAM и зеркалирование nametable.
- **Ввод:** контроллер с клавиатуры и NES Zapper с мышью.
- **Темп игры:** частота NTSC около 60,1 кадра/с независимо от частоты обновления монитора; счётчик FPS показывает кадры эмуляции.
- **Браузер:** загрузка локального ROM, звук, пауза, перезапуск и Zapper. Файл ROM остаётся в памяти браузера и не отправляется на сервер.

Проект развивается. Проверены Windows x64 / MSVC и браузеры Edge и Firefox на Windows. Ограничения точности и совместимости перечислены ниже.

## Запуск на Windows

### Зависимости

Нужны Git, CMake 3.24+, Ninja, инструменты C++ Visual Studio 2022 и Windows SDK. Сначала соберите **Release x64** версию dasSDL3 по его [инструкции](https://github.com/spiiin/dasSDL3#getting-started).

По умолчанию репозитории должны находиться рядом:

```text
workspace/
├── dasSDL3/             # собран в build/ninja
└── dasNES/
```

Клонирование dasNES из этой общей папки:

```powershell
git clone https://github.com/spiiin/dasNES.git
cd dasNES
```

### Сборка и запуск

В PowerShell из папки dasNES:

```powershell
.\build.ps1
.\run.ps1                         # встроенное демо
.\run.ps1 -Rom '.\roms\game.nes'  # ваш распакованный ROM
```

Папку `roms` можно создать самостоятельно или передать абсолютный путь к `.nes`. Пути с пробелами и квадратными скобками поддерживаются; заключайте их в кавычки.

Дополнительные параметры:

```powershell
.\run.ps1 -Rom '.\roms\game.nes' -Mute
.\run.ps1 -Rom '.\roms\game.nes' -Zapper
.\build.ps1 -DasSDL3 '..\dasSDL3' -DependencyBuild '..\dasSDL3\build\ninja'
```

Сборка использует готовые библиотеки dasSDL3 Release x64 (`/MD`) и создаёт `build/aot/dasNES.exe`. После изменения исходников `.das` повторите `build.ps1`.

Для игры рекомендуется AOT-сборка. Параметр `-Interpreter` запускает интерпретатор, который может быть слишком медленным для реального времени. Если AOT ещё не собран, launcher использует доступный интерпретатор с предупреждением.

### Интерпретатор с JIT

```powershell
.\build.ps1 -Jit                    # один раз: установить LLVM и собрать launcher
.\run.ps1 -Interpreter -Jit -Rom 'C:\roms\game.nes'
.\benchmark.ps1 -Jit -Rom 'C:\roms\game.nes'
.\benchmark.ps1 -Jit -Profile -Rom 'C:\roms\game.nes'
```

`-Jit` сам включает режим интерпретатора; `-Interpreter` можно опустить.
В этом режиме используется `build/aot/dasNES.exe`, который загружает `.das` и
компилирует функции через LLVM JIT. В журнале появляются `LLVM JIT: ... functions`
и `dasNES: LLVM JIT (in memory)`. При отсутствии JIT entry point запуск завершается
ошибкой, без незаметного перехода на обычный интерпретатор.

`build.ps1 -Jit` скачивает закреплённый LLVM 22.1.5, проверяет SHA256 архива и
помещает `LLVM.dll` (~54 MB) в `build/jit`. При повторной сборке скачивание не нужно.
Используется JIT в памяти, без DLL-кэша: компиляция добавляет задержку при каждом
запуске, но не требует пересобирать EXE после правок `.das`.
Без `-Jit` поведение прежнее. JIT доступен только для Windows launcher и несовместим
с `-Standalone`; компактные Windows/Web-сборки не включают LLVM.

### Компактная standalone-сборка

```powershell
.\build.ps1 -Standalone
.\run.ps1 -Standalone -Rom 'C:\roms\Super Mario Bros. (W) [!].nes'
```

Результат — `build/aot/dasNES_standalone.exe`. Его можно перенести в отдельную
папку и запускать без исходников `.das`, dasSDL3 runner и checkout daScript:

```powershell
.\dasNES_standalone.exe --rom 'C:\roms\game.nes'
```

Без `--rom` запускается `demo.nes` рядом с EXE; сборка копирует его автоматически.
Поддерживаются `--mute`, `--zapper`, `--smoke-test` и переменные окружения
`DASNES_ROM`, `DASNES_MUTE`, `DASNES_ZAPPER`. Для Duck Hunt при прямом запуске
EXE передайте `--zapper`; `run.ps1` определяет его по имени ROM.
Как и обычная MSVC-сборка, EXE требует Microsoft Visual C++ Runtime x64.

Компилятор daScript нужен **только при сборке**. Генератор создаёт C++ standalone-
контекст и линкует его с SDL3 и `libDaScript_runtime`; runtime для строк, массивов,
контекста и AOT-вызовов остаётся. Парсер, компилятор, регистрации модулей и тестовые
скрипты в этот EXE не входят. Сборка автоматически проверяет linker map.
На проверенной Release x64 конфигурации: **31,56 → 4,81 MB** (−85%).

Обычные `build.ps1`, `run.ps1 -Interpreter`, тесты и профилирование продолжают
использовать сборку для разработки. Standalone не загружает произвольные `.das`:
после изменения исходников его нужно пересобрать.

## Веб-версия

Нужны **Emscripten 5.0.3**, CMake, Ninja, Python и заранее собранный Web-профиль dasSDL3. Подготовка зависимости описана в [dasSDL3 Web](https://github.com/spiiin/dasSDL3/blob/HEAD/web/README.md); необходимые функции обвязки перечислены в [документации веб-версии](web/README.md).

Из папки dasNES, указав путь к своей установке Emscripten SDK:

```powershell
.\build-web.ps1 -EmSdk 'C:\path\to\emsdk'
python -m http.server 8080 --bind 127.0.0.1 --directory build/web/site
```

Откройте [локальную страницу](http://127.0.0.1:8080/), выберите `.nes` и нажмите **Играть**. Без выбранного файла запускается демо. Архивы нужно распаковать заранее.

На странице доступны пауза, перезапуск и выключение звука. При скрытии вкладки эмуляция приостанавливается. Браузер разрешает запуск звука после действия пользователя.

Для размещения на статическом хостинге скопируйте всё содержимое `build/web/site`. Нужен HTTP(S)-сервер с MIME-типом `application/wasm`; открытие через `file://` не поддерживается. Подробнее о сборке, размещении и браузерных тестах — в [web/README.md](web/README.md).

## Управление

| Действие | Клавиша |
| --- | --- |
| Крестовина | Стрелки |
| A | Z |
| B | X |
| Select | Правый Shift |
| Start | Enter |
| Выход / завершение сессии | Esc |

Для Zapper: мышь — прицел, левая кнопка — выстрел, правая — выстрел за пределы экрана. Duck Hunt включает Zapper автоматически по имени файла. Для переименованного ROM используйте `-Zapper` на Windows или переключатель на веб-странице. В браузере щелчок по экрану игры возвращает фокус клавиатуры.

## Совместимость

Следующие версии ROM использовались для проверок:

| Игра / версия ROM | Маппер |
| --- | --- |
| Super Mario Bros. (W) [!] | 0 — NROM |
| Duck Hunt (W) [!] | 0 — NROM |
| Darkwing Duck (U) [!] | 1 — MMC1 |
| Contra (U) [!] | 2 — UxROM |
| Duck Tales (U) [!] | 2 — UxROM |
| Megaman IV (U) (PRG1) [!] | 4 — MMC3 |
| Super Mario Bros. 3 (U) (PRG1) [!] | 4 — MMC3 |
| Teenage Mutant Ninja Turtles III - The Manhattan Project (U) [!] | 4 — MMC3 |

Настольные проверки включали воспроизведение ввода в течение 3600 кадров для каждого ROM; браузерные — запуск каждого ROM на 300 кадров в Edge и Firefox. Для Super Mario Bros. отдельно проверяется скроллинг через границы nametable. Это проверки запуска и отдельных сценариев, а не полное прохождение игр.

Игровые ROM в репозиторий не входят. Включён только оригинальный [demo.nes](demo.nes).

### Ограничения

- Поддерживается NTSC; PAL, NES 2.0, другие мапперы и неофициальные инструкции CPU пока не реализованы.
- Нет сохранения battery-backed SRAM на диск, сохранений состояния и второго обычного контроллера.
- PPU рисует по строкам: изменения внутри строки и аппаратный конвейер выборки пикселей воспроизводятся приблизительно.
- CNROM: оригинальные iNES-платы с PRG 16/32 KiB и CHR ROM 8–32 KiB, AND bus conflicts. NES 2.0 submapper и расширенные CNROM-платы пока не поддерживаются.
- MMC3 IRQ, взаимодействие DMC/OAM DMA, пограничные случаи NMI и Zapper пока не полностью соответствуют аппаратуре.
- Аппаратная ошибка sprite overflow и цветовое emphasis не воспроизводятся.

## Разработка

Основные проверки запускаются из PowerShell:

```powershell
.\test.ps1
.\test.ps1 -Nestest
.\test.ps1 -SmbRom '.\roms\Super Mario Bros. (W) [!].nes'
.\benchmark.ps1 -Rom '.\roms\game.nes'
.\benchmark.ps1 -Rom '.\roms\game.nes' -Interpreter
.\benchmark.ps1 -Rom '.\roms\game.nes' -Interpreter -Profile
```

`test.ps1` проверяет CPU, PPU, скроллинг, APU, мапперы, темп эмуляции и запуск демо. `-Nestest` требует Python 3 и скачивает эталонные файлы при первом запуске; сравниваются первые 5003 состояния для официальных инструкций CPU. `-SmbRom` требует указанную версию ROM и проверяет сценарий скроллинга.

Бенчмарк измеряет скорость ядра без ограничения частоты, поэтому его FPS отличается от счётчика в игре. `-Interpreter` использует тот же dasSDL3 runner, что и запуск игры. `-Profile` отдельно измеряет CPU, APU и PPU после каждой инструкции; эти значения включают накладные расходы измерений. Для сравнения общей скорости используйте запуск без `-Profile`. Профиль также выводит хеш звука всех измеренных кадров и итоговый хеш изображения/RAM.

`renderer_tests.das` сравнивает оптимизированный рендерер с исходным попиксельным алгоритмом на 2048 детерминированных сценариях, включая скроллинг, CHR-банки, зеркалирование, спрайты и Zapper. `apu_event_tests.das` сравнивает обработку APU по событиям с потактовым эталоном: состояния каналов, IRQ, задержки DMC и точные байты PCM, включая случайные записи в регистры. Инструкции для Playwright находятся в [web/README.md](web/README.md).

### Исходники

| Файл / папка | Назначение |
| --- | --- |
| [state.das](state.das), [core.das](core.das) | Состояние NES, загрузка ROM и шина CPU |
| [cpu.das](cpu.das) | Инструкции Ricoh 2A03/6502 |
| [ppu.das](ppu.das) | Регистры, тайминги и изображение PPU |
| [apu.das](apu.das) | Звуковые каналы и микшер |
| [mapper.das](mapper.das) | NROM, MMC1, UxROM, CNROM и MMC3 |
| [pacing.das](pacing.das) | Синхронизация времени и кадров |
| [main.das](main.das), [native/](native/) | Настольная версия и AOT-сборка |
| [web_main.das](web_main.das), [web/](web/) | Браузерная версия, WebAssembly и веб-интерфейс |
| [tools/](tools/) | Генераторы CPU и демо, тестовые инструменты |

## Материалы

- [NESdev Wiki](https://www.nesdev.org/wiki/Nesdev_Wiki) — описание аппаратуры NES.
- [Writing NES Emulator in Rust](https://bugzmanov.github.io/nes_ebook/chapter_1.html) — последовательный разбор устройства эмулятора.
- [Porting a NES emulator from Go to Nim](https://hookrace.net/blog/porting-nes-go-nim/) — пример реализации и переноса эмулятора.
- [NES test ROMs](https://github.com/christopherpow/nes-test-roms) — тестовые программы и эталонные данные.
- [dasSDL3](https://github.com/spiiin/dasSDL3) — привязки SDL3 к daScript.

Mapper 42: PRG 128 KiB, CHR ROM до 128 KiB или CHR RAM 8 KiB; банк ROM в $6000–$7FFF, фиксированные последние 32 KiB PRG, CHR-банки, mirroring и циклический CPU IRQ. Это поддержка картриджных конверсий, не дисковода FDS. Спецификация: https://www.nesdev.org/wiki/INES_Mapper_042 .
