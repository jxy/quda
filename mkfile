MKSHELL=$PLAN9/bin/rc

HASH=omptarget,FIXME_with_a_unique_string

# CXX=mpicxx
CXX=icpx
# OMPFLAGS=-fopenmp
OMPFLAGS=-fiopenmp -fopenmp-targets=spir64 -D__STRICT_ANSI__

CXXFLAGS=-O0 -g -std=gnu++17
# CXXFLAGS=-march=native -Ofast
CXXFLAGS=$CXXFLAGS -Iinclude/targets/omptarget -Iinclude -Itests/utils -Iinclude/externals -Ilib -Itests/host_reference -I../eigen-3.3.7 -Itests/googletest/include -Itests/googletest
CXXFLAGS=$CXXFLAGS -DQUDA_PRECISION=14 -DQUDA_RECONSTRUCT=7 -DQUDA_MAX_MULTI_BLAS_N=4 -DQUDA_FAST_COMPILE_REDUCE -DQUDA_HASH="$HASH"
CXXFLAGS=$CXXFLAGS -DBUILD_QDP_INTERFACE -DGPU_WILSON_DIRAC
# CXXFLAGS=$CXXFLAGS -DMPI_COMMS -DMULTI_GPU
CXXFLAGS=$CXXFLAGS -DQUDA_BACKEND_OMPTARGET
CXXFLAGS=$CXXFLAGS -Wno-attributes

LDFLAGS=

TFILES=`{ls tests/*.cpp}

EXE=${TFILES:%.cpp=%}
EXEOFILES=${EXE:%=%.o}

LIBOFILES=\
	lib/block_orthogonalize.o\
	lib/blas_magma.o\
	lib/blas_quda.o\
	lib/checksum.o\
	lib/clover_deriv_quda.o\
	lib/clover_field.o\
	lib/clover_invert.o\
	lib/clover_outer_product.o\
	lib/clover_quda.o\
	lib/clover_sigma_outer_product.o\
	lib/clover_trace_quda.o\
	lib/coarse_op.o\
	lib/coarse_op_preconditioned.o\
	lib/coarsecoarse_op.o\
	lib/color_spinor_field.o\
	lib/color_spinor_pack.o\
	lib/color_spinor_util.o\
	lib/comm_common.o\
	lib/comm_single.o\
	lib/contract.o\
	lib/copy_clover.o\
	lib/copy_color_spinor.o\
	lib/copy_color_spinor_dd.o\
	lib/copy_color_spinor_dh.o\
	lib/copy_color_spinor_dq.o\
	lib/copy_color_spinor_ds.o\
	lib/copy_color_spinor_hd.o\
	lib/copy_color_spinor_hh.o\
	lib/copy_color_spinor_hq.o\
	lib/copy_color_spinor_hs.o\
	lib/copy_color_spinor_mg_dd.o\
	lib/copy_color_spinor_mg_ds.o\
	lib/copy_color_spinor_mg_hh.o\
	lib/copy_color_spinor_mg_hq.o\
	lib/copy_color_spinor_mg_hs.o\
	lib/copy_color_spinor_mg_qh.o\
	lib/copy_color_spinor_mg_qq.o\
	lib/copy_color_spinor_mg_qs.o\
	lib/copy_color_spinor_mg_sd.o\
	lib/copy_color_spinor_mg_sh.o\
	lib/copy_color_spinor_mg_sq.o\
	lib/copy_color_spinor_mg_ss.o\
	lib/copy_color_spinor_qd.o\
	lib/copy_color_spinor_qh.o\
	lib/copy_color_spinor_qq.o\
	lib/copy_color_spinor_qs.o\
	lib/copy_color_spinor_sd.o\
	lib/copy_color_spinor_sh.o\
	lib/copy_color_spinor_sq.o\
	lib/copy_color_spinor_ss.o\
	lib/copy_gauge.o\
	lib/copy_gauge_double.o\
	lib/copy_gauge_extended.o\
	lib/copy_gauge_half.o\
	lib/copy_gauge_mg.o\
	lib/copy_gauge_quarter.o\
	lib/copy_gauge_single.o\
	lib/covDev.o\
	lib/cpu_color_spinor_field.o\
	lib/cpu_gauge_field.o\
	lib/cuda_color_spinor_field.o\
	lib/cuda_gauge_field.o\
	lib/deflation.o\
	lib/dirac.o\
	lib/dirac_clover.o\
	lib/dirac_clover_hasenbusch_twist.o\
	lib/dirac_coarse.o\
	lib/dirac_domain_wall.o\
	lib/dirac_domain_wall_4d.o\
	lib/dirac_improved_staggered.o\
	lib/dirac_improved_staggered_kd.o\
	lib/dirac_mobius.o\
	lib/dirac_staggered.o\
	lib/dirac_staggered_kd.o\
	lib/dirac_twisted_clover.o\
	lib/dirac_twisted_mass.o\
	lib/dirac_wilson.o\
	lib/dslash5_domain_wall.o\
	lib/dslash5_mobius_eofa.o\
	lib/dslash_coarse.o\
	lib/dslash_coarse_dagger.o\
	lib/dslash_domain_wall_4d.o\
	lib/dslash_domain_wall_5d.o\
	lib/dslash_improved_staggered.o\
	lib/dslash_ndeg_twisted_mass.o\
	lib/dslash_ndeg_twisted_mass_preconditioned.o\
	lib/dslash_pack2.o\
	lib/dslash_quda.o\
	lib/dslash_staggered.o\
	lib/dslash_twisted_clover.o\
	lib/dslash_twisted_clover_preconditioned.o\
	lib/dslash_twisted_mass.o\
	lib/dslash_twisted_mass_preconditioned.o\
	lib/dslash_wilson.o\
	lib/dslash_wilson_clover.o\
	lib/dslash_wilson_clover_hasenbusch_twist.o\
	lib/dslash_wilson_clover_hasenbusch_twist_preconditioned.o\
	lib/dslash_wilson_clover_preconditioned.o\
	lib/eig_block_trlm.o\
	lib/eig_iram.o\
	lib/eig_trlm.o\
	lib/eigensolve_quda.o\
	lib/extract_gauge_ghost.o\
	lib/extract_gauge_ghost_extended.o\
	lib/extract_gauge_ghost_mg.o\
	lib/gauge_ape.o\
	lib/gauge_covdev.o\
	lib/gauge_field.o\
	lib/gauge_field_strength_tensor.o\
	lib/gauge_fix_fft.o\
	lib/gauge_fix_ovr.o\
	lib/gauge_force.o\
	lib/gauge_laplace.o\
	lib/gauge_observable.o\
	lib/gauge_phase.o\
	lib/gauge_plaq.o\
	lib/gauge_qcharge.o\
	lib/gauge_random.o\
	lib/gauge_stout.o\
	lib/gauge_update_quda.o\
	lib/gauge_wilson_flow.o\
	lib/hisq_paths_force_quda.o\
	lib/instantiate.o\
	lib/interface_quda.o\
	lib/inv_bicgstab_quda.o\
	lib/inv_bicgstabl_quda.o\
	lib/inv_ca_cg.o\
	lib/inv_ca_gcr.o\
	lib/inv_cg_quda.o\
	lib/inv_cg3_quda.o\
	lib/inv_eigcg_quda.o\
	lib/inv_gcr_quda.o\
	lib/inv_gmresdr_quda.o\
	lib/inv_mpbicgstab_quda.o\
	lib/inv_mpcg_quda.o\
	lib/inv_mr_quda.o\
	lib/inv_mre.o\
	lib/inv_multi_cg_quda.o\
	lib/inv_pcg_quda.o\
	lib/inv_sd_quda.o\
	lib/laplace.o\
	lib/lattice_field.o\
	lib/llfat_quda.o\
	lib/max_gauge.o\
	lib/mdw_fused_dslash.o\
	lib/momentum.o\
	lib/multi_blas_quda.o\
	lib/multi_reduce_quda.o\
	lib/multigrid.o\
	lib/prolongator.o\
	lib/quda_arpack_interface.o\
	lib/random.o\
	lib/reduce_helper.o\
	lib/reduce_quda.o\
	lib/restrictor.o\
	lib/solver.o\
	lib/spinor_noise.o\
	lib/staggered_coarse_op.o\
	lib/staggered_kd_apply_xinv.o\
	lib/staggered_kd_build_xinv.o\
	lib/staggered_oprod.o\
	lib/staggered_prolong_restrict.o\
	lib/timer.o\
	lib/transfer.o\
	lib/unitarize_force_quda.o\
	lib/unitarize_links_quda.o\
	lib/util_quda.o\
	lib/vector_io.o\
	lib/targets/generic/blas_lapack_eigen.o\
	lib/targets/omptarget/blas_lapack_cublas.o\
	lib/targets/omptarget/device.o\
	lib/targets/omptarget/malloc.o\
	lib/targets/omptarget/quda_api.o\
	tests/host_reference/clover_reference.o\
	tests/host_reference/domain_wall_dslash_reference.o\
	tests/host_reference/dslash_reference.o\
	tests/host_reference/staggered_dslash_reference.o\
	tests/host_reference/wilson_dslash_reference.o\
	tests/utils/command_line_params.o\
	tests/utils/host_blas.o\
	tests/utils/host_utils.o\
	tests/utils/llfat_utils.o\
	tests/utils/misc.o\
	tests/utils/set_params.o\
	tests/utils/staggered_gauge_utils.o\
	tests/utils/staggered_host_utils.o\

GTESTOFILES=tests/googletest/src/gtest-all.o

DFILES=${LIBOFILES:%.o=%.d} ${EXEOFILES:%.o=%.d} ${GTESTOFILES:%.o=%.d}
<|cat $DFILES>[2]/dev/null||true

tests/%: tests/%.o $LIBOFILES $GTESTOFILES
	$CXX $OMPFLAGS $LDFLAGS -o $target $prereq

%.o: %.cc
	$CXX $CXXFLAGS $OMPFLAGS -MMD -o $target -c $stem.cc
%.o: %.cpp
	$CXX $CXXFLAGS $OMPFLAGS -MMD -o $target -c $stem.cpp
%.o: %.cu
	$CXX $CXXFLAGS $OMPFLAGS -MMD -x c++ -o $target -c $stem.cu

allclean:V:	clean
	rm -f $EXE
clean:V:	depclean
	rm -f $LIBOFILES $GTESTOFILES $EXEOFILES
depclean:V:
	rm -f $DFILES
