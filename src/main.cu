#include <float.h>
#include <stdio.h>

#include "structs.h"

__device__ __constant__ unsigned int num_photons_dc[1];
__device__ __constant__ unsigned int n_layers_dc[1];
__device__ __constant__ unsigned int start_weight_dc[1];
__device__ __constant__ LayerStruct layers_dc[MAX_LAYERS];
__device__ __constant__ DetStruct det_dc[1];

#include "memory.cu"
#include "io.cu"
#include "randomgen.cu"
#include "transport.cu"


void DoOneSimulation(SimulationStruct * simulation, unsigned long long * x, unsigned int * a) {
  MemStruct DeviceMem;
  MemStruct HostMem;
  unsigned int threads_active_total = 1;
  unsigned int i, ii;

  cudaError_t cudastat;
  clock_t time1, time2;

  time1 = clock();

  HostMem.x = x;
  HostMem.a = a;

  InitMemStructs( & HostMem, & DeviceMem, simulation);
  InitDCMem(simulation);

  dim3 dimBlock(NUM_THREADS_PER_BLOCK);
  dim3 dimGrid(NUM_BLOCKS);

  LaunchPhoton_Global <<< dimGrid, dimBlock >>> (DeviceMem);
  cudaDeviceSynchronize(); 
  cudastat = cudaGetLastError();
  if (cudastat) printf("Error code=%i, %s.\n", cudastat, cudaGetErrorString(cudastat));

  printf("ignoreAdetection = %d\n\n", simulation -> ignoreAdetection);

  i = 0;
  while (threads_active_total > 0) {
    i++;
    if (simulation -> ignoreAdetection == 1) {
      MCd < 1 > <<< dimGrid, dimBlock >>> (DeviceMem);
    } else {
      MCd < 0 > <<< dimGrid, dimBlock >>> (DeviceMem);
    }
    cudaDeviceSynchronize(); 
    cudastat = cudaGetLastError();
    if (cudastat) printf("Error code=%i, %s.\n", cudastat, cudaGetErrorString(cudastat));

    cudaMemcpy(HostMem.thread_active, DeviceMem.thread_active, NUM_THREADS * sizeof(unsigned int), cudaMemcpyDeviceToHost);
    threads_active_total = 0;
    for (ii = 0; ii < NUM_THREADS; ii++) threads_active_total += HostMem.thread_active[ii];

    cudaMemcpy(HostMem.num_terminated_photons, DeviceMem.num_terminated_photons, sizeof(unsigned int), cudaMemcpyDeviceToHost);

    printf("Run %u, Number of photons terminated %u, Threads active %u\n", i, * HostMem.num_terminated_photons, threads_active_total);
  }
  printf("Simulation done!\n");

  CopyDeviceToHostMem( & HostMem, & DeviceMem, simulation);

  time2 = clock();

  printf("Simulation time: %.2f sec\n", (double)(time2 - time1) / CLOCKS_PER_SEC);

  Write_Simulation_Results( & HostMem, simulation, time2 - time1);

  FreeMemStructs( & HostMem, & DeviceMem);
}

int main(int argc, char * argv[]) {
  int i;
  SimulationStruct * simulations;
  int n_simulations;
  unsigned long long seed = (unsigned long long) time(NULL);
  int ignoreAdetection = 0;
  char * filename;

  if (argc < 2) {
    printf("Not enough input arguments!\n");
    return 1;
  } else {
    filename = argv[1];
  }

  if (interpret_arg(argc, argv, & seed, & ignoreAdetection)) return 1;

  n_simulations = read_simulation_data(filename, & simulations, ignoreAdetection);

  if (n_simulations == 0) {
    printf("Something wrong with read_simulation_data!\n");
    return 1;
  } else {
    printf("Read %d simulations\n", n_simulations);
  }

  unsigned long long x[NUM_THREADS];
  unsigned int a[NUM_THREADS];

  if (init_RNG(x, a, NUM_THREADS, "trueprimes.txt", seed)) return 1;

  for (i = 0; i < n_simulations; i++) {
    DoOneSimulation( & simulations[i], x, a);
  }

  FreeSimulationStruct(simulations, n_simulations);

  return 0;
}