cmake_minimum_required(VERSION 3.28)

# Windows + V100 port:
# - sm_70 / Volta supports CUDA Toolkit 12.8 or 12.9
# - CUDA 13.x is rejected because offline Volta compilation was removed
# - sm_120a keeps the original Windows/Blackwell path
if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
  set(CMAKE_CUDA_ARCHITECTURES 70 CACHE STRING "CUDA architectures to build")
endif()
if(NOT CMAKE_CUDA_ARCHITECTURES STREQUAL "120a" AND
   NOT CMAKE_CUDA_ARCHITECTURES STREQUAL "70")
  message(FATAL_ERROR
    "NInfer Windows V100 port supports only CMAKE_CUDA_ARCHITECTURES=70 or 120a; got "
    "'${CMAKE_CUDA_ARCHITECTURES}'")
endif()

if(CMAKE_CUDA_ARCHITECTURES STREQUAL "70")
  add_compile_definitions(NINFER_VOLTA_BUILD=1)
endif()

project(ninfer LANGUAGES C CXX CUDA)

option(NINFER_BUILD_APPS "Build the NInfer CLI, server and perplexity evaluator" ON)
option(BUILD_TESTING "Build the NInfer test suite" OFF)
option(NINFER_BUILD_BENCHMARKS "Build the NInfer benchmark binaries" OFF)
option(NINFER_BUILD_PRODUCT_SUPPORT "Build product support (media, logging, prompt input, serve)" ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 20)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

if(CMAKE_CUDA_ARCHITECTURES STREQUAL "120a" AND
   CMAKE_CUDA_COMPILER_VERSION VERSION_LESS 13.1)
  message(FATAL_ERROR
    "sm_120a requires CUDA 13.1 or newer; found CUDA compiler "
    "${CMAKE_CUDA_COMPILER_VERSION}")
endif()

if(CMAKE_CUDA_ARCHITECTURES STREQUAL "70" AND
   CMAKE_CUDA_COMPILER_VERSION VERSION_LESS 12.8)
  message(FATAL_ERROR
    "Tesla V100 / sm_70 requires CUDA Toolkit 12.8 or 12.9; found "
    "${CMAKE_CUDA_COMPILER_VERSION}")
endif()

if(CMAKE_CUDA_ARCHITECTURES STREQUAL "70" AND
   CMAKE_CUDA_COMPILER_VERSION VERSION_GREATER_EQUAL 13.0)
  message(FATAL_ERROR
    "Tesla V100 / sm_70 must be built with CUDA Toolkit 12.8 or 12.9. CUDA 13.x no longer "
    "assembles Volta device code; found ${CMAKE_CUDA_COMPILER_VERSION}")
endif()

if(CMAKE_CUDA_ARCHITECTURES STREQUAL "70")
  include(FetchContent)
  set(CUTLASS_ENABLE_HEADERS_ONLY ON CACHE BOOL "Enable only CUTLASS headers" FORCE)
  set(CUTLASS_ENABLE_TESTS OFF CACHE BOOL "Disable CUTLASS tests" FORCE)
  set(CUTLASS_ENABLE_EXAMPLES OFF CACHE BOOL "Disable CUTLASS examples" FORCE)
  FetchContent_Declare(
    cutlass
    GIT_REPOSITORY https://github.com/nvidia/cutlass.git
    GIT_TAG v4.4.2
    GIT_SHALLOW TRUE
    GIT_PROGRESS TRUE)
  FetchContent_MakeAvailable(cutlass)
endif()

if(MSVC)
  add_compile_definitions(
    CCCL_IGNORE_MSVC_TRADITIONAL_PREPROCESSOR_WARNING
    NOMINMAX)
endif()

include(cmake/Dependencies.cmake)
include(cmake/NinferTargets.cmake)

add_subdirectory(src)
if(NINFER_BUILD_APPS)
  add_subdirectory(apps)
endif()
if(BUILD_TESTING)
  enable_testing()
  add_subdirectory(tests)
endif()
if(NINFER_BUILD_BENCHMARKS)
  add_subdirectory(bench)
endif()
