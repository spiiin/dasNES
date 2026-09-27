#include "nes.das.h"
#include "daScript/ast/ast.h"
#define SDL_MAIN_HANDLED
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

int main(int argc, char **argv) {
    bool smoke = false;
    for (int i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--smoke-test")) smoke = true;
        else if (!strcmp(argv[i], "--rom") && i + 1 < argc) _putenv_s("DASNES_ROM", argv[++i]);
        else if (!strcmp(argv[i], "--mute")) _putenv_s("DASNES_MUTE", "1");
        else if (!strcmp(argv[i], "--zapper")) _putenv_s("DASNES_ZAPPER", "1");
        else {
            const bool help = !strcmp(argv[i], "--help");
            fprintf(help ? stdout : stderr, "Usage: dasNES_standalone [--rom game.nes] [--mute] [--zapper] [--smoke-test]\n");
            return help ? 0 : 2;
        }
    }
    SDL_SetMainReady();
    if (!getenv("DASNES_ROM")) {
        const char *base = SDL_GetBasePath();
        const auto demo = std::string(base ? base : "") + "demo.nes";
        _putenv_s("DASNES_ROM", demo.c_str());
    }
    // AOT needs TLS/runtime services, not registered compiler modules.
    das::daScriptEnvironment environment;
    das::daScriptEnvironmentGuard guard(&environment, nullptr);
    int result = 1;
    try {
        das::ctx_nes::Standalone context;
        result = context.main(smoke);
    } catch (const std::exception &e) {
        fprintf(stderr, "dasNES: %s\n", e.what());
    }
    SDL_Quit();
    das::clearGlobalAotLibrary();
    return result;
}
