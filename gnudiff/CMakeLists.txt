add_library(gnudiff OBJECT
    src/analyze.c
    src/util.c
    stub/diff.c
    stub/normal.c
    stub/zalloc.c
)

target_include_directories(gnudiff
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    PRIVATE
    src
    stub
)

