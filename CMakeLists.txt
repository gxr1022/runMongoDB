cmake_minimum_required(VERSION 3.11)
PROJECT (TEST_MONGODB)
# SET (SRC_LIST test.cpp)

set(CMAKE_INSTALL_INCLUDEDIR "include")

include_directories(
    ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_INCLUDEDIR}/bsoncxx/v_noabi
    ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_INCLUDEDIR}/mongocxx/v_noabi
    /mnt/nvme0/home/gxr/mongdb-run/mongo-cxx-driver-r3.10.1/build/src/bsoncxx/third_party/_deps/core-src/include
)

# find_package(libmongocxx REQUIRED)
add_executable(test test.cpp)
find_package(Boost REQUIRED)
target_include_directories(test
  PRIVATE ${Boost_INCLUDE_DIRS}
)
target_include_directories(test
  PRIVATE ${LIBMONGOCXX_INCLUDE_DIRS}
)
target_link_libraries(test
  PRIVATE ${LIBMONGOCXX_LIBRARIES}
)
target_compile_definitions(test
  PRIVATE ${LIBMONGOCXX_DEFINITIONS}
)
target_link_libraries(test 
 PRIVATE bsoncxx)
 
 target_link_libraries(test 
 PRIVATE mongocxx)
