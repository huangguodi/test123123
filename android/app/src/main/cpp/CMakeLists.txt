cmake_minimum_required(VERSION 3.4.1)

project("native_security")

add_library(
    native_security
    SHARED
    native-lib.cpp
)

find_library(
    log-lib
    log
)

target_link_libraries(
    native_security
    ${log-lib}
)
