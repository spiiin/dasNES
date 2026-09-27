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
.\run.ps1 -Rom C:\roms\game.nes    # свой NTSC NROM ROM
.\run.ps1 -Rom C:\roms\game.nes -Runner C:\path\dasSDL3_runner.exe
```

Управление: **Z** — A, **X** — B, **правый Shift** — Select, **Enter** — Start,
стрелки — крестовина, **Esc** — выход. Окно 768×720, изображение NES 256×240.
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

- Загрузчик iNES 1.0: mapper 0, PRG 16/32 KiB, CHR ROM 8 KiB / CHR RAM, trainer,
  горизонтальное, вертикальное и four-screen зеркалирование. Некорректные и обрезанные файлы отклоняются.
- Все 151 официальная инструкция Ricoh 2A03/6502, флаги, стек, BRK/RTI, NMI,
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

Это начальная реализация NROM, а не обещание совместимости со всеми играми.
**APU/звук, IRQ APU, другие mapper'ы, PAL/NES 2.0, второй контроллер,
сохранение battery SRAM и неофициальные opcodes пока не реализованы.**
Неизвестная инструкция останавливает эмулятор с PC и opcode.

PPU рисует строку по снимку v и fine-X на dot 1; sprite-zero hit выставляется
на dot соответствующего пересечения, а не в конце строки. Фоновые fetch/shifter
pipeline и изменения картинки внутри строки пока приближённые. Race conditions NMI,
аппаратная ошибка sprite overflow и color emphasis не воспроизводятся.
CPU учитывает длительность инструкций, но не моделирует каждый bus cycle.
Поэтому игры с точными растровыми эффектами могут работать неправильно.
Интерпретатор может не успевать в real-time; для игры используйте AOT-сборку.
Ограничитель рассчитан на ~60.0988 FPS. FPS в заголовке учитывает эмуляцию, вывод и ожидание.

## Проверки

```powershell
.\test.ps1              # CPU/bus/PPU/controller + SDL demo smoke
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

## Структура

| Файл | Назначение |
|---|---|
| `core.das` | Состояние машины, cartridge, память, PPU registers, контроллер |
| `cpu.das` | Генерируемый декодер официальных инструкций |
| `tools/generate_cpu.py` | Таблица opcodes и генератор декодера |
| `ppu.das` | Рендер строк и тайминг PPU |
| `main.das` | SDL frontend |
| `tests.das`, `trace.das` | Проверки и экспорт трассы |
| `timing_tests.das`, `benchmark.das` | Эквивалентность PPU и скорость ядра |
| `scroll_tests.das`, `smb_scroll_test.das` | Регрессии прокрутки и необязательный replay SMB |
| `native/`, `CMakeLists.txt`, `build.ps1` | Host и сборка AOT; логика эмуляции остаётся в daScript |

Дальнейшая работа: точный fetch/shifter pipeline PPU, APU, неофициальные opcodes,
mapper 2/3/1, проверка на открытых тестовых ROM и homebrew играх.

## Справочные материалы

- [NESdev Wiki](https://www.nesdev.org/wiki/Nesdev_Wiki)
- [PPU scrolling: v/t и правила переноса](https://www.nesdev.org/wiki/PPU_scrolling)
- [Writing NES Emulator in Rust](https://bugzmanov.github.io/nes_ebook/chapter_1.html)
- [Porting a NES emulator from Go to Nim](https://hookrace.net/blog/porting-nes-go-nim/)
- [nestest и другие тестовые ROM](https://github.com/christopherpow/nes-test-roms)

Реализация написана для этого проекта; код других эмуляторов не копировался.

