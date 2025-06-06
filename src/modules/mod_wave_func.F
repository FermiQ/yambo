!
! License-Identifier: GPL
!
! Copyright (C) 2006 The Yambo Team
!
! Authors (see AUTHORS file for details): AM DS
!
module wave_func
 !
 use pars,           ONLY:SP
 use devxlib,        ONLY:devxlib_mapped
 use gpu_m,          ONLY:have_gpu
 !
#include <dev_defs.h>
#include <y_memory.h>
 !
 type WAVEs 
   integer              :: b(2)      ! band range 
   integer              :: k(2)      ! k range
   integer              :: sp_pol(2) ! sp_pol_range
   integer              :: N         ! states 
   character(1)         :: space
   complex(SP), allocatable :: c(:,:,:)
   integer    , allocatable :: index(:,:,:)
   logical    , allocatable :: state(:,:,:)
   logical                  :: to_load = .TRUE.
   complex(SP), allocatable DEV_ATTR :: c_d(:,:,:)
 end type WAVEs
 !
 ! Buffered WFs
 !
 type (WAVEs), save :: WF_buffer
 logical            :: WF_buffered_IO
 !
 ! Actual WFs
 !
 type (WAVEs), save, target :: WF
 !
 ! Real components ?
 !
 logical                :: real_wavefunctions
 !
 ! Bands block size
 !
 integer                :: wf_nb_io
 integer                :: wf_nb_io_groups
 !
 integer                :: wf_nb_to_load
 integer, allocatable   :: wf_b_indx(:)   ! given ib_to_load=1,wf_nb_to_load returns the band index
 !
 ! Max Num. of COMPONENTS
 !
 integer                :: wf_ncx
 !
 ! Max Num. of G-VECTORS for the WFs maxval(wf_igk) > wf_ncx
 !
 integer                :: wf_ng          ! For WFs in the    IBZ
 integer                :: wf_ng_1st_BZ   ! For WFs in the 1st BZ
 integer                :: wf_ng_overlaps ! For WFs shifted used by the overlaps
 integer                :: cutoff_ng      ! For G-vectors used in cutoff (if read, may be different from wf_ng)
 !
 ! Wave function derivatives
 !
 complex(SP), allocatable :: wf_x(:,:,:)
 complex(SP), allocatable :: wf_y(:,:,:)
 complex(SP), allocatable :: wf_z(:,:,:)
 !
 ! Parallel wave-function distribution
 !
 logical,    allocatable:: states_to_load(:,:,:) 
 !
 ! Num. of COMPONENTS at each k
 !
 integer,    allocatable:: wf_nc_k(:)
 !
 ! Table correspondance G-vec <-> Components: G_ic = wf_igk(ic,ik)
 !
 integer,    allocatable:: wf_igk(:,:)
 integer,    allocatable DEV_ATTR :: wf_igk_d(:,:)
 logical                :: wf_norm_test
 !
 interface
   !
   integer function io_WF(ID,wf)
     use pars,       ONLY: SP
     integer            :: ID
     complex(SP), optional :: wf(:,:,:)
   end function
   !
   function WF_symm(ifft,isc)
     use pars,        ONLY: SP
     use electrons,   ONLY: n_spinor
     integer             :: ifft,isc(4)
     complex(SP),dimension(n_spinor) :: WF_symm
   end function
   !
#if defined _GPU
   function WF_symm_gpu(ifft,isc)
     use pars,        ONLY: SP
     use electrons,   ONLY: n_spinor
     integer             :: ifft,isc(4)
     complex(SP),dimension(n_spinor) DEV_ATTR :: WF_symm_gpu
   end function
#endif
   !
 end interface 
 !
 contains
   !
   subroutine WF_copy(WF_in,WF_out)
     use electrons,  ONLY: n_spinor
     type(WAVEs):: WF_in,WF_out
     logical :: lpres
     !
     YAMBO_ALLOC_MOLD(WF_out%c,WF_in%c)
     YAMBO_ALLOC(WF_out%index,(WF_in%b(1):WF_in%b(2),WF_in%k(1):WF_in%k(2),WF_in%sp_pol(1):WF_in%sp_pol(2)))
     !
     WF_out%b      = WF_in%b
     WF_out%k      = WF_in%k
     WF_out%sp_pol = WF_in%sp_pol
     WF_out%N      = WF_in%N
     WF_out%space  = WF_in%space
     WF_out%to_load= WF_in%to_load
     WF_out%c      = WF_in%c
     WF_out%index  = WF_in%index
     !
     lpres=have_gpu.and.devxlib_mapped(DEV_VAR(WF_in%c))
#ifdef _GPU
     if (lpres) then
       YAMBO_ALLOC_GPU_SOURCE(DEV_VAR(WF_out%c),WF_in%c)
     endif
#endif
   end subroutine
   !
   subroutine WF_derivative_alloc(cart_direction)
     use pars,     ONLY : cZERO
     use FFT_m,    ONLY : fft_size
     use electrons,ONLY : n_spinor
     logical  :: cart_direction(3)
     !
     if(cart_direction(1)) then
       YAMBO_ALLOC(wf_x,(fft_size,n_spinor,WF%N))
       wf_x=cZERO
     endif
     if(cart_direction(2)) then
       YAMBO_ALLOC(wf_y,(fft_size,n_spinor,WF%N))
       wf_y=cZERO
     endif
     if(cart_direction(3)) then
       YAMBO_ALLOC(wf_z,(fft_size,n_spinor,WF%N))
       wf_z=cZERO
     endif
   end subroutine
   !
   subroutine WF_derivative_free()
     !
     YAMBO_FREE(wf_x)
     YAMBO_FREE(wf_y)
     YAMBO_FREE(wf_z)
     !
   end subroutine
   !
end module
