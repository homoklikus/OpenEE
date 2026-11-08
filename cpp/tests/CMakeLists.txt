# openee_tests – testy natywne Core (bez Godota). Kod 77 = SKIP (brak oryginalnej DLL).
add_executable(openee_tests testy_core.cpp)
target_link_libraries(openee_tests PRIVATE openee_core)
target_compile_definitions(openee_tests PRIVATE
  OPENEE_KATALOG_ZRODEL="${PROJECT_SOURCE_DIR}"
  OPENEE_INSTALACJA_DOMYSLNA="${OPENEE_INSTALACJA}")
target_compile_options(openee_tests PRIVATE ${OPENEE_OSTRZEZENIA})

foreach(grupa trygonometria rng teren ruch odpychanie dll tai determinizm astar astar_gra krok kolizje_takt kolejka scenariusze porownanie_gra mapa walka podsystemy)
  add_test(NAME core_${grupa} COMMAND openee_tests ${grupa})
  set_tests_properties(core_${grupa} PROPERTIES SKIP_RETURN_CODE 77 TIMEOUT 300)
endforeach()
