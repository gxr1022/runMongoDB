#include <iostream>
#include <iomanip>
#include <chrono>
#include <unordered_map>
#include <vector>
#include <map>
#include <fstream>
#include <unistd.h>
#include <cassert>
#include <gflags/gflags.h>
#include <cstring>
#include <array>
#include <sched.h>
#include <algorithm>
#include <random>
#include <sstream>
#include <malloc.h>
#include <mutex>
#include <thread>

#include <bsoncxx/builder/basic/document.hpp>
#include <bsoncxx/json.hpp>
#include <mongocxx/client.hpp>
#include <mongocxx/instance.hpp>
#include <mongocxx/stdx.hpp>
#include <mongocxx/uri.hpp>

#include "../util/affinity.hpp"

// Redefine assert after including headers. Release builds may undefine the assert macro and result
// in -Wunused-variable warnings.
#if defined(NDEBUG) || !defined(assert)
#undef assert
#define assert(stmt)                                                                         \
    do                                                                                       \
    {                                                                                        \
        if (!(stmt))                                                                         \
        {                                                                                    \
            std::cerr << "Assert on line " << __LINE__ << " failed: " << #stmt << std::endl; \
            abort();                                                                         \
        }                                                                                    \
    } while (0)
#endif

using bsoncxx::builder::basic::kvp;
using bsoncxx::builder::basic::make_array;
using bsoncxx::builder::basic::make_document;

DEFINE_uint64(str_key_size, 16, "size of key (bytes)");
DEFINE_uint64(str_value_size, 16, "size of value (bytes)");
// DEFINE_string(mode, "tes", "workload type(default, ycsb)");

DEFINE_string(load_file, "NULL", "load workload file name");
DEFINE_string(run_file, "NULL", "run workload file name");

DEFINE_string(URI, "mongodb://localhost:27017", "the uri of mongoDB");
DEFINE_string(client_name, "mydb_1", "the name of client");
DEFINE_string(collection_name, "test_1", "the name of collection");
DEFINE_string(report_prefix, "[report] ", "prefix of report data");
DEFINE_uint64(num_threads, 1, "the number of threads");

DEFINE_string(core_binding, "", "Core Binding, example : 0,1,16,17");

typedef uint64_t mongo_key_t;
typedef uint64_t hash_value_t;

typedef enum OP_TYPE
{
    OP_UNKNOWN,
    OP_INSERT,
    OP_READ,
    OP_SCAN,
    OP_UPDATE,
    OP_DELETE,
    OP_READMODIFYWRITE
} op_type_t;

typedef struct StrOperation
{
    op_type_t op;
    std::string key;
    std::string value; // if op == OP_READ, value is the groundtrue result
} str_operation_t;

void standard_report(const std::string &prefix, const std::string &name, const std::string &value)
{
    std::cout << FLAGS_report_prefix << prefix + "_" << name << " : " << value << std::endl;
}

class mongodbBenchmark
{
private:
    /* data */
public:
    // uint64_t key_size;
    // uint64_t value_size;

    uint64_t num_of_load_ops;
    uint64_t num_of_run_ops;

    uint64_t num_threads;

    std::vector<str_operation_t> str_load_ops; // store load ops
    std::vector<str_operation_t> str_run_ops;  // store run ops

    std::string load_workload_file_name;
    std::string run_workload_file_name;

    std::string client_name;
    std::string collection_name;

    std::string load_benchmark_prefix = "load";
    std::string run_benchmark_prefix = "run";

    std::string core_binding;

    // uint64_t duration_ns;

    mongodbBenchmark(int argc, char **argv);
    ~mongodbBenchmark();
    op_type_t get_op_type_from_string(const std::string &s);
    std::string from_uint64_to_hex_string_w16(uint64_t value);

    void clientThread(int thread_id,uint64_t core_id,uint64_t num_of_ops_per_thread);
    void load_and_run();

    void benchmark_report(const std::string benchmark_prefix, const std::string &name, const std::string &value)
    {
        standard_report(benchmark_prefix, name, value);
    }
};

op_type_t mongodbBenchmark::get_op_type_from_string(const std::string &s)
{
    if (s == "INSERT")
    {
        return OP_INSERT;
    }
    else if (s == "READ")
    {
        return OP_READ;
    }
    else if (s == "SCAN")
    {
        return OP_SCAN;
    }
    else if (s == "UPDATE")
    {
        return OP_UPDATE;
    }
    else if (s == "DELETE")
    {
        return OP_DELETE;
    }
    else if (s == "READMODIFYWRITE")
    {
        return OP_READMODIFYWRITE;
    }
    return OP_UNKNOWN;
}

mongodbBenchmark::mongodbBenchmark(int argc, char **argv)
{
    google::ParseCommandLineFlags(&argc, &argv, false);

    this->client_name = FLAGS_client_name;
    this->collection_name = FLAGS_client_name;
    this->num_threads = FLAGS_num_threads;
    this->core_binding = FLAGS_core_binding;

    uint64_t key_size = FLAGS_str_key_size;
    uint64_t value_size = FLAGS_str_value_size;

    num_of_load_ops = 0;
    num_of_run_ops = 0;

    std::string common_value;
    for (int i = 0; i < value_size; i++)
    {
        common_value += (char)('a' + (i % 26));
    }
    std::cout << common_value << std::endl;
    std::cout << common_value.size() << std::endl;

    std::string op_string;
    mongo_key_t mongo_key;
    std::cout << "reading workload files ..." << std::endl;
    // init workload from files

    // load
    std::string load_filename = FLAGS_load_file;
    std::cout << "load_filename : " << load_filename << std::endl;
    load_workload_file_name = load_filename;

    // readfile
    auto file_start_time = std::chrono::system_clock::now();
    std::ifstream load_file_stream(load_filename);
    while (load_file_stream >> op_string >> mongo_key)
    {
        op_type_t op_type = get_op_type_from_string(op_string);
        // std::cout << "[DEBUG] OP : " << op_string << " " << mongo_key << std::endl;
        if (op_type == OP_UNKNOWN)
        {
            std::cout << "Warning : Unknown OP : " << op_string << " " << mongo_key << std::endl;
            continue;
        }
        str_load_ops.push_back(str_operation_t{
            op_type,
            from_uint64_to_hex_string_w16(mongo_key),
            common_value});
    }

    auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::system_clock::now() - file_start_time).count();
    std::cout << "read load file needs: " << duration << " s " << std::endl;

    // run
    std::string run_filename = FLAGS_run_file;
    std::cout << "run_filename : " << run_filename << std::endl;
    run_workload_file_name = run_filename;
    // readfile

    file_start_time = std::chrono::system_clock::now();
    std::ifstream run_file_stream(run_filename);
    while (run_file_stream >> op_string >> mongo_key)
    {
        op_type_t op_type = get_op_type_from_string(op_string);
        // std::cout << "[DEBUG] OP : " << op_string << " " << mongo_key << std::endl;
        if (op_type == OP_UNKNOWN)
        {
            std::cout << "Warning : Unknown OP : " << op_string << " " << mongo_key << std::endl;
            continue;
        }
        str_run_ops.push_back(str_operation_t{
            op_type,
            from_uint64_to_hex_string_w16(mongo_key),
            common_value});
    }
    duration = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::system_clock::now() - file_start_time).count();
    std::cout << "read run file needs: " << duration << " s " << std::endl;

    num_of_load_ops = str_load_ops.size();
    std::cout << "num_of_load_ops is " << num_of_load_ops << std::endl;
    num_of_run_ops = str_run_ops.size();
    std::cout << "num_of_run_ops is " << num_of_run_ops << std::endl;
}

mongodbBenchmark::~mongodbBenchmark()
{
}

std::string mongodbBenchmark::from_uint64_to_hex_string_w16(uint64_t value)
{
    std::stringstream ss;
    ss << std::setfill('0') << std::setw(16) << std::hex << value;
    return ss.str();
}

void mongodbBenchmark::load_and_run()
{

    mongocxx::instance instance{}; // This should be done only once.
    
    // Create and start client threads
    std::vector<std::thread> threads;
    std::vector<int> core_ids;
    if (core_binding.size() != 0)
    {
        std::stringstream ss(core_binding);
        std::string item;
        while (std::getline(ss, item, ','))
        {
            core_ids.push_back(std::stoi(item));
            // std::cout<<std::stoi(item)<<" ";
        }
        // std::cout<<std::endl;
        // if (core_ids.size() != num_threads)
        // {
        //     std::cout << "WARN !! " << "core_ids.size() is not equal to number of threads" << std::endl;
        // }
    }

    
    uint64_t num_of_ops_per_thread=num_of_load_ops/num_threads;
    for (int i = 0; i < num_threads; ++i)
    {
        uint64_t core_id=core_ids[i];
        // std::cout<<core_id<<std::endl;
        threads.emplace_back([this, i, core_id, num_of_ops_per_thread]()
                             { this->clientThread(i, core_id, num_of_ops_per_thread); });
    }

    // Wait for all client threads to finish
    auto start_time = std::chrono::high_resolution_clock::now();
    for (auto &thread : threads)
    {
        thread.join();
    }
    auto duration_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::system_clock::now() - start_time).count();
    std::cout << "All clients run done needs: " << duration_ns << " ns " << std::endl;

    double duration_s = duration_ns / (1000.0 * 1000 * 1000);
    double throughput = num_of_load_ops * num_threads / duration_s;
    double average_latency_ns = (double)duration_ns / num_of_load_ops / num_threads;

    benchmark_report(load_benchmark_prefix, "overall_duration_ns", std::to_string(duration_ns));
    benchmark_report(load_benchmark_prefix, "overall_duration_s", std::to_string(duration_s));
    benchmark_report(load_benchmark_prefix, "overall_throughput", std::to_string(throughput));
    benchmark_report(load_benchmark_prefix, "overall_average_latency_ns", std::to_string(average_latency_ns));
}

void mongodbBenchmark::clientThread(int thread_id, uint64_t core_id,uint64_t num_of_ops_per_thread)
{
    set_affinity(core_id);
    mongocxx::uri uri(FLAGS_URI);
    mongocxx::client client(uri);

    auto db = client[client_name];
    auto collection = db[collection_name];

    // First choice: I can make document with only one KV pair.

    // Create a Document
    {
        auto doc_value = make_document(
            kvp("name", "MongoDB"),
            kvp("type", "database"));

        auto doc_view = doc_value.view();
        auto element = doc_view["name"];
        assert(element.type() == bsoncxx::type::k_string);
        auto name = element.get_string().value; // For C++ driver version < 3.7.0, use get_utf8()
        assert(0 == name.compare("MongoDB"));
    }

    int start_index=thread_id*num_of_ops_per_thread;
    int end_index=(thread_id+1)*num_of_ops_per_thread;
    
    // Now let's start running YCSB benchmarks ……
    auto load_start_time = std::chrono::high_resolution_clock::now();
    for (int i = start_index; i < end_index && i < str_load_ops.size(); ++i) {
        auto ele=str_load_ops[i];
        switch (ele.op)
        {
        case OP_INSERT:
        {
            auto insert_one_result = collection.insert_one(make_document(kvp(ele.key, ele.value)));
            break;
        }
        case OP_READ:
        {
            // To know if the record include values.
            auto find_one_result = collection.find_one(make_document(kvp(ele.key, ele.value)));
            // IMPORTANT!!
            // ele.value = read_result;
            break;
        }
        case OP_UPDATE:
        {
            auto update_one_result = collection.update_one(
                make_document(kvp(ele.key, ele.value)),
                make_document(kvp("$set", make_document(kvp(ele.key, ele.value)))));
            // std::cout << "Matched documents: " << update_one_result->matched_count() << std::endl;
            // std::cout << "Modified documents: " << update_one_result->modified_count() << std::endl;
            break;
        }
        case OP_DELETE:
        {
            auto delete_one_result = collection.delete_one(make_document(kvp(ele.key, ele.value)));
            break;
        }
        default:
        {
            std::cout << "Unknown OP In Load : " << ele.op << std::endl;
            break;
        }
        }
        
    }

    auto duration_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::system_clock::now() - load_start_time).count();
    std::cout << "Load workloads needs: " << duration_ns << " ns " << std::endl;

    double duration_s = duration_ns / (1000.0 * 1000 * 1000);
    double throughput = num_of_ops_per_thread / duration_s;
    double average_latency_ns = (double)duration_ns / num_of_ops_per_thread;

    benchmark_report(load_benchmark_prefix, "thread_ID", std::to_string(thread_id));
    benchmark_report(load_benchmark_prefix, "duration_ns", std::to_string(duration_ns));
    benchmark_report(load_benchmark_prefix, "duration_s", std::to_string(duration_s));
    benchmark_report(load_benchmark_prefix, "throughput", std::to_string(throughput));
    benchmark_report(load_benchmark_prefix, "average_latency_ns", std::to_string(average_latency_ns));

    // run
    // auto run_start_time = std::chrono::high_resolution_clock::now();
    // for (auto ele : str_run_ops)
    // {
    //     switch (ele.op)
    //     {
    //     case OP_INSERT:
    //     {

    //         auto insert_one_result = collection.insert_one(make_document(kvp(ele.key, ele.value)));
    //         break;
    //     }
    //     case OP_READ:
    //     {
    //         // To know if the record include values.
    //         auto find_one_result = collection.find_one(make_document(kvp(ele.key, ele.value)));
    //         // IMPORTANT!!
    //         // ele.value = read_result;
    //         break;
    //     }
    //     case OP_UPDATE:
    //     {
    //         auto update_one_result = collection.update_one(
    //             make_document(kvp(ele.key, ele.value)),
    //             make_document(kvp("$set", make_document(kvp(ele.key, ele.value)))));
    //         // std::cout << "Matched documents: " << update_one_result->matched_count() << std::endl;
    //         // std::cout << "Modified documents: " << update_one_result->modified_count() << std::endl;
    //         break;
    //     }
    //     case OP_DELETE:
    //     {
    //         auto delete_one_result = collection.delete_one(make_document(kvp(ele.key, ele.value)));
    //         break;
    //     }
    //     default:
    //     {
    //         std::cout << "Unknown OP In Load : " << ele.op << std::endl;
    //         break;
    //     }
    //     }
    // }
    // duration_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::system_clock::now() - run_start_time).count();
    // std::cout << "Run workloads needs: " << duration_ns << " ns " << std::endl;

    // duration_s = duration_ns / (1000.0 * 1000 * 1000);
    // throughput = num_of_run_ops / duration_s;
    // average_latency_ns = (double)duration_ns / num_of_run_ops;

    // benchmark_report(run_benchmark_prefix, "duration_ns", std::to_string(duration_ns));
    // benchmark_report(run_benchmark_prefix, "duration_s", std::to_string(duration_s));
    // benchmark_report(run_benchmark_prefix, "throughput", std::to_string(throughput));
    // benchmark_report(run_benchmark_prefix, "average_latency_ns", std::to_string(average_latency_ns));

    // collection.drop();
}
