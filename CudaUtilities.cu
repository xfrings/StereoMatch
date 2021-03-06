///////////////////////////////////////////////////////////////////////////////////////////////////
// Implementation of convolution on GPU
// CudaUtilities.cu
// 
// 
// This file contains helper functions for kernel/wrapper implementations
//
//
// Use GPUERRORCHECK to verify successful completion of CUDA calls
//
// Created: 3-Dec-2014
//
///////////////////////////////////////////////////////////////////////////////////////////////////

#include "CudaUtilities.h"
#include "Error.h"

Timer *profilingTimer;
Timer *profilingTimer2;

bool ZeroCopySupported;


///////////////////////////////////////////////////////////////////////////////////////////////////
//Timer methods
///////////////////////////////////////////////////////////////////////////////////////////////////
void 
Timer::startTimer()
{
   sdkStartTimer(&timerIfc);
}

float 
Timer::stopAndGetTimerValue()
{
   sdkStopTimer(&timerIfc);
   float time = sdkGetTimerValue(&timerIfc);
   sdkResetTimer(&timerIfc);
   return time;
}



///////////////////////////////////////////////////////////////////////////////////////////////////
// GPU memory handling functions
///////////////////////////////////////////////////////////////////////////////////////////////////

// Alloc device memory and set to 0
void
AllocateGPUMemory(void** ptr, unsigned int total_size, bool clear)
{
    GPUERRORCHECK(cudaMalloc(ptr, total_size))
    if (clear) GPUERRORCHECK(cudaMemset(*ptr, 0, total_size))
}

// Copy to device and back
// H->D(HtoD = true) and D->H(HtoD = false)
void
CopyGPUMemory(void* dest, void* src, unsigned int num_elems, bool HtoD)
{
    if (HtoD) GPUERRORCHECK(cudaMemcpy(dest, src, num_elems, cudaMemcpyHostToDevice))
   else  GPUERRORCHECK(cudaMemcpy(dest, src, num_elems, cudaMemcpyDeviceToHost))
}

// Copy to constant memory
void
CopyToGPUConstantMemory(void* dest, void* src, int numBytes)
{
    GPUERRORCHECK(cudaMemcpyToSymbol(dest, src, numBytes, 0, cudaMemcpyHostToDevice))
}

// Free
void
FreeGPUMemory(void* ptr)
{
    GPUERRORCHECK(cudaFree(ptr))
}



///////////////////////////////////////////////////////////////////////////////////////////////////
// Verify results
///////////////////////////////////////////////////////////////////////////////////////////////////
bool 
VerifyComputedData(float* reference, float* data, int numElems)
{
   bool result = compareData(reference, data, numElems, 0.0001f, 0.0f);
   printf("VerifyComputedData: %s\n", (result) ? "DATA OK" : "DATA MISMATCH");
   return result;
}


void
prepareDevice(void)
{
   // Get device properties to check for page-locked memory mapping capability
   int device;
   
   // Zero copy - exploit unified physical CPU-GPU memory by pinning all host memories
   // Doesn't need MemCpy anymore!
   GPUERRORCHECK(cudaSetDeviceFlags(cudaDeviceMapHost))
   
   ZeroCopySupported = false;
   GPUERRORCHECK(cudaGetDeviceCount(&device))

   if (device == 0)
   {
      throw CError("No CUDA GPUs found");
   }

   // Create a context for this process on the GPU - GPU-Attach
   FreeGPUMemory(0); 

   // Just check the first device
   cudaDeviceProp prop;
   GPUERRORCHECK(cudaGetDeviceProperties(&prop, 0))

   // Zero-Copy gives performance increase only when physical DRAM for CPU-GPU is unified
   // Enabled only for TK1 Jetson
   std::string gpuname(prop.name);
   if ((prop.canMapHostMemory == 1) && (gpuname.find("GK20") != std::string::npos)) ZeroCopySupported = true;

   printf("GPU used: %s , Zero-Copy support: %d\n", prop.name, ZeroCopySupported);
   GPUERRORCHECK(cudaSetDevice(0));

   // Setting of L1 cache preference mode is done just before kernel call
}