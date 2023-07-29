add_executable(tdiff3
    common.cpp
    difflistgenerator.cpp
    main.cpp
    mmappedfilelineprovider.cpp
)

target_link_libraries(tdiff3
    PRIVATE
    gnudiff
)

