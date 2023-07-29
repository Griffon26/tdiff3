include(FetchContent)
FetchContent_Declare(
  googletest
  GIT_REPOSITORY https://github.com/google/googletest.git
  GIT_TAG        v1.13.0
)
FetchContent_MakeAvailable(googletest)

add_executable(test.tdiff3 test_overlap.cpp)
target_link_libraries(test.tdiff3 PRIVATE GTest::gtest_main)

