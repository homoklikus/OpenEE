# openee_gdextension – cienka warstwa integracji OpenEE Core z Godot (godot-cpp, przypięta wersja).
# godot-cpp: submoduł cpp/thirdparty/godot-cpp (tag 10.0.0-stable, 507ed9d) albo OPENEE_GODOT_CPP_DIR.
set(OPENEE_GODOT_CPP_DIR "${PROJECT_SOURCE_DIR}/cpp/thirdparty/godot-cpp" CACHE PATH "Katalog źródeł godot-cpp")
if(NOT EXISTS "${OPENEE_GODOT_CPP_DIR}/CMakeLists.txt")
  message(FATAL_ERROR
    "Brak godot-cpp w ${OPENEE_GODOT_CPP_DIR}.\n"
    "Pobierz submoduł:  git submodule update --init cpp/thirdparty/godot-cpp\n"
    "albo wskaż katalog: -DOPENEE_GODOT_CPP_DIR=...  albo zbuduj bez integracji: -DOPENEE_GDEXTENSION=OFF")
endif()

# Wersja API = wersja Godota projektu (config/features „4.7”, binarka 4.7.2).
set(GODOTCPP_API_VERSION "4.7" CACHE STRING "Docelowa wersja API Godota")
set(GODOTCPP_BUILD_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/profil_godot_cpp.json" CACHE PATH "Profil klas godot-cpp")
set(GODOTCPP_DISABLE_EXCEPTIONS OFF CACHE BOOL "OpenEE Core używa wyjątków standardowych" FORCE)
if(NOT GODOTCPP_TARGET)
  set(GODOTCPP_TARGET "template_debug" CACHE STRING "template_debug (edytor/uruchamianie z projektu) albo template_release")
endif()
add_subdirectory("${OPENEE_GODOT_CPP_DIR}" "${CMAKE_BINARY_DIR}/godot-cpp" EXCLUDE_FROM_ALL)

add_library(openee_gdextension SHARED src/rejestracja.cpp src/openee_symulacja.cpp)
target_link_libraries(openee_gdextension PRIVATE openee_core godot-cpp)
get_target_property(GODOTCPP_SUFFIX godot-cpp GODOTCPP_SUFFIX)
set_target_properties(openee_gdextension PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  PREFIX "lib"
  OUTPUT_NAME "openee${GODOTCPP_SUFFIX}"
  LIBRARY_OUTPUT_DIRECTORY "${PROJECT_SOURCE_DIR}/godot/bin"
  RUNTIME_OUTPUT_DIRECTORY "${PROJECT_SOURCE_DIR}/godot/bin")
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  # libstdc++ statycznie: biblioteka działa bez zgodnej wersji libstdc++ w systemie gracza
  target_link_options(openee_gdextension PRIVATE -static-libstdc++ -static-libgcc -Wl,--no-undefined)
endif()
