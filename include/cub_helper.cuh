#pragma once
#include <quda_constants.h>
#include <float_vector.h>
#include <comm_quda.h>
#include <blas_quda.h>

using namespace quda;

// ensures we use shfl_sync and not shfl when compiling with clang
#if defined(__clang__) && defined(__CUDA__) && CUDA_VERSION >= 9000
#define CUB_USE_COOPERATIVE_GROUPS
#endif

#ifdef __CUDACC_RTC__
// WAR for CUDA < 11 which prevents the use of cuda_fp16.h in cub with nvrtc
struct __half { };
#endif

#include <cub/block/block_reduce.cuh>

#if __COMPUTE_CAPABILITY__ >= 300
#include <generics/shfl.h>
#endif

/**
   @file cub_helper.cuh

   @section Description

   Provides helper functors for custom datatypes for cub algorithms.
 */

namespace quda {

  /**
     struct which acts as a wrapper to a vector of data.
   */
  template <typename scalar, int n>
  struct vector_type {
    scalar data[n];
    __device__ __host__ inline scalar& operator[](int i) { return data[i]; }
    __device__ __host__ inline const scalar& operator[](int i) const { return data[i]; }
    __device__ __host__ inline static constexpr int size() { return n; }
    __device__ __host__ inline void operator+=(const vector_type &a) {
#pragma unroll
      for (int i=0; i<n; i++) data[i] += a[i];
    }
    __device__ __host__ inline void operator=(const vector_type &a) {
#pragma unroll
      for (int i=0; i<n; i++) data[i] = a[i];
    }
    __device__ __host__ vector_type() {
#pragma unroll
      for (int i=0; i<n; i++) zero(data[i]);
    }
  };

  template<typename scalar, int n>
  __device__ __host__ inline void zero(vector_type<scalar,n> &v) {
#pragma unroll
    for (int i=0; i<n; i++) zero(v.data[i]);
  }

  template<typename scalar, int n>
  __device__ __host__ inline vector_type<scalar,n> operator+(const vector_type<scalar,n> &a, const vector_type<scalar,n> &b) {
    vector_type<scalar,n> c;
#pragma unroll
    for (int i=0; i<n; i++) c[i] = a[i] + b[i];
    return c;
  }


  template <typename T>
  struct ReduceArg {
    T *partial;
    T *result_d;
    T *result_h;
    ReduceArg() :
      partial(static_cast<T*>(blas::getDeviceReduceBuffer())),
      result_d(static_cast<T*>(blas::getMappedHostReduceBuffer())),
      result_h(static_cast<T*>(blas::getHostReduceBuffer()))
    {
      //  write reduction to GPU memory if asynchronous
      if (commAsyncReduction()) result_d = partial;
    }

  };

#ifdef QUAD_SUM
  __device__ __host__ inline void zero(doubledouble &x) { x.a.x = 0.0; x.a.y = 0.0; }
  __device__ __host__ inline void zero(doubledouble2 &x) { zero(x.x); zero(x.y); }
  __device__ __host__ inline void zero(doubledouble3 &x) { zero(x.x); zero(x.y); zero(x.z); }
#endif

  __device__ unsigned int count[QUDA_MAX_MULTI_REDUCE] = { };
  __shared__ bool isLastBlockDone;

  template <int block_size_x, int block_size_y, typename T, bool do_sum=true, typename Reducer=cub::Sum>
  __device__ inline void reduce2d(ReduceArg<T> arg, const T &in, const int idx=0) {

    typedef cub::BlockReduce<T, block_size_x, cub::BLOCK_REDUCE_WARP_REDUCTIONS, block_size_y> BlockReduce;
    __shared__ typename BlockReduce::TempStorage cub_tmp;

    Reducer r;
    T aggregate = (do_sum ? BlockReduce(cub_tmp).Sum(in) : BlockReduce(cub_tmp).Reduce(in, r));

    if (threadIdx.x == 0 && threadIdx.y == 0) {
      arg.partial[idx*gridDim.x + blockIdx.x] = aggregate;
      __threadfence(); // flush result

      // increment global block counter
      unsigned int value = atomicInc(&count[idx], gridDim.x);

      // determine if last block
      isLastBlockDone = (value == (gridDim.x-1));
    }

    __syncthreads();

    // finish the reduction if last block
    if (isLastBlockDone) {
      unsigned int i = threadIdx.y*block_size_x + threadIdx.x;
      T sum;
      zero(sum);
      while (i<gridDim.x) {
        sum = r(sum, arg.partial[idx*gridDim.x + i]);
	//sum += arg.partial[idx*gridDim.x + i];
	i += block_size_x*block_size_y;
      }

      sum = (do_sum ? BlockReduce(cub_tmp).Sum(sum) : BlockReduce(cub_tmp).Reduce(sum,r));

      // write out the final reduced value
      if (threadIdx.y*block_size_x + threadIdx.x == 0) {
	arg.result_d[idx] = sum;
	count[idx] = 0; // set to zero for next time
      }
    }
  }

  template <int block_size, typename T, bool do_sum = true, typename Reducer = cub::Sum>
  __device__ inline void reduce(ReduceArg<T> arg, const T &in, const int idx=0) { reduce2d<block_size, 1, T, do_sum, Reducer>(arg, in, idx); }


  __shared__ volatile bool isLastWarpDone[16];

#if __COMPUTE_CAPABILITY__ >= 300

  /**
     @brief Do a warp reduction, followed by a global reduction to the
     idx bin.  This function is only enabled on Kepler and above.
     @param arg Meta data needed for reduction
     @param in Input data in registers for reduction
     @param idx Bin in which the global (inter-CTA) reduction is done
   */
  template <typename T>
  __device__ inline void warp_reduce(ReduceArg<T> arg, const T &in, const int idx=0) {

    const int warp_size = 32;
    T aggregate = in;
#pragma unroll
    for (int offset = warp_size/2; offset > 0; offset /= 2) aggregate += __shfl_down(aggregate, offset);

    if (threadIdx.x == 0) {
      arg.partial[idx*gridDim.x + blockIdx.x] = aggregate;
      __threadfence(); // flush result

      // increment global block counter
      unsigned int value = atomicInc(&count[idx], gridDim.x);

      // determine if last warp
      if (threadIdx.y == 0) isLastBlockDone = (value == (gridDim.x-1));
    }

    __syncthreads();

    // finish the reduction if last block
    if (isLastBlockDone) {
      unsigned int i = threadIdx.x;
      T sum;
      zero(sum);
      while (i<gridDim.x) {
	sum += arg.partial[idx*gridDim.x + i];
	i += warp_size;
      }

#pragma unroll
      for (int offset = warp_size/2; offset > 0; offset /= 2) sum += __shfl_down(sum, offset);

      // write out the final reduced value
      if (threadIdx.x == 0) {
	arg.result_d[idx] = sum;
	count[idx] = 0; // set to zero for next time
      }
    }
  }
#endif // __COMPUTE_CAPABILITY__ >= 300

  /**
     functor that defines how to do a row-wise vector reduction
   */
  template <typename T>
  struct reduce_vector {
    __device__ __host__ inline T operator()(const T &a, const T &b) {
      T sum;
      for (int i=0; i<sum.size(); i++) sum[i] = a[i] + b[i];
      return sum;
    }
  };

  template <int block_size_x, int block_size_y, typename T>
  __device__ inline void reduceRow(ReduceArg<T> arg, const T &in) {

    typedef vector_type<T,block_size_y> vector;
    typedef cub::BlockReduce<vector, block_size_x, cub::BLOCK_REDUCE_WARP_REDUCTIONS, block_size_y> BlockReduce;
    constexpr int n_word = sizeof(T) / sizeof(int);

    __shared__ union {
      typename BlockReduce::TempStorage cub;
      int exchange[n_word*block_size_x*block_size_y];
    } shared;

    // first move all data at y>0 to y=0 slice and pack in a vector of length block_size_y
    if (threadIdx.y > 0) {
      for (int i=0; i<n_word; i++)
	shared.exchange[(i * block_size_y + threadIdx.y)*block_size_x + threadIdx.x] = reinterpret_cast<const int*>(&in)[i];
    }

    __syncthreads();

    vector data;

    if (threadIdx.y == 0) {
      data[0] = in;
      for (int y=1; y<block_size_y; y++)
	for (int i=0; i<n_word; i++)
	  reinterpret_cast<int*>(&data[y])[i] = shared.exchange[(i * block_size_y + y)*block_size_x + threadIdx.x];
    }

    __syncthreads();

    reduce_vector<vector> reducer;

    vector aggregate = BlockReduce(shared.cub).Reduce(data, reducer, block_size_x);

    if (threadIdx.x == 0 && threadIdx.y == 0) {
      reinterpret_cast<vector*>(arg.partial)[blockIdx.x] = aggregate;
      __threadfence(); // flush result

      // increment global block counter
      unsigned int value = atomicInc(&count[0], gridDim.x);

      // determine if last block
      isLastBlockDone = (value == (gridDim.x-1));
    }

    __syncthreads();

    // finish the reduction if last block
    if (isLastBlockDone) {
      vector sum;
      if (threadIdx.y == 0) { // only use x-row to do final reduction since we've only allocated space for this
	unsigned int i = threadIdx.x;
	while (i < gridDim.x) {
	  sum += reinterpret_cast<vector*>(arg.partial)[i];
	  i += block_size_x;
	}
      }

      sum = BlockReduce(shared.cub).Reduce(sum, reducer, block_size_x);

      // write out the final reduced value
      if (threadIdx.y*block_size_x + threadIdx.x == 0) {
	reinterpret_cast<vector*>(arg.result_d)[0] = sum;
	count[0] = 0; // set to zero for next time
      }
    }
  }

} // namespace quda
