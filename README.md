# dasNES

Первая рабочая версия эмулятора NTSC NES на **daScript** с выводом через **dasSDL3**.
Ядро целиком написано на daScript; Python используется только для генерации кода/демо и проверки эталонной трассы.

## Запуск

Нужен собранный [dasSDL3](https://github.com/spiiin/dasSDL3). По умолчанию launcher ищет его рядом с dasNES:
`../dasSDL3/build/ninja/bin/dasSDL3_runner.exe`.

```powershell
cd C:\src\dasNES
.\build.ps1                       # собрать AOT один раз; MSVC x64 + CMake/Ninja
.\run.ps1                         # встроенный оригинальный demo ROM
.\run.ps1 -Rom C:\roms\game.nes    # свой NTSC ROM (mapper 0/1/2/4)
.\run.ps1 -Rom C:\roms\game.nes -Runner C:\path\dasSDL3_runner.exe
```

Управление: **Z** — A, **X** — B, **правый Shift** — Select, **Enter** — Start,
стрелки — крестовина, **Esc** — выход. Окно 768×720, изображение NES 256×240.
Звук: пять каналов APU, mono PCM 48 kHz через SDL AudioStream. `-Mute` отключает
аудиоустройство, сохраняя эмуляцию APU. Для Duck Hunt launcher автоматически включает
Zapper: мышь — прицел, левая кнопка — выстрел, правая — выстрел за пределы экрана.
Для другого имени ROM можно указать `-Zapper`.
Путь ROM передаётся через переменную окружения процесса `DASNES_ROM`; launcher восстанавливает её после запуска.

`run.ps1` автоматически выбирает `build/aot/dasNES.exe`, если он собран.
В этом режиме всё ядро и frontend выполняются как AOT C++ без interpreter fallback.
После изменения `.das` запустите `build.ps1` снова: устаревшая сборка выдаст ошибку,
а не незаметно перейдёт на медленное выполнение. `-Interpreter` принудительно включает
старый интерпретатор; без AOT-сборки launcher использует его с предупреждением.

Сборка использует существующую Release x64 `/MD` сборку соседнего dasSDL3 и ту же
установку MSVC из её CMake cache. Библиотеки SDL/daScript повторно не собираются;
binding registration с поддержкой AOT собирается внутри проекта, исходный dasSDL3 не меняется.
Другой путь: `./build.ps1 -DasSDL3 C:\path\dasSDL3 -DependencyBuild C:\path\build`.

## Реализовано

- Загрузчик iNES 1.0: NROM (0), MMC1 (1), UxROM (2), MMC3 (4), PRG/CHR banking,
  CHR RAM, trainer, горизонтальное/вертикальное/one-screen/four-screen зеркалирование.
  MMC1 serial register, MMC3 IRQ, PRG RAM enable/write protection.
  Некорректные и обрезанные файлы отклоняются.
- APU: два pulse, triangle, noise, DMC, envelope/length/linear counters, sweep,
  4/5-step frame sequencer, IRQ, DMC PRG reads и CPU stalls. Нелинейный микшер,
  усреднение по CPU-тактам, фильтрация DC и высоких частот, вывод S16LE 48 kHz.
- Все 151 официальная инструкция Ricoh 2A03/6502, флаги, стек, BRK/RTI, NMI/IRQ,
  переходы через границы страниц, особенности JMP indirect, такты инструкций и OAM DMA.
  Decimal flag сохраняется, но арифметика остаётся двоичной, как на NES.
- CPU bus: RAM mirrors, SRAM, PPU registers, serial controller.
- PPU: фон, attribute palettes, спрайты 8×8/8×16, отражения, приоритет,
  ограничение восьми спрайтов, sprite-zero hit, палитра, grayscale, vblank/NMI,
  буфер $2007, внутренние scroll-регистры v/t, переносы на dot 257 и 280–304,
  циклический переход между nametable, отношение PPU/CPU 3:1.
- dasSDL3: streaming RGBA texture, клавиатура, освобождение ресурсов через scopes,
  ограниченный скрытый smoke test.

## Ограничения

Поддержка ориентирована на выбранные NTSC-версии восьми игр ниже.
**Другие mapper'ы, PAL/NES 2.0, второй обычный контроллер,
сохранение battery SRAM и неофициальные opcodes пока не реализованы.**
Неизвестная инструкция останавливает эмулятор с PC и opcode.

PPU рисует строку по снимку v и fine-X на dot 1; sprite-zero hit выставляется
на dot соответствующего пересечения, а не в конце строки. Фоновые fetch/shifter
pipeline и изменения картинки внутри строки пока приближённые. Race conditions NMI,
аппаратная ошибка sprite overflow и color emphasis не воспроизводятся.
MMC3 IRQ пока использует приближение A12 по фазам фоновых/спрайтовых fetch,
а не полную модель PPU-шины. DMC DMA учитывает четыре такта задержки, без точного
арбитража с OAM DMA и аппаратных конфликтов чтения контроллера. APU-записи происходят
на границе инструкции; тактовые edge cases не заявляются полностью точными.
Zapper проверяет яркость около прицела при рендере строки и время затухания датчика.
CPU учитывает длительность инструкций, но не моделирует каждый bus cycle.
Поэтому игры с точными растровыми эффектами могут работать неправильно.
Интерпретатор может не успевать в real-time; для игры используйте AOT-сборку.
Ограничитель рассчитан на ~60.0988 FPS. FPS в заголовке учитывает эмуляцию, вывод и ожидание.

## Проверки

```powershell
.\test.ps1              # CPU/bus/PPU/APU/mapper/controller + SDL audio/video smoke
.\test.ps1 -Nestest     # дополнительно Python 3, интернет при первом запуске
.\test.ps1 -Nestest -SmbRom '.\ROM\Super Mario Bros. (W) [!].nes'
.\benchmark.ps1 -Rom '.\ROM\Super Mario Bros. (W) [!].nes'
.\benchmark.ps1 -Rom '.\ROM\Super Mario Bros. (W) [!].nes' -Interpreter
```

`-Nestest` загружает тестовый ROM и эталонную трассу в игнорируемую папку `work/`.
Сравнивает первые **5003** состояния официальной части nestest: PC, A, X, Y, P, SP,
число CPU cycles. Неофициальная часть теста не заявляется пройденной.
Коммерческие ROM в репозиторий не включаются. `demo.nes` создан специально для проекта:
рисует узор и меняет цвет через NMI. Генерация: `python tools/make_demo.py`.

Дополнительно проверен Super Mario Bros. (W): replay на 1800 кадров с обычным
управлением проходит два перехода nametable. Он воспроизводит прежнее зависание
в ожидании sprite-zero hit на $8150 после первой смены страницы. Полное прохождение
и совместимость всех игровых эффектов не проверялись. Архивы из `ROM/` исключены из Git;
для запуска требуется извлечённый `.nes`, чтение `.7z` в launcher не реализовано.

Benchmark прогревает 60 кадров и измеряет 120 без ожидания и SDL-вывода: это скорость
ядра, а не FPS окна. Выводит checksum framebuffer/RAM и состояние CPU для сравнения
интерпретатора с AOT. `timing_tests.das` сравнивает 3746 сценариев PPU с потактовым
эталонным планировщиком, включая границы событий, scroll transfers, DMA и нечётные кадры.
`scroll_tests.das` проверяет wrap coarse/fine scroll, адресацию $2007 и split экрана
со sprite-zero hit при разных значениях PPUCTRL и внутреннего адреса v.

Оптимизации: декодер CPU делает 8 сравнений вместо линейной цепочки из 151 проверки;
PPU перескакивает до следующего события; единственный framebuffer напрямую передаётся
в upload_rgba8 без второго скриптового массива и побайтного копирования.

## Основные ROM из локальных архивов

Из каждого архива выбран один good dump NTSC; при наличии PRG0/PRG1 выбрана PRG1.
Извлечённые файлы находятся в `ROM/selected/` (папка исключена из Git).

| Архив | Выбранный ROM | Mapper |
|---|---|---|
| Contra | Contra (U) [!] | 2 — UxROM |
| Darkwing Duck | Darkwing Duck (U) [!] | 1 — MMC1 |
| Duck Hunt | Duck Hunt (W) [!] | 0 — NROM + Zapper |
| Duck Tales | Duck Tales (U) [!] | 2 — UxROM |
| Megaman IV | Megaman IV (U) (PRG1) [!] | 4 — MMC3 |
| Super Mario Bros. 3 | Super Mario Bros. 3 (U) (PRG1) [!] | 4 — MMC3 |
| Super Mario Bros. | Super Mario Bros. (W) [!] | 0 — NROM |
| TMNT III | Teenage Mutant Ninja Turtles III - The Manhattan Project (U) [!] | 4 — MMC3 |

```powershell
.\run.ps1 -Rom '.\ROM\selected\Super Mario Bros. 3 (U) (PRG1) [!].nes'
.\run.ps1 -Rom '.\ROM\selected\Duck Hunt (W) [!].nes'
python tools/test_rom_set.py                 # извлечение + replay всех восьми игр
python tools/test_rom_set.py --extract-only  # только извлечение
python tools/test_rom_set.py --only smb3     # повторить одну игру
```

`test_rom_set.py` использует локальные `.7z` и системный `tar`, ничего не скачивает.
По каждой игре выполняет 3600 кадров с обычным вводом, сохраняет кадры RGBA, пять секунд
звука WAV и JSON с SHA-256 ROM/результатом в `work/compatibility/`. Проверяет выполнение
без panic, изменение изображения и наличие звукового сигнала. Это smoke/replay-проверка,
а не доказательство полного прохождения или точного воспроизведения всех эффектов.
`hardware_tests.das` отдельно проверяет банки, CHR RAM, mirroring, IRQ, APU и Zapper bus.

## Структура

| Файл | Назначение |
|---|---|
| `state.das` | Состояние NES и APU |
| `core.das` | Cartridge loader, CPU bus, PPU registers, контроллер/Zapper |
| `mapper.das` | NROM, MMC1, UxROM, MMC3 |
| `apu.das` | Пять звуковых каналов, sequencer, mixer, PCM |
| `hardware_tests.das`, `rom_replay.das` | APU/mapper проверки и replay набора ROM |
| `cpu.das` | Генерируемый декодер официальных инструкций |
| `tools/generate_cpu.py` | Таблица opcodes и генератор декодера |
| `ppu.das` | Рендер строк и тайминг PPU |
| `main.das` | SDL frontend |
| `tests.das`, `trace.das` | Проверки и экспорт трассы |
| `timing_tests.das`, `benchmark.das` | Эквивалентность PPU и скорость ядра |
| `scroll_tests.das`, `smb_scroll_test.das` | Регрессии прокрутки и необязательный replay SMB |
| `native/`, `CMakeLists.txt`, `build.ps1` | Host и сборка AOT; логика эмуляции остаётся в daScript |

Дальнейшая работа: точный fetch/shifter pipeline PPU и A12, bus-cycle CPU/APU/DMA,
неофициальные opcodes, battery saves и дополнительные mapper’ы.

## Справочные материалы

- [APU](https://www.nesdev.org/wiki/APU), [MMC1](https://www.nesdev.org/wiki/MMC1), [MMC3](https://www.nesdev.org/wiki/MMC3)
- [NESdev Wiki](https://www.nesdev.org/wiki/Nesdev_Wiki)
- [PPU scrolling: v/t и правила переноса](https://www.nesdev.org/wiki/PPU_scrolling)
- [Writing NES Emulator in Rust](https://bugzmanov.github.io/nes_ebook/chapter_1.html)
- [Porting a NES emulator from Go to Nim](https://hookrace.net/blog/porting-nes-go-nim/)
- [nestest и другие тестовые ROM](https://github.com/christopherpow/nes-test-roms)

Реализация написана для этого проекта; код других эмуляторов не копировался.

