file(READ "${MAP_FILE}" symbols)
# Runtime services (arrays, strings, Context, AOT call adapters) are intentional.
# Neither the compiler library, parser nor module factories may enter this build.
if(symbols MATCHES "compileDaScript|das2?_yyparse|register_Module_|libDaScript[.:]")
    message(FATAL_ERROR "Standalone link unexpectedly contains compiler/module registrations: ${MAP_FILE}")
endif()
message(STATUS "Standalone link checked: no compiler or module registrations")
