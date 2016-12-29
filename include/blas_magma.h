#ifndef _BLAS_MAGMA_H
#define _BLAS_MAGMA_H

#include <cuda.h>
#include <cuda_runtime.h>
#include <string>
#include <complex>
#include <cuComplex.h>
#include <stdio.h>

//MAGMA library interface
//required for (incremental) EigCG solver



   class BlasMagmaArgs{

      typedef std::complex<double> Complex;

    private:

      //problem sizes:
      int m;
      int max_nev; //=2*nev for (incremental) eigCG and nev+1 for (F)GMRESDR
      int prec;
      int ldm;//(may include padding)

      //general magma library parameters:
      int info;

      bool init;
      bool alloc;

      //magma params/objects:
      int llwork;
      int lrwork;
      int liwork;

      int sideLR;

      int htsize;//MIN(l,k)-number of Householder reflectors, but we always have k <= MIN(m,n)
      int dtsize;//

      int lwork_max;

      void *W;
      void *W2;
      void *hTau;
      void *dTau;

      void *lwork;
      void *rwork;
      int  *iwork;

    public:

      BlasMagmaArgs() : prec(8), info(-1), init(true), alloc(false) {  }

      BlasMagmaArgs(const int prec);

      BlasMagmaArgs(const int m, const int max_nev, const int ldm, const int prec);

      BlasMagmaArgs(const int m, const int ldm, const int prec);

      ~BlasMagmaArgs();

      //Initialization methods:
      static void OpenMagma();
      //
      static void CloseMagma();

      //Collection of methods for EigCG solver:
      void MagmaHEEVD(void *dTvecm, void *hTvalm, const int problem_size, bool host = false);
      //
      int  MagmaORTH_2nev(void *dTvecm, void *dTm);
      //
      void RestartV(void *dV, const int vld, const int vlen, const int vprec, void *dTevecm, void *dTm);

      //Collection of methods used for the initial guess vector deflation:

      //this accepts host routines, and employ either CPU or GPU, depending on problem size etc.
      void SolveProjMatrix(void* rhs, const int ldn, const int n, void* H, const int ldH);

      //GPU version of the above
      void SolveGPUProjMatrix(void* rhs, const int ldn, const int n, void* H, const int ldH);

      //Spinor matrix vector product:
      void SpinorMatVec(void *spinorOut, const void *spinorSetIn, const int sld, const int slen, const void *vec, const int vlen);

      //Collection of methods for GMRESDR solver:
      void RestartVH(void *dV, const int vld, const int vlen, const int vprec, void *sortedHarVecs, void *H, const int ldh);//ldm: leading dim for both dharVecs and dH. additional info: nev, nev+1 = max_nev, m

      void MagmaRightNotrUNMQR(const int clen, const int qrlen, const int nrefls, void *QR, const int ldqr, void *Vm, const int cldn);

      void MagmaRightNotrUNMQR(const int clen, const int qrlen, const int nrefls, void *pQR, const int ldqr, void *pTau, void *pVm, const int cldn);
      //
      void Sort(const int m, const int ldm, void *eVecs, const int nev, void *unsorted_eVecs, void *eVals);//Sort nev smallest eigenvectors
//new:
      void ComputeQR(const int nev, Complex * evmat, const int m, const int ldm, Complex  *tau);

      void LeftConjZUNMQR(const int k /*number of reflectors*/, const int n /*number of columns of H*/, Complex *H, const int dh /*number of rows*/, const int ldh, Complex * QR,  const int ldqr, Complex *tau);//for vectors: n =1

      void Construct_harmonic_matrix(Complex * const harmH, Complex * const conjH, const double beta2, const int m, const int ldH);

      void Compute_harmonic_matrix_eigenpairs(Complex *harmH, const int m, const int ldH, Complex *vr, Complex *evalues, const int ldv);

      /**
	 Batch inversion the matrix field using an LU decomposition method.
	 @param Ainv_h Matrix field containing the inverse matrices on the CPU
	 @param A_h Matrix field containing the input matrices on the CPU
	 @param Temporary storate on the GPU of size = A_h
	 @param n Dimension each matrix
	 @param batch Problem batch size
       */
      void BatchInvertMatrix(void *Ainv_h, void* A_h, const int n, const int batch);

   };

  void magma_Xgesv(void* sol, const int ldn, const int n, void* Mat, const int ldm, const int prec);

  void magma_Xgeev(void *Mat, const int m, const int ldm, void *vr, void *evalues, const int ldv, const int prec);

  void magma_Xgels(void *Mat, void *c, int rows, int cols, int ldm, const int prec);

  void magma_Xheev(void *Mat, const int m, const int ldm, void *evalues, const int prec);


#endif // _BLAS_MAGMA_H
