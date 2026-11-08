# OpenEE – natywny rdzeń symulacji (C++20) i integracja z Godot przez GDExtension (etap 28).
# Budowanie: docs/cpp/BUDOWANIE.md.  Cele: openee_core, openee_tests, openee_gdextension.
cmake_minimum_required(VERSION 3.22)
project(OpenEE VERSION 0.6.0 LANGUAGES CXX)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Typ budowania (Debug/Release)" FORCE)
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)          # -std=c++20, nie gnu++20 (domyślne -ffp-contract=fast w trybie GNU)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(OPENEE_TESTY "Buduj testy natywne (openee_tests, CTest)" ON)
option(OPENEE_GDEXTENSION "Buduj bibliotekę GDExtension (wymaga cpp/thirdparty/godot-cpp)" ON)
set(OPENEE_INSTALACJA "" CACHE PATH
    "Katalog instalacji EE Gold (zawiera 'Empire Earth' i 'Empire Earth - The Art of Conquest') – tylko testy z DLL")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cpp/cmake")
include(OpenEEFlagi)

add_subdirectory(cpp/core)

if(OPENEE_TESTY)
  enable_testing()
  add_subdirectory(cpp/tests)
  add_subdirectory(cpp/tools)   # etap 30: openee_porownaj (pomiar oryginału → Core)
endif()

if(OPENEE_GDEXTENSION)
  add_subdirectory(cpp/gdextension)
endif()
