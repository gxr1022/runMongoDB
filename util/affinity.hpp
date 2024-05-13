#pragma once
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <cassert>
#include <unistd.h>

#include <iostream>
#include <array>
#include <memory>

static size_t get_mem_size(){
  FILE* file = fopen("/proc/self/status", "r");
  size_t result = -1;
  char line[128];

  while (fgets(line, 128, file) != nullptr) {
    if (strncmp(line, "VmRSS:", 6) == 0) {
      int len = strlen(line);

      const char* p = line;
      for (; std::isdigit(*p) == false; ++p) {}

      line[len - 3] = 0;
      result = atoll(p);

      break;
    }
  }
  fclose(file);
  return result;
}
static size_t get_stable_mem_size(){
  auto mem_size = get_mem_size();
  std::cout << "mem_size is :" << mem_size << std::endl;
  std::cout << "wait for mem_size to be stable" << std::endl;
  sleep(2);
  while (std::abs((long long)get_mem_size()-(long long )mem_size) > 10000){
    mem_size = get_mem_size();
    std::cout << "mem_size is :" << mem_size << std::endl;
    std::cout << "wait for mem_size to be stable" << std::endl;
    std::cout << "sleep .." << std::endl;
    sleep(2);
  }
  return mem_size;
}

// https://stackoverflow.com/questions/478898/how-do-i-execute-a-command-and-get-the-output-of-the-command-within-c-using-po
std::string exec(const char* cmd) {
  std::array<char, 128> buffer;
  std::string result;
  std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd, "r"), pclose);
  if (!pipe) {
    throw std::runtime_error("popen() failed!");
  }
  while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
    result += buffer.data();
  }
  return result;
}

void set_affinity(uint64_t i){
  cpu_set_t mask;
  CPU_ZERO(&mask);
  CPU_SET(i, &mask);
  if (sched_setaffinity(0, sizeof(cpu_set_t), &mask) == -1) {
    std::cout << "sched_setaffinity" << std::endl;
    assert(false);
  }
}

void print_affinity() {
  cpu_set_t mask;
  long nproc, i;

  if (sched_getaffinity(0, sizeof(cpu_set_t), &mask) == -1) {
    perror("sched_getaffinity");
    assert(false);
  }
  nproc = sysconf(_SC_NPROCESSORS_ONLN);
  printf("sched_getaffinity = ");
  for (i = 0; i < nproc; i++) {
    printf("%d ", CPU_ISSET(i, &mask));
  }
  printf("\n");
}


typedef struct barrier {
    pthread_cond_t complete;
    pthread_mutex_t mutex;
    int count;
    int crossing;
} barrier_t;


void barrier_init(barrier_t *b, int n) {
    pthread_cond_init(&b->complete, NULL);
    pthread_mutex_init(&b->mutex, NULL);
    b->count = n;
    b->crossing = 0;
}

void barrier_cross(barrier_t *b) {
    pthread_mutex_lock(&b->mutex);
    b->crossing++;
    if (b->crossing < b->count) {
        pthread_cond_wait(&b->complete, &b->mutex);
    } else {
        pthread_cond_broadcast(&b->complete);
        b->crossing = 0;
    }
    pthread_mutex_unlock(&b->mutex);
}