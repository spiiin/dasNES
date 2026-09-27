options gen2
require daslib/aot_standalone
require daslib/aot_cpp
require daslib/ast
require daslib/rtti
require daslib/c_api_header

// Build-time only. All calls in this application have AOT implementations;
// SDL/FIO handles are managed explicitly, without runtime reflection or GC.
// Registering the compile-time modules here would retain the compiler in the EXE.
[export]
def emit(var program : ProgramPtr; var pctx : smart_ptr<Context>; output : string) : bool {
    let (modules, no_aot) = getRequiredModulesFor(program, true)
    verify(!no_aot)
    var registrations : array<StandaloneModuleEntry>
    let cfg = StandaloneContextCfg(context_name = "ctx_nes", file_stem = "nes", class_name = "Standalone", cpp_output_dir = output, registers_modules = false)
    return runStandaloneVisitor(program, modules, registrations, pctx, cfg)
}
