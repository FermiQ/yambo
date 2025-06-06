!
! License-Identifier: GPL
!
! Copyright (C) 2006 The Yambo Team
!
! Authors (see AUTHORS file for details): DS AM
!
module hamiltonian
 !
 use pars,       ONLY:SP,schlen
 use electrons,  ONLY:levels
 !
#include<y_memory.h>
 !
 integer           :: H_ref_bands(2)
 integer           :: H_ref_nbands
 !
 character(schlen) :: H_potential
 !
 ! Possible Kinds, functionals and external perturbations
 !
 integer           :: H_kind
 integer           :: H_xc_functional
 integer           :: H_perturbation
 !
 complex(SP), allocatable :: Hzero(:,:,:,:)
 !
 ! Non-Local part (sigma_x, sigma_cohsex)
 !
 complex(SP), allocatable :: H_nl_sc(:,:)
 !
 real(SP),    allocatable :: V_xc_sc(:,:)
 real(SP),    allocatable :: V_hartree_sc(:,:)
 !
 logical           :: l_sc_V_is_local=.TRUE.
 logical           :: l_sc_XC_is_local=.TRUE.
 !
 ! Kinetic Energy and Ionic potential energy
 !
 type(levels),save        :: E_reference
 !
 real(SP),    allocatable :: rho_n(:)
 real(SP),    allocatable :: magn_n(:,:)
 !
 ! Rotation matrix which diagonalize the hamiltonian
 !
 complex(SP), allocatable :: H_rotation(:,:,:,:)
 complex(SP), allocatable :: H_rotation_ref(:,:,:,:)
 !
 ! Wavefunction indexes
 !
 integer :: WF_G_max
 integer :: WF_Go_indx
 !
 contains
   !
   integer function B_mat_index(ib1,ib2,nb)
     integer :: ib1,ib2,nb(2)
     !
     B_mat_index=(ib1-nb(1))*(nb(2)-nb(1)+1)+ib2-nb(1)+1
     !
   end function
   !
   subroutine H_QP_table_setup(E)
     use drivers,        ONLY:l_use_collisions
     use R_lattice,      ONLY:nkibz
     use electrons,      ONLY:levels
     use QP_m,           ONLY:QP_nk,QP_state,QP_nb
     !
     type(levels) :: E
     !
     ! Build-up QP table
     !
     QP_nb=H_ref_bands(2)
     QP_nk=nkibz
     ! 
     ! QP_state my be read from DBs at start-up
     !
     if (.not.l_use_collisions) then
       !
       YAMBO_FREE(QP_state)
       !
       YAMBO_ALLOC(QP_state,(QP_nb,QP_nk))
       QP_state=.TRUE.
       call QP_state_table_setup(E)
       !
     endif
     !
   end subroutine
   !
   subroutine H_alloc(E,l_real_space,l_rotation_matrix)
     use pars,           ONLY:SP
     use drivers,        ONLY:l_nl_optics,l_sc_run
     use electrons,      ONLY:n_spin,n_sp_pol,levels,E_reset,E_duplicate
     use FFT_m,          ONLY:fft_size
     use xc_functionals, ONLY:magn,V_xc
     !
     implicit none
     !
     type(levels), intent(in) :: E
     logical,      intent(in) :: l_real_space,l_rotation_matrix
     !
     ! Store the reference energies
     !
     if (.not.l_sc_run) then
       call E_reset(E_reference)
       call E_duplicate(E,E_reference)
     endif
     !
     H_ref_nbands=H_ref_bands(2)-H_ref_bands(1)+1
     !
     YAMBO_ALLOC(Hzero,(H_ref_bands(1):H_ref_bands(2),H_ref_bands(1):H_ref_bands(2),E%nk,n_sp_pol))
     !
     YAMBO_ALLOC(H_nl_sc,(H_ref_bands(1):H_ref_bands(2),H_ref_bands(1):H_ref_bands(2)))
     !
     if(l_rotation_matrix) then
       YAMBO_ALLOC(H_rotation,(H_ref_bands(1):H_ref_bands(2),H_ref_bands(1):H_ref_bands(2),E%nk,n_sp_pol))
     endif
     !
     if (.not.l_real_space.or.fft_size==0) return
     !
     YAMBO_ALLOC(rho_n,(fft_size))
     !
     if(n_spin>1) then
       YAMBO_ALLOC(magn,(fft_size,3))
       YAMBO_ALLOC(magn_n,(fft_size,3))
     endif
     !
     YAMBO_ALLOC(V_xc_sc,(fft_size,n_spin))
     !
     YAMBO_ALLOC(V_xc,(fft_size,n_spin))
     !
     YAMBO_ALLOC(V_hartree_sc,(fft_size,n_spin))
     !
   end subroutine
   !
   subroutine H_free()
     use xc_functionals, ONLY:magn,V_xc
     use ALLOC,          ONLY:X_ALLOC_elemental
     !
     implicit none
     !
     YAMBO_FREE(Hzero)
     YAMBO_FREE(H_nl_sc)
     YAMBO_FREE(H_rotation)
     !
     YAMBO_FREE(rho_n)
     YAMBO_FREE(magn_n)
     YAMBO_FREE(magn)
     !
     YAMBO_FREE(V_xc)
     YAMBO_FREE(V_xc_sc)
     YAMBO_FREE(V_hartree_sc)
     !
   end subroutine
   !
end module
