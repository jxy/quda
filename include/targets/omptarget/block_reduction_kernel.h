#pragma once

#include <reduce_helper.h>

namespace quda {

  /**
     @brief This helper function swizzles the block index through
     mapping the block index onto a matrix and tranposing it.  This is
     done to potentially increase the cache utilization.  Requires
     that the argument class has a member parameter "swizzle" which
     determines if we are swizzling and a parameter "swizzle_factor"
     which is the effective matrix dimension that we are tranposing in
     this mapping.
   */
  template <typename Arg> __device__ int virtual_block_idx(const Arg &arg)
  {
    QUDA_RT_CONSTS;
    int block_idx = blockIdx.x;
    if (arg.swizzle) {
      // the portion of the grid that is exactly divisible by the number of SMs
      const int gridp = gridDim.x - gridDim.x % arg.swizzle_factor;

      block_idx = blockIdx.x;
      if (blockIdx.x < gridp) {
        // this is the portion of the block that we are going to transpose
        const int i = blockIdx.x % arg.swizzle_factor;
        const int j = blockIdx.x / arg.swizzle_factor;

        // transpose the coordinates
        block_idx = i * (gridp / arg.swizzle_factor) + j;
      }
    }
    return block_idx;
  }

  /**
     @brief Generic block reduction kernel.  Here, we ensure that each
     thread block maps exactly to a logical block to be reduced, with
     number of threads equal to the number of sites per block.  The y
     thread dimension is a trivial vectorizable dimension.

     TODO: add a Reducer class for non summation reductions
  */
  template <int block_size, template <typename> class Transformer, typename Arg>
  __global__ void BlockReductionKernel2D(Arg arg)
  {
    QUDA_RT_CONSTS;
    using reduce_t = typename Transformer<Arg>::reduce_t;
    Transformer<Arg> t(arg);

    const int block = virtual_block_idx(arg);
    const int i = threadIdx.x;
    const int j = blockDim.y*blockIdx.y + threadIdx.y;
    const int j_local = threadIdx.y;
    if (j >= arg.threads.y) return;

    reduce_t value; // implicitly we assume here that default constructor zeros reduce_t
    // only active threads call the transformer
    if (i < arg.threads.x) value = t(block, i, j);
/*
    // but all threads take part in the reduction
    using BlockReduce = cub::BlockReduce<reduce_t, block_size, cub::BLOCK_REDUCE_WARP_REDUCTIONS>;
    __shared__ typename BlockReduce::TempStorage temp_storage[Arg::n_vector_y];
    value = BlockReduce(temp_storage[j_local]).Sum(value);
*/
    if (i == 0) t.store(value, block, j);
  }

}
