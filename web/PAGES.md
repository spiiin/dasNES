# GitHub Pages

Ожидаемый адрес после публикации: https://spiiin.github.io/dasNES/.

## Первый запуск

1. В `spiiin/dasNES` открыть **Settings → Pages → Build and deployment → Source → GitHub Actions**.
2. Отправить исходники и `.github/workflows/pages.yml` в ветку `main`.
3. Дождаться workflow **GitHub Pages** во вкладке Actions. Повторный запуск:
   **GitHub Pages → Run workflow → main**.

Push в `main` собирает и публикует сайт. Pull request только собирает и проверяет.
Адрес успешной публикации появляется в environment `github-pages` и выводе deploy.
Настройки Pages, права Actions и ограничения environment должны разрешать deployment из `main`.
Для deploy используется `GITHUB_TOKEN`; ветка `gh-pages`, домен и сервер не нужны.

## Доступ к приватному dasSDL3

Обычный `GITHUB_TOKEN` действует только в dasNES и не может читать другой
приватный репозиторий. Поэтому checkout dasSDL3 может завершиться сообщением
`Repository not found`, даже если локальный Git успешно читает его.

1. В GitHub **Settings → Developer settings → Personal access tokens →
   Fine-grained tokens** создать токен с владельцем `spiiin`, доступом только
   к `dasSDL3` и разрешением **Contents: Read-only**.
2. В репозитории **dasNES → Settings → Secrets and variables → Actions →
   New repository secret** сохранить его под именем `DASSDL3_READ_TOKEN`.
3. Отправить обновлённый workflow в `main` и запустить новый **Run workflow**.
   Перезапуск старого run использует старую версию workflow.

Токен используется только для checkout зависимости и не сохраняется в Git config.
Если dasSDL3 публичный, secret не нужен: workflow использует `github.token`.
Токен с истёкшим сроком нужно обновить. Secrets недоступны для PR из fork и
Dependabot, поэтому их сборка с приватной зависимостью не пройдёт; используйте
доверенную ветку для проверки. Не переключайте workflow на `pull_request_target`
для выполнения кода из PR.

См. [checkout private repositories](https://github.com/actions/checkout#checkout-multiple-repos-private).

## Что собирается

Ubuntu 24.04, Emscripten 5.0.3, dasSDL3 на коммите
`2c559dc0b9127415599640ef2c5b3ccbb498225a`, его daScript submodule и SDL 3.4.16.
Генерация AOT выполняется в wasm32 через Node. Windows-библиотеки не используются.
Сначала собирается Web-профиль dasSDL3, затем `web/CMakeLists.txt` этого проекта.
Два параллельных процесса ограничивают потребление памяти CI. Первая сборка длительная.

Перед публикацией Firefox запускает демо, проверяет изображение, строгий AOT,
Pause/Resume и Stop/Restart по адресу с префиксом `/dasNES/`.
Ошибка сборки или проверки блокирует deploy. Запуск workflow на GitHub остаётся
необходимой проверкой чистой Linux-сборки; локальная Windows-сборка её не заменяет.

`tools/package_pages.py` копирует только HTML, CSS, два JS-файла, WASM и data
в `build/pages`, добавляет `.nojekyll`. Каталог назначения должен быть пустым.
В data CMake упаковывает только наше `demo.nes`; ядро встроено в standalone WASM.
Коммерческие ROM в artifact не входят. Выбранный пользователем ROM читается
в память браузера и не отправляется на сервер.

## Локальная проверка пакета

```powershell
.\build-web.ps1
python tools/package_pages.py
python -m http.server 8080 --bind 127.0.0.1 --directory build/pages
```

Открыть http://127.0.0.1:8080/. При повторной упаковке выбрать новый пустой каталог
через `--output` или убрать предыдущий `build/pages`.
Сайт использует относительные URL, поэтому работает и в корне, и в `/dasNES/`.
Для запуска нужны HTTP(S), WebAssembly SIMD, WebAssembly exceptions и WebGL.
SharedArrayBuffer, COOP/COEP и специальный backend не требуются.
Размер текущего standalone-пакета около 2,77 MB без сжатия; первая загрузка зависит от сети.

Документация: [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages),
[Emscripten SDK](https://emscripten.org/docs/getting_started/downloads.html).
