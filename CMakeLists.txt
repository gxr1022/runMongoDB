cmake_minimum_required(VERSION 3.11)
PROJECT (TEST_MONGODB)

set(CMAKE_INSTALL_INCLUDEDIR "include")

include_directories(
    ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_INCLUDEDIR}/bsoncxx/v_noabi
    ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_INCLUDEDIR}/mongocxx/v_noabi
    /home/gxr/mongodb-run/mongo-cxx-driver-r3.10.1/build/src/bsoncxx/third_party/_deps/core-src/include
    /home/gxr/mongodb-run/test_mongodb/include
    ${GFLAGS_INCLUDE_DIRS}
)



find_package(Boost REQUIRED)
find_package(gflags REQUIRED)

add_executable(run_client src/run_client.cpp include/mongdbBench.h util/affinity.hpp)


target_include_directories(run_client
  PRIVATE ${Boost_INCLUDE_DIRS}
)
target_include_directories(run_client
  PRIVATE ${LIBMONGOCXX_INCLUDE_DIRS}
)
target_link_libraries(run_client
  PRIVATE ${LIBMONGOCXX_LIBRARIES}
)
target_compile_definitions(run_client
  PRIVATE ${LIBMONGOCXX_DEFINITIONS}
)
target_link_libraries(run_client 
 PRIVATE bsoncxx)
 
 target_link_libraries(run_client 
 PRIVATE mongocxx)

#  target_link_libraries(run_client gflags::gflags)


target_link_libraries(run_client
PRIVATE ${GFLAGS_LIBRARIES}
)



# How to use gflags Lib? https://gflags.github.io/gflags/ 


