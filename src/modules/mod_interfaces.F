!
! License-Identifier: GPL
!
! Copyright (C) 2013 The Yambo Team
!
! Authors (see AUTHORS file for details): AM DS
!
! headers
!
#if defined _SLEPC && !defined _NL
#include <petsc/finclude/petscsys.h>
#include <petsc/finclude/petscvec.h>
#include <petsc/finclude/petscmat.h>
#include <slepc/finclude/slepcsys.h>
#include <slepc/finclude/slepceps.h>
#endif
!
module interfaces
 !
#include<dev_defs.h>
 !
 implicit none
 !
 interface
   !
   subroutine DESC_compare(D1,D2,i_err,exclude,only)
     use descriptors,ONLY:IO_desc
     type(IO_desc),          intent(in) :: D1,D2
     integer                            :: i_err(2)
     character(*), optional, intent(in) :: exclude
     character(*), optional, intent(in) :: only
   end subroutine
   !
   subroutine DESC_write(dest,prefix,desc,range,skip_patt)
     use descriptors,ONLY:IO_desc
     character(*),           intent(in) :: dest
     character(*),           intent(in) :: prefix
     type(IO_desc),          intent(in) :: desc
     integer, optional,      intent(in) :: range(2)
     character(*), optional, intent(in) :: skip_patt
   end subroutine
   !
   subroutine OCCUPATIONS_Fermi(E,K,OBJ,mode,n_bands,impose_balance)
     use electrons,      ONLY:levels
     use R_lattice,      ONLY:bz_samp
     type(levels)  ::E
     type(bz_samp) ::K
     character(*)           ::OBJ
     character(*), OPTIONAL ::mode
     integer,      OPTIONAL ::n_bands
     logical,      OPTIONAL ::impose_balance
   end subroutine
   !
   subroutine MATRIX_duplicate( operation, M_in, INDEX_in, M_out )
     use matrix,         ONLY:PAR_matrix
     character(*)               :: operation
     type(PAR_matrix), optional :: M_in
     integer         , optional :: INDEX_in
     type(PAR_matrix)           :: M_out
   end subroutine
   !
   subroutine MATRIX_transpose( operation, M_in, M_out )
     use matrix,         ONLY:PAR_matrix,MATRIX_reset
     character(*)               :: operation
     type(PAR_matrix), optional :: M_in
     type(PAR_matrix)           :: M_out
   end subroutine
   !
   subroutine MATRIX_transfer( M_in, M_bse, M, M_out, INDEX_in, INDEX_out, SND, RCV, COMM, COMM_name)
     !
     use parallel_m,     ONLY:yMPI_comm
     use matrix,         ONLY:PAR_matrix
     use BS,             ONLY:BS_block
     use pars,           ONLY:SP
     !
     type(PAR_matrix), optional :: M_in
     type(PAR_matrix), optional :: M_out
     type(BS_block),   optional :: M_bse(:)
     integer,          optional :: INDEX_in
     integer,          optional :: INDEX_out
     complex(SP),      optional :: M(:,:)
     logical,          optional :: SND
     logical,          optional :: RCV
     type(yMPI_comm),   optional :: COMM
     character(*),     optional :: COMM_name
     !
   end subroutine
   !
   subroutine LINEAR_ALGEBRA_driver(idriver,lib_in,M,M_slk,M_bse,B,B_slk,C,C_slk,V_left,V_right,E_real,&
&                                   E_cmpl,SVD_digits,det)
     !
     use matrix,         ONLY:PAR_matrix
     use pars,           ONLY:SP
     use BS,             ONLY:BS_block
     !
     integer                    :: idriver
     integer,          optional :: lib_in
     complex(SP),      optional :: M(:,:)
     type(PAR_matrix), optional :: M_slk
     type(BS_block),   optional :: M_bse(:)
     complex(SP),      optional :: B(:,:)
     type(PAR_matrix), optional :: B_slk
     complex(SP),      optional :: C(:,:)
     type(PAR_matrix), optional :: C_slk
     complex(SP),      optional :: V_left(:,:)
     complex(SP),      optional :: V_right(:,:)
     real(SP),         optional :: E_real(:)
     complex(SP),      optional :: E_cmpl(:)
     integer,          optional :: SVD_digits 
     complex(SP),      optional :: det
     !
   end subroutine
   !
   subroutine el_density_and_current(E,k,rho,drho,J,bands,force_spatial_inversion)
     use pars,           ONLY:SP
     use electrons,      ONLY:levels
     use R_lattice,      ONLY:bz_samp
     use FFT_m,          ONLY:fft_size
     type(bz_samp)::k
     type(levels) ::E       
     real(SP), optional             ::rho(fft_size)
     real(SP), optional             ::drho(fft_size,3)
     real(SP), optional             ::J(fft_size,3)
     integer,  optional, intent(in) ::bands(2)
     logical,  optional, intent(in) ::force_spatial_inversion
   end subroutine el_density_and_current
   !
   subroutine el_magnetization(en,Xk,magn,bands)
     use pars,           ONLY:SP
     use electrons,      ONLY:levels
     use R_lattice,      ONLY:bz_samp
     use FFT_m,          ONLY:fft_size
     implicit none
     type(levels), intent(in ) ::en
     type(bz_samp),intent(in ) ::Xk
     real(SP),     intent(out) ::magn(fft_size,3)
     integer,  optional, intent(in) ::bands(2)
   end subroutine el_magnetization
   !
   subroutine el_density_of_states(Xk,Xen,dos_E,DOS_broadening,DOS_bands,dos_value,&
&                                  USE_the_DbGd,USE_Eo,USE_W,USE_occupations,WF_fac,PDOS_fac)
     use pars,           ONLY:SP
     use electrons,      ONLY:levels
     use R_lattice,      ONLY:bz_samp 
     use electrons,      ONLY:n_spin
     type(bz_samp), intent(in)  :: Xk
     type(levels),  intent(in)  :: Xen
     real(SP),      intent(in)  :: dos_E,DOS_broadening
     integer,       intent(in)  :: DOS_bands(2)
     real(SP),      intent(out) :: dos_value(n_spin)
     logical,  optional, intent(in) :: USE_Eo,USE_W,USE_occupations,USE_the_DbGd
     real(SP), pointer, optional, intent(in) :: WF_fac(:,:,:)
     real(SP), pointer, optional, intent(in) :: PDOS_fac(:,:,:)
   end subroutine el_density_of_states
   !
#if defined _SLEPC && !defined _NL
   subroutine MATRIX_slepc(M_slepc,l_target_energy,n_eig,V_right,V_left,E_real,E_cmpl)
     !
     use pars,           ONLY:SP,schlen
     use petscmatdef,    ONLY:tmat
#include <petsc/finclude/petscsys.h>
#include <petsc/finclude/petscmat.h>
     Mat                         :: M_slepc      ! matrix to diagonalize of stype from slepc
     logical                     :: l_target_energy
     integer                     :: n_eig        ! number of eigenvalues to compute
     complex(SP)                 :: V_right(:,:) ! right eigenvalues
     complex(SP),  optional      :: V_left(:,:)  ! left eigenvalues
     complex(SP),  optional      :: E_cmpl(:)    ! complex eigenvalues
     real(SP),     optional      :: E_real(:)    ! real eigenvalues
     !
   end subroutine
#endif
   !
   integer function eval_G_minus_G(iG,iGo,force_recompute,COMM)
     use parallel_m,      ONLY:yMPI_comm
     integer :: iG,iGo
     logical,         optional :: force_recompute
     type(yMPI_comm), optional :: COMM
   end function
   !
   subroutine WF_load(WF,iG_in,iGo_max_in,bands_to_load,kpts_to_load,sp_pol_to_load,&
&                     k_extrema_only,space,title,impose_free_and_alloc,&
&                     force_WFo,keep_states_to_load,quiet)
     use wave_func,       ONLY:WAVEs
     integer :: iG_in,iGo_max_in,bands_to_load(2),kpts_to_load(2)
     type(WAVEs)           :: WF
     integer,     optional :: sp_pol_to_load(2)
     character(*),optional :: space
     character(*),optional :: title
     logical     ,optional :: k_extrema_only
     logical     ,optional :: impose_free_and_alloc
     logical     ,optional :: force_WFo
     logical     ,optional :: keep_states_to_load
     logical,     optional, intent(in) :: quiet
   end subroutine
   !
   subroutine WF_free(WF,keep_fft,keep_states_to_load)
     use wave_func,       ONLY:WAVEs
     type(WAVEs)           :: WF
     logical     ,optional :: keep_fft
     logical     ,optional :: keep_states_to_load
   end subroutine
   !
   subroutine OCCUPATIONS_Gaps(E,E_g_dir,E_g_ind,N_f,N_m,I_dir,E_k_dir,E_k_ind)
     use pars,          ONLY: SP
     use electrons,     ONLY:levels,n_sp_pol
     type(levels)       :: E
     real(SP), optional :: E_g_dir(1+(n_sp_pol-1)*2,2) ! min - max
     real(SP), optional :: E_g_ind(1+(n_sp_pol-1)*2,2) ! min - max
     integer , optional :: N_f(2)
     integer , optional :: N_m(2)
     integer , optional :: I_dir(2)
     integer , optional :: E_k_dir(n_sp_pol)    ! k-point of the direct gap
     integer , optional :: E_k_ind(n_sp_pol,2)  ! k->k'   of the indirect gap
   end subroutine 
   !
   subroutine K_diago_response_functions(iq,i_BS_mat,W,BS_E,BS_R_left_abs,BS_R_right_abs,BS_E_SOC_corr,&
     &                                  BS_R_left_magn,BS_R_right_magn,BS_R_left_kerr,BS_R_right_kerr,BS_R_right_dich,BS_R_PL)
     use BS_solvers,    ONLY:BSS_n_eig
     use pars,          ONLY:SP
     use frequency,     ONLY:w_samp
     type(w_samp),intent(in)  :: W
     integer,     intent(in)  :: iq,i_BS_mat
     complex(SP), intent(in)  :: BS_E(BSS_n_eig)
     complex(SP), pointer, intent(in) :: BS_R_left_abs(:),BS_R_right_abs(:)
     real(SP),    pointer, intent(in) :: BS_E_SOC_corr(:,:)
     complex(SP), pointer, intent(in) :: BS_R_left_magn(:,:),BS_R_right_magn(:,:)
     complex(SP), pointer, intent(in) :: BS_R_left_kerr(:),BS_R_right_kerr(:),BS_R_right_dich(:,:)
     real(SP),    pointer, intent(in) :: BS_R_PL(:,:)
   end subroutine
   !
   subroutine K_diago_right_residuals(mode,i_BS_mat,BS_E,BS_R_right,BS_V_right)
     use BS_solvers,    ONLY:BSS_n_eig
     use pars,          ONLY:SP
     implicit none
     character(*),intent(in)  :: mode
     integer,     intent(in)  :: i_BS_mat
     complex(SP), intent(in)  :: BS_E(BSS_n_eig)
     complex(SP), intent(out) :: BS_R_right(BSS_n_eig)
     complex(SP), intent(in)  :: BS_V_right(:,:)
   end subroutine K_diago_right_residuals
   !
   subroutine K_diago_left_residuals(mode,i_BS_mat,BS_E,BS_R_left,BS_V_left,BS_overlap)
     use BS_solvers,    ONLY:BSS_n_eig
     use pars,          ONLY:SP
     implicit none
     character(*),intent(in)  :: mode
     integer,     intent(in)  :: i_BS_mat
     complex(SP), intent(in)  :: BS_E(BSS_n_eig)
     complex(SP),target,  intent(out) :: BS_R_left(BSS_n_eig)
     complex(SP),         intent(in)  :: BS_V_left(:,:)
     complex(SP),optional,intent(in)  :: BS_overlap(BSS_n_eig,BSS_n_eig)
   end subroutine K_diago_left_residuals
   !
   subroutine PL_diago_residual(BS_V_left,BS_V_right,BS_R_PL,K_is_not_hermitian,BS_overlap) 
     use pars,           ONLY:SP
     use BS,             ONLY:BS_H_dim
     logical,    intent(in)  :: K_is_not_hermitian
     complex(SP),intent(in)  :: BS_V_left(BS_H_dim,BS_H_dim),BS_V_right(BS_H_dim,BS_H_dim)
     real(SP)   ,intent(out) :: BS_R_PL(2,BS_H_dim)
     complex(SP),optional,intent(in)  :: BS_overlap(BS_H_dim,BS_H_dim)
   end subroutine
   !
   subroutine QP_DBs_merge(N,DBs,plan,N_qp,qp,OP,PRE_FAC,FILES)
     use pars, ONLY:SP
     use QP_m, ONLY:QP_t
     integer              :: N,N_qp
     type(QP_t)           :: DBs(N)
     logical              :: plan(N,3)
     type(QP_t),  optional:: qp(N_qp)
     character(*),optional:: OP(N)
     real(SP)    ,optional:: PRE_FAC(N)
     character(*),optional:: FILES(N)
   end subroutine QP_DBs_merge
   !
   integer function io_DB1_selective_scan(what,DB1_path,E,k,db1_alat,db1_a,COM_mode)
     use pars,       ONLY:SP
     use electrons,  ONLY:levels
     use R_lattice,  ONLY:bz_samp
     type(levels)      :: E
     type(bz_samp)     :: k
     character(*)      :: DB1_path,what
     real(SP),optional :: db1_a(3,3)
     real(SP),optional :: db1_alat(3) 
     integer ,optional :: COM_mode
   end function
   !
   subroutine QP_state_print(qp)
     use QP_m,          ONLY:QP_t
     type(QP_t),optional ::qp              
   end subroutine
   !
   function TDDFT_ALDA_eh_space_R_kernel(is,os,isp,osp,tddft_wf,mode) result(H_x)
     use pars,           ONLY:SP
     use TDDFT,          ONLY:tddft_wf_t
     complex(SP) :: H_x
     integer,          intent(in)  :: is(4),os(4),isp(4),osp(4)
     character(3),     intent(in)  :: mode
     type(tddft_wf_t), target, intent(inout) :: tddft_wf
   end function TDDFT_ALDA_eh_space_R_kernel
   !
   subroutine WF_shift_kpoint_gpu(b_to_shift,nb_to_shift,ikbz,i_sp_pol,wf_shift,Xk,WF_k_in,WF_k_out)
     use pars,          ONLY:SP
     use electrons,     ONLY:n_spinor
     use wave_func,     ONLY:wf_ng_1st_BZ,wf_ng_overlaps
     use R_lattice,     ONLY:bz_samp
     integer,       intent(in) :: wf_shift(3),ikbz,i_sp_pol,b_to_shift(2),nb_to_shift
     type(bz_samp), intent(in) :: Xk
     complex(SP),   intent(in)  DEV_ATTR :: WF_k_in (wf_ng_1st_BZ,n_spinor,nb_to_shift)
     complex(SP),   intent(out) DEV_ATTR :: WF_k_out(wf_ng_overlaps,n_spinor,nb_to_shift)
   end subroutine WF_shift_kpoint_gpu
   !
   subroutine WF_symm_kpoint(b_to_load,ikbz,i_sp_pol,Xk,WF_k_out)
     use pars,          ONLY:SP 
     use R_lattice,     ONLY:bz_samp
     use wave_func,     ONLY:wf_ng_1st_BZ
     use electrons,     ONLY:n_spinor
     integer,       intent(in)  :: ikbz,i_sp_pol,b_to_load(2)
     type(bz_samp), intent(in)  :: Xk
     complex(SP),   intent(out) :: WF_k_out(wf_ng_1st_BZ,n_spinor,b_to_load(2)-b_to_load(1)+1)
   end subroutine WF_symm_kpoint
   !
   subroutine WF_symm_kpoint_gpu(b_to_load,ikbz,i_sp_pol,Xk,WF_k_out)
     use pars,          ONLY:SP 
     use R_lattice,     ONLY:bz_samp
     use wave_func,     ONLY:wf_ng_1st_BZ
     use electrons,     ONLY:n_spinor
     integer,       intent(in)  :: ikbz,i_sp_pol,b_to_load(2)
     type(bz_samp), intent(in)  :: Xk
     complex(SP),   intent(out) DEV_ATTR :: WF_k_out(wf_ng_1st_BZ,n_spinor,b_to_load(2)-b_to_load(1)+1)
   end subroutine WF_symm_kpoint_gpu
   !
   subroutine WF_apply_symm(isc,WF_symm)
     use pars,          ONLY:SP
     use FFT_m,         ONLY:fft_size
     use electrons,     ONLY:n_spinor
     integer,     intent(in)  :: isc(4)
     complex(SP), intent(out) :: WF_symm(fft_size,n_spinor)
   end subroutine WF_apply_symm
   !
   subroutine WF_apply_symm_gpu(isc,WF_symm)
     use pars,          ONLY:SP
     use FFT_m,         ONLY:fft_size
     use electrons,     ONLY:n_spinor
     integer,     intent(in)  :: isc(4)
     complex(SP), intent(out) DEV_ATTR :: WF_symm(fft_size,n_spinor)
   end subroutine WF_apply_symm_gpu
   !
 end interface
 !
end module interfaces
