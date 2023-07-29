cmake_minimum_required(VERSION 3.1...3.26)

project(
  tdiff3
  VERSION 0.1
  LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED On)
set(CMAKE_CXX_EXTENSIONS Off)


add_subdirectory(src)
add_subdirectory(test)

