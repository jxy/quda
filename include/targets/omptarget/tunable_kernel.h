#pragma once

#include <constant_kernel_arg.h>
#include <tune_quda.h>
#include <target_device.h>
#include <kernel_helper.h>
#include <kernel.h>

namespace quda {

  namespace target {
    namespace omptarget {
      // defined in ../../../lib/targets/omptarget/quda_api.cpp:/qudaSetupLaunchParameter
      int qudaSetupLaunchParameter(const TuneParam &);
      void set_runtime_error(int error, const char *api_func, const char *func, const char *file,
                             const char *line, bool allow_error = false);
    }
  }

  template <typename T>
  concept has_reduce_t = requires {
    typename T::reduce_t;
  };
  template <typename T>
  concept is_GaugeFixOvr = requires (T a) {
    a.relax_boost;
  };

  template <typename Arg>
  inline bool acceptThreads(const TuneParam &tp, const Arg &arg)
  {
    bool fit = tp.block.x*tp.block.y*tp.block.z<=device::max_block_size();
    bool divisible =
        (arg.threads.x%tp.block.x==0 &&
         arg.threads.y%tp.block.y==0 &&
         arg.threads.z%tp.block.z==0);
    if(getVerbosity() >= QUDA_DEBUG_VERBOSE)
      printfQuda("Checking threads setup for arg %d %d %d tp grid %d %d %d block %d %d %d\n",arg.threads.x,arg.threads.y,arg.threads.z,tp.grid.x,tp.grid.y,tp.grid.z,tp.block.x,tp.block.y,tp.block.z);
    if(!fit){
      if(getVerbosity() >= QUDA_DEBUG_VERBOSE)
        warningQuda("rejecting threads setup with a large block size\nfor arg %d %d %d tp grid %d %d %d block %d %d %d\n",arg.threads.x,arg.threads.y,arg.threads.z,tp.grid.x,tp.grid.y,tp.grid.z,tp.block.x,tp.block.y,tp.block.z);
      return fit;
    }
    if(!divisible){
      // we need to specialize it for different Arg
      if constexpr(has_reduce_t<Arg> || is_GaugeFixOvr<Arg>){
        if(getVerbosity() >= QUDA_DEBUG_VERBOSE)
          warningQuda("rejecting threads setup with a non-divisible block size\nfor arg %d %d %d tp grid %d %d %d block %d %d %d\n",arg.threads.x,arg.threads.y,arg.threads.z,tp.grid.x,tp.grid.y,tp.grid.z,tp.block.x,tp.block.y,tp.block.z);
        return false;
      } else {
        if(getVerbosity() >= QUDA_DEBUG_VERBOSE){
          bool cont = true;
          std::string reply;
          ompwip("arg threads not divisible by tp block, yes to stop?");
          std::getline(std::cin, reply);
          if(reply[0] == 'y' || reply[0] == 'Y'){
            cont = false;
          }
          return cont;
        } else {
          if(getVerbosity() >= QUDA_VERBOSE)
            ompwip("accepting threads setup with a non-divisible block size\nfor arg %d %d %d tp grid %d %d %d block %d %d %d\n",arg.threads.x,arg.threads.y,arg.threads.z,tp.grid.x,tp.grid.y,tp.grid.z,tp.block.x,tp.block.y,tp.block.z);
          return true;
        }
      }
    }
    return true;
  }

  class TunableKernel : public Tunable
  {

  protected:
    QudaFieldLocation location;

    virtual unsigned int sharedBytesPerThread() const { return 0; }
    virtual unsigned int sharedBytesPerBlock(const TuneParam &) const { return 0; }

    template <template <typename> class Functor, bool grid_stride, typename Arg>
    qudaError_t launch_device(const kernel_t &kernel, const TuneParam &tp, const qudaStream_t &stream, const Arg &arg)
    {
      if (acceptThreads(tp, arg) && 0==target::omptarget::qudaSetupLaunchParameter(tp)) {
        if constexpr (device::use_kernel_arg<Arg>()) {
          reinterpret_cast<void(*)(Arg)>(const_cast<void*>(kernel.func))(arg);
        } else {
          static_assert(sizeof(Arg) <= device::max_constant_size(), "Parameter struct is greater than max constant size");
          Arg *argp = reinterpret_cast<Arg*>(device::get_constant_buffer<Arg>());
          memcpy(argp, &arg, sizeof(Arg));
          reinterpret_cast<void(*)(Arg*)>(const_cast<void*>(kernel.func))(argp);
        }
        launch_error = QUDA_SUCCESS;
      } else {
        target::omptarget::set_runtime_error(QUDA_ERROR, __func__, __func__, __FILE__, __STRINGIFY__(__LINE__), activeTuning());
        launch_error = QUDA_ERROR;
      }
      return launch_error;
    }

  public:
    /**
       @brief Special kernel launcher used for raw CUDA kernels with no
       assumption made about shape of parallelism.  Kernels launched
       using this must take responsibility of bounds checking and
       assignment of threads.
     */
    template <template <typename> class Functor, typename Arg>
    void launch_cuda(const TuneParam &tp, const qudaStream_t &stream, const Arg &arg) const
    {
      constexpr bool grid_stride = false;
      const_cast<TunableKernel*>(this)->launch_device<Functor, grid_stride>(KERNEL(raw_kernel), tp, stream, arg);
    }

    TunableKernel(QudaFieldLocation location = QUDA_INVALID_FIELD_LOCATION) : location(location) { } 

    virtual bool advanceTuneParam(TuneParam &param) const
    {
      return location == QUDA_CPU_FIELD_LOCATION ? false : Tunable::advanceTuneParam(param);
    }

    TuneKey tuneKey() const { return TuneKey(vol, typeid(*this).name(), aux); }
  };

}
