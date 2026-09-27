#include "daScript/daScript.h"
#include <SDL3/SDL.h>
#define SDL_MAIN_HANDLED
#include <SDL3/SDL_main.h>
#include <cstring>
#include <iostream>
#include <filesystem>
#include "daScript/ast/dyn_modules.h"
DECLARE_MODULE(Module_dasSDL3);
DECLARE_MODULE(Module_LLVM);

static int run(const char *path, bool smoke, bool interpret, bool jit) {
    using namespace das;
    TextPrinter log;
    ModuleGroup modules;
    auto access = make_smart<FsFileAccess>();
    access->addFsRoot("dassdl3", std::string(DASNES_SDL_ROOT) + "/dassdl3");
    CodeOfPolicies policy;
    policy.aot = !interpret;
    policy.fail_on_no_aot = !interpret;
    policy.tune_frozen = true;
    if (jit) {
        policy.jit_enabled = true;
        policy.jit_dll_mode = false; // In-memory JIT; no linker or cached DLL required.
        policy.dll_search_paths.emplace_back(DASNES_JIT_ROOT);
        for (const char *folder : {"daslib", "bindings"}) {
            auto root = std::filesystem::path(getDasRoot().c_str()) / "modules/dasLLVM" / folder;
            for (const auto &file : std::filesystem::directory_iterator(root)) {
                if (file.path().extension() != ".das") continue;
                auto name = std::string(folder) + "/" + file.path().stem().string();
                replay_native_path("llvm", name.c_str(), file.path().generic_string().c_str());
            }
        }
        access->addExtraModule("just_in_time", getDasRoot() + "/daslib/just_in_time.das");
    }
    auto program = compileDaScript(path, access, log, modules, policy);
    auto errors = [&] {
        for (const auto &e : program->errors) log << reportError(e.at, e.what, "", e.fixme, e.cerr);
        if (!interpret) log << "If scripts changed, run build.ps1 to regenerate AOT.\n";
    };
    if (program->failed()) { errors(); return 1; }
    Context context(program->getContextStackSize());
    if (!program->simulate(context, log)) { errors(); return 1; }
    auto entry = context.findFunction("main");
    if (!entry || !verifyCall<int32_t, bool>(entry->debugInfo, modules)) {
        log << "Expected [export] def main(smoke : bool) : int\n"; return 1;
    }
    if (!interpret && !entry->aot) { log << "AOT missing: rebuild with build.ps1\n"; return 1; }
    if (jit && !entry->jitFunction) { log << "JIT entry point missing; refusing silent interpreter fallback\n"; return 1; }
    log << (jit ? "dasNES: LLVM JIT (in memory)\n" : interpret ? "dasNES: interpreter\n" : "dasNES: AOT, interpreter fallback disabled\n");
    vec4f args[] = {cast<bool>::from(smoke)};
    auto value = context.evalWithCatch(entry, args);
    if (const char *error = context.getException()) { log << error << "\n"; return 1; }
    return cast<int32_t>::to(value);
}
int main(int argc, char **argv) {
    if (argc < 2) { std::cerr << "Usage: dasNES script.das [--smoke-test] [--interpret] [--jit]\n"; return 2; }
    bool smoke = false, interpret = false, jit = false;
    for (int i = 2; i < argc; ++i) {
        if (!std::strcmp(argv[i], "--smoke-test")) smoke = true;
        else if (!std::strcmp(argv[i], "--jit")) { jit = true; interpret = true; }
        else if (!std::strcmp(argv[i], "--interpret")) interpret = true;
        else { std::cerr << "Unknown argument: " << argv[i] << '\n'; return 2; }
    }
    if (jit && !std::filesystem::is_regular_file(std::string(DASNES_JIT_ROOT) + "/LLVM.dll")) {
        std::cerr << "LLVM missing: run .\\build.ps1 -Jit first\n"; return 2;
    }
    SDL_SetMainReady();
    das::setDasRoot(std::string(DASNES_SDL_ROOT) + "/third_party/daScript");
    NEED_ALL_DEFAULT_MODULES;
    NEED_MODULE(Module_dasSDL3);
    if (jit) { NEED_MODULE(Module_LLVM); }
    das::Module::Initialize();
    const int result = run(argv[1], smoke, interpret, jit);
    SDL_Quit();
    das::Module::Shutdown();
    return result;
}
