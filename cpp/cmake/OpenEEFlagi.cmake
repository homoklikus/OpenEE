# Flagi zmiennoprzecinkowe OpenEE Core – zgodność bitowa Debug/Release (docs/cpp/BUDOWANIE.md § Flagi).
#  -ffp-contract=off   : bez łączenia a*b+c w FMA (GCC w trybie GNU domyślnie łączy, gdy cel ma FMA)
#  -fno-fast-math      : bez przestawiania działań; -fno-associative-math, -fno-reciprocal-math
#  -fexcess-precision=standard : bez nadmiarowej precyzji (istotne tylko dla x87)
#  -frounding-math NIE jest potrzebne – tryb zaokrąglania jest stały (najbliższa parzysta)
# Na x86-64 arytmetyka idzie przez SSE2 (FLT_EVAL_METHOD == 0); 32-bitowe x86 bez SSE2 nie jest wspierane.
set(OPENEE_FLAGI_FP "")
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  list(APPEND OPENEE_FLAGI_FP -ffp-contract=off -fno-fast-math -fno-associative-math -fno-reciprocal-math
       -fno-unsafe-math-optimizations -fsigned-zeros -ftrapping-math)
  # GCC < 13 nie obsługuje tej flagi dla C++; na x86-64 (SSE2) i aarch64 nadmiarowej precyzji i tak nie ma –
  # pilnuje tego static_assert FLT_EVAL_METHOD == 0 w openee/f32.hpp
  include(CheckCXXCompilerFlag)
  check_cxx_compiler_flag(-fexcess-precision=standard OPENEE_MA_EXCESS_PRECISION)
  if(OPENEE_MA_EXCESS_PRECISION)
    list(APPEND OPENEE_FLAGI_FP -fexcess-precision=standard)
  endif()
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(i.86|x86)$")
    list(APPEND OPENEE_FLAGI_FP -msse2 -mfpmath=sse)
  endif()
  set(OPENEE_OSTRZEZENIA -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wno-sign-conversion)
elseif(MSVC)
  list(APPEND OPENEE_FLAGI_FP /fp:precise /fp:contract-)
  set(OPENEE_OSTRZEZENIA /W4)
endif()
message(STATUS "OpenEE: flagi FP = ${OPENEE_FLAGI_FP}")
