# openee_core – biblioteka statyczna bez zależności od Godota.
add_library(openee_core STATIC
  src/tablice_dll.cpp
  src/matematyka.cpp
  src/generator.cpp
  src/teren.cpp
  src/fizyka.cpp
  src/maszyna_stanow.cpp
  src/kolizje.cpp
  src/symulacja.cpp
  src/nawigacja.cpp
  src/mapa.cpp
  src/walka.cpp
  src/ulepszenia.cpp
  src/efekty_obszaru.cpp
)
target_include_directories(openee_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_features(openee_core PUBLIC cxx_std_20)
target_compile_options(openee_core PUBLIC ${OPENEE_FLAGI_FP} PRIVATE ${OPENEE_OSTRZEZENIA})
