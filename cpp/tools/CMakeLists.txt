# openee_porownaj – porównanie serii pomiarowej oryginału z Core (etap 30; narzedzia/titan/pomiar_core.py).
add_executable(openee_porownaj openee_porownaj.cpp)
target_include_directories(openee_porownaj PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../tests)
target_link_libraries(openee_porownaj PRIVATE openee_core)
target_compile_options(openee_porownaj PRIVATE ${OPENEE_OSTRZEZENIA})
