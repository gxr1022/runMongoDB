#include "mongdbBench.h"
#include <algorithm>
#include <chrono>
#include <iostream>
#include <gflags/gflags.h>
#include <string>

int main(int argc, char *argv[])
{
    google::ParseCommandLineFlags(&argc, &argv, false);
    mongodbBenchmark kv_bench(argc, argv);
    kv_bench.load_and_run();
    return 0;
}



