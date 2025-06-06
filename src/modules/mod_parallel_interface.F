!
! License-Identifier: GPL
!
! Copyright (C) 2013 The Yambo Team
!
! Authors (see AUTHORS file for details): AM
!
module parallel_int
 !
 use pars,       ONLY:SP,DP
 use parallel_m, ONLY:ncpu,myid,comm_default_value
#if defined _MPI
 use mpi
! 2021/01/14 DS, commented.
! It maybe needed for old libraries
! To be uncommented but protected with precompiler flags on gfortran compiler
! include 'mpif.h'
#else
 use parallel_m, ONLY:mpi_comm_world
#endif
 !
 implicit none
 !
 integer, private   :: i_err
 integer, private   :: local_type
 !
 interface PP_redux_wait
   module procedure l1share,l0share,                                   &
&                   i0share, i1share, i2share,i3share,                 &
&                   r0share, r1share, r2share,r3share,r4share,         &
&                   c0share, c1share, c2share,c3share,c4share,c5share, &
&                                     c2share_x,                       &
#if ! defined _DOUBLE
&                   d0share, d1share, d2share,d3share,                 &
&                   dc0share,dc1share,dc2share,                        &
#endif
&                   i81share
 end interface PP_redux_wait
 !
 interface PP_bcast
   module procedure r1bcast,c0bcast,c1bcast,c2bcast,c3bcast,i0bcast,i1bcast,ch0bcast
#if ! defined _DOUBLE
   module procedure                                 z3bcast
#endif
 end interface PP_bcast
 !
 interface PP_send_and_receive
   module procedure PP_snd_rcv_c2,PP_snd_rcv_c1,PP_snd_rcv_r2
 end interface PP_send_and_receive
 !
 interface 
   !
   subroutine PARALLEL_scheme_initialize(WHAT,ENVIRONMENT,PARs,N,TABLE,MATRIX)
     use parallel_m,   ONLY:PAR_scheme
     character(*)               :: WHAT
     character(*)               :: ENVIRONMENT
     type(PAR_scheme)           :: PARs
     integer                    :: N(:)
     logical, optional          :: TABLE
     logical, optional          :: MATRIX
   end subroutine
   !
   subroutine PARALLEL_assign_chains_and_COMMs(n_elements,COMM_index_1,COMM_index_2,COMM_index_3,&
&                                              COMM_index_4,COMM_index_5,COMM_A2A_1,COMM_A2A_2,&
&                                              COMM_A2A_3,COMM_A2A_4,COMM_index_global_2)
     use parallel_m,    ONLY:yMPI_comm
     integer                 :: n_elements
     type(yMPI_comm)          :: COMM_index_1
     type(yMPI_comm),optional :: COMM_index_2
     type(yMPI_comm),optional :: COMM_index_3
     type(yMPI_comm),optional :: COMM_index_4
     type(yMPI_comm),optional :: COMM_index_5
     type(yMPI_comm),optional :: COMM_A2A_1
     type(yMPI_comm),optional :: COMM_A2A_2
     type(yMPI_comm),optional :: COMM_A2A_3
     type(yMPI_comm),optional :: COMM_A2A_4
     type(yMPI_comm),optional :: COMM_index_global_2
   end subroutine
   !
   subroutine PARALLEL_index(px,uplim,low_range,COMM,CONSECUTIVE,ORDERED,NO_EMPTIES,MASK)
     use parallel_m, ONLY:PP_indexes,yMPI_COMM
     type(PP_indexes)       ::px
     integer                ::uplim(:)
     integer, optional      ::low_range(:)
     type(yMPI_COMM),optional::COMM
     logical,       optional::CONSECUTIVE
     logical,       optional::ORDERED
     logical,       optional::NO_EMPTIES
     logical,       optional::MASK(:)
   end subroutine
   !
   subroutine PARALLEL_MATRIX_distribute(COMM,PAR_IND,nb,PAR_index,PAR_ID,PAR_n_elements)
     use parallel_m,    ONLY:yMPI_comm,PP_indexes
     type(yMPI_comm)   :: COMM
     type(PP_indexes) :: PAR_IND
     integer          :: nb(2)
     integer, optional:: PAR_index(:,:)
     integer, optional:: PAR_ID
     integer, optional:: PAR_n_elements
   end subroutine
   !
   subroutine PARALLEL_WF_index(COMM)
     use parallel_m,      ONLY:yMPI_comm
     type(yMPI_comm), optional :: COMM
   end subroutine
   !
   subroutine PARALLEL_global_indexes(E,Xk,q,ENVIRONMENT,X,Dip,RESET,Dip_limits_pre_defined)
     use X_m,           ONLY:X_t
     use DIPOLES,       ONLY:DIPOLE_t
     use electrons,     ONLY:levels
     use R_lattice,     ONLY:bz_samp
     implicit none
     type(levels)             ::E
     type(bz_samp)            ::Xk,q
     character(*)             ::ENVIRONMENT
     type(X_t),       optional::X
     type(DIPOLE_t),  optional::Dip
     logical,         optional::RESET,Dip_limits_pre_defined
   end subroutine
   !
   subroutine PARALLEL_check_phase_space( N_PAR_elements,WORLD,WORLD_size,MSG )
     integer               :: N_par_elements
     integer,     optional :: WORLD,WORLD_size
     character(*),optional :: MSG
   end subroutine
   !
   subroutine PARALLEL_live_message(WHAT,ENVIRONMENT,LOADED,TOTAL,LOADED_r,TOTAL_r,NCPU)
     use pars,           ONLY:SP
     character(*)          :: WHAT
     character(*),optional :: ENVIRONMENT
     integer,     optional :: LOADED,TOTAL,NCPU
     real(SP),    optional :: LOADED_r,TOTAL_r
   end subroutine
   !
   subroutine PARALLEL_WF_distribute(B_index,Bp_index,K_index,B_and_K_index,&
&                                    QP_index,PLASMA_index,Bm_index,CLEAN_UP)
     !
     use parallel_m,      ONLY:PP_indexes
     !
     implicit none
     !
     type(PP_indexes),    optional :: K_index
     type(PP_indexes),    optional :: B_index
     type(PP_indexes),    optional :: Bp_index
     type(PP_indexes),    optional :: B_and_K_index
     type(PP_indexes),    optional :: QP_index
     type(PP_indexes),    optional :: PLASMA_index
     type(PP_indexes),    optional :: Bm_index
     logical, intent(in), optional :: CLEAN_UP
     !
   end subroutine 
   !
 end interface 
 !
 contains
   !
   subroutine PP_wait(COMM)
     integer, optional :: COMM
#if defined _MPI
     integer :: local_COMM
     if (ncpu==1) return
     !
     local_COMM=mpi_comm_world
     if (present(COMM)) local_COMM=COMM
     if (local_COMM==comm_default_value) return
     call mpi_barrier(local_COMM,i_err)
#endif
   end subroutine
   !
   !==========
   ! PP_redux
   !==========
   !
   subroutine l0share(array,imode,COMM)
     logical   :: array
     integer, optional :: imode,COMM
#if defined _MPI
     integer ::omode,LOCAL_COMM
     integer ::dimensions(1),dimension ! Work Space
     logical :: larray    ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     call mpi_barrier(LOCAL_COMM,i_err)
     if (present(imode)) then
       if (imode==1) omode=MPI_LOR
       if (imode==2) omode=MPI_LAND
       if (imode==3) omode=mpi_lor
       if (imode==4) omode=mpi_land
     else
       omode=MPI_LOR
     endif
     larray=.FALSE.
     call mpi_allreduce(array,larray,1,mpi_logical,omode,LOCAL_COMM,i_err)
     array=larray
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine l1share(array,imode,COMM)
     logical   :: array(:)
     integer, optional :: imode,COMM
#if defined _MPI
     integer ::omode,LOCAL_COMM
     integer ::dimensions(1),dimension ! Work Space
     logical,allocatable::larray(:)    ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     call mpi_barrier(LOCAL_COMM,i_err)
     if (present(imode)) then
       if (imode==1) omode=MPI_LOR
       if (imode==2) omode=MPI_LAND
       if (imode==3) omode=mpi_lor
       if (imode==4) omode=mpi_land
     else
       omode=MPI_LOR
     endif
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=.FALSE.
     call mpi_allreduce(array(1),larray,dimension,mpi_logical,omode,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine i0share(ival,imode,COMM)
     integer:: ival
     integer, optional :: imode,COMM
#if defined _MPI
     integer ::omode,LOCAL_COMM
     integer ::local_ival
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     call mpi_barrier(LOCAL_COMM,i_err)
     if (present(imode)) then
       if (imode==1) omode=mpi_sum
       if (imode==2) omode=mpi_prod
     else
       omode=mpi_sum
     endif
     call mpi_allreduce(ival,local_ival,1,mpi_integer,omode,LOCAL_COMM,i_err)
     ival=local_ival
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine i0share
   !
   subroutine i1share(array,imode,COMM)
     integer:: array(:)
     integer, optional :: imode,COMM
#if defined _MPI
     integer ::omode,LOCAL_COMM
     integer ::dimensions(1),dimension ! Work Space
     integer,allocatable::larray(:)    ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     call mpi_barrier(LOCAL_COMM,i_err)
     if (present(imode)) then
       if (imode==1) omode=mpi_sum
       if (imode==2) omode=mpi_prod
     else
       omode=mpi_sum
     endif
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0
     call mpi_allreduce(array(1),larray,dimension,mpi_integer,omode,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine i81share(array,imode,COMM)
     integer(8)        :: array(:)
     integer, optional :: imode,COMM
#if defined _MPI
     integer :: omode,LOCAL_COMM
     integer::dimensions(1),dimension  !Work Space
     integer(8),allocatable::larray(:) !Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     call mpi_barrier(LOCAL_COMM,i_err)
     if (present(imode)) then
       if (imode==1) omode=mpi_sum
       if (imode==2) omode=mpi_prod
     else
       omode=mpi_sum
     endif
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0
     call mpi_allreduce(array(1),larray,dimension,mpi_integer8,omode,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine i2share(array,COMM)
     integer :: array(:,:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(2),dimension,LOCAL_COMM  ! Work Space
     integer,allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0
     call mpi_allreduce(array(1,1),larray,dimension,mpi_integer,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine i3share(array,COMM)
     integer:: array(:,:,:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(3),dimension,LOCAL_COMM  ! Work Space
     integer,allocatable::larray(:) ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0
     call mpi_allreduce(array(1,1,1),larray,dimension,mpi_integer,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine r0share(rval,imode,COMM)
     real(SP)          :: rval
     integer, optional :: imode,COMM
#if defined _MPI
     integer :: omode,LOCAL_COMM  ! Work Space
     real(SP):: local_rval  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_REAL
     if (SP==DP) local_type=MPI_DOUBLE_PRECISION
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     if (present(imode)) then
       if (imode==1) omode=mpi_sum
       if (imode==2) omode=mpi_prod
     else
       omode=mpi_sum
     endif
     local_rval=0.
     call mpi_allreduce(rval,local_rval,1,local_type,omode,LOCAL_COMM,i_err)
     rval=local_rval
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine r1share(array,COMM)
     real(SP) :: array(:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(1),dimension,LOCAL_COMM ! Work Space
     real(SP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_REAL
     if (SP==DP) local_type=MPI_DOUBLE_PRECISION
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0.
     call mpi_allreduce(array(1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine r2share(array,COMM)
     real(SP) :: array(:,:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(2),dimension,LOCAL_COMM  ! Work Space
     real(SP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_REAL
     if (SP==DP) local_type=MPI_DOUBLE_PRECISION
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0.
     call mpi_allreduce(array(1,1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine r3share(array,COMM)
     real(SP):: array(:,:,:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(3),dimension,LOCAL_COMM  ! Work Space
     real(SP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_REAL
     if (SP==DP) local_type=MPI_DOUBLE_PRECISION
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0.
     call mpi_allreduce(array(1,1,1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine r4share(array,COMM)
     real(SP):: array(:,:,:,:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(4),dimension,LOCAL_COMM  ! Work Space
     real(SP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_REAL
     if (SP==DP) local_type=MPI_DOUBLE_PRECISION
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0.
     call mpi_allreduce(array(1,1,1,1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine d0share(rval,imode,COMM)
     real(DP)          :: rval
     integer, optional :: imode,COMM
#if defined _MPI
     integer :: omode,LOCAL_COMM  ! Work Space
     real(DP):: local_rval  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_DOUBLE_PRECISION
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     if (present(imode)) then
       if (imode==1) omode=mpi_sum
       if (imode==2) omode=mpi_prod
     else
       omode=mpi_sum
     endif
     local_rval=0.
     call mpi_allreduce(rval,local_rval,1,local_type,omode,LOCAL_COMM,i_err)
     rval=local_rval
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine d1share(array,COMM)
     real(DP) :: array(:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(1),dimension,LOCAL_COMM ! Work Space
     real(DP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_DOUBLE_PRECISION
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0.
     call mpi_allreduce(array(1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine d2share(array,COMM)
     real(DP) :: array(:,:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(2),dimension,LOCAL_COMM  ! Work Space
     real(DP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_DOUBLE_PRECISION
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0.
     call mpi_allreduce(array(1,1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine d3share(array,COMM)
     real(DP):: array(:,:,:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(3),dimension,LOCAL_COMM  ! Work Space
     real(DP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_DOUBLE_PRECISION
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0.
     call mpi_allreduce(array(1,1,1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine c0share(cval,imode,COMM)
     complex(SP)       :: cval
     integer, optional :: imode,COMM
#if defined _MPI
     integer :: omode,LOCAL_COMM  ! Work Space
     complex(SP):: local_cval  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     if (present(imode)) then
       if (imode==1) omode=mpi_sum
       if (imode==2) omode=mpi_prod
     else
       omode=mpi_sum
     endif
     local_cval=0.
     call mpi_allreduce(cval,local_cval,1,local_type,omode,LOCAL_COMM,i_err)
     cval=local_cval
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine c1share(array,COMM)
     complex(SP):: array(:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(1),dimension,LOCAL_COMM  ! Work Space
     complex(SP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=(0.,0.)
     call mpi_allreduce(array(1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=larray
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine c2share(array,COMM)
     complex(SP):: array(:,:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(2),dimension,LOCAL_COMM  ! Work Space
     complex(SP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=(0.,0.)
     call mpi_allreduce(array(1,1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine

   subroutine c2share_x(array,in_place,COMM)
     complex(SP):: array(:,:)
     logical, intent(IN) :: in_place 
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(2),dimension,LOCAL_COMM  ! Work Space
     if (ncpu==1) return
     !
     if (.not.in_place) then
       if (      present(COMM)) call c2share(array,COMM)
       if (.not. present(COMM)) call c2share(array)
       return
     endif
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     call mpi_allreduce(MPI_IN_PLACE,array,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine c3share(array,COMM)
     complex(SP):: array(:,:,:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(3),dimension,LOCAL_COMM  ! Work Space
     complex(SP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0.
     call mpi_allreduce(array(1,1,1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine c4share(array,COMM)
     complex(SP):: array(:,:,:,:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(4),dimension,LOCAL_COMM  ! Work Space
     complex(SP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0.
     call mpi_allreduce(array(1,1,1,1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine c5share(array,COMM)
     complex(SP):: array(:,:,:,:,:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(5),dimension,LOCAL_COMM  ! Work Space
     complex(SP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=0.
     call mpi_allreduce(array(1,1,1,1,1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine dc0share(cval,imode,COMM)
     complex(DP)       :: cval
     integer, optional :: imode,COMM
#if defined _MPI
     integer :: omode,LOCAL_COMM  ! Work Space
     complex(DP):: local_cval  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     if (present(imode)) then
       if (imode==1) omode=mpi_sum
       if (imode==2) omode=mpi_prod
     else
       omode=mpi_sum
     endif
     local_cval=0.
     call mpi_allreduce(cval,local_cval,1,local_type,omode,LOCAL_COMM,i_err)
     cval=local_cval
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine dc1share(array,COMM)
     complex(DP):: array(:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(1),dimension,LOCAL_COMM  ! Work Space
     complex(DP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=(0.,0.)
     call mpi_allreduce(array(1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=larray
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine dc2share(array,COMM)
     complex(DP):: array(:,:)
     integer, optional :: COMM
#if defined _MPI
     integer::dimensions(2),dimension,LOCAL_COMM  ! Work Space
     complex(DP),allocatable::larray(:)  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_barrier(LOCAL_COMM,i_err)
     dimensions=shape(array)
     if( any(dimensions<1) ) return
     dimension=product(dimensions)
     allocate(larray(dimension))
     larray=(0.,0.)
     call mpi_allreduce(array(1,1),larray,dimension,local_type,mpi_sum,LOCAL_COMM,i_err)
     array=reshape(larray,dimensions)
     deallocate(larray)
     call mpi_barrier(LOCAL_COMM,i_err)
#endif
   end subroutine
   !==========
   ! PP_bcast
   !==========
   subroutine i0bcast(ival,node,COMM)
     integer  :: ival
     integer, intent(in) :: node
     integer, optional   :: COMM
#if defined _MPI
     integer::LOCAL_COMM  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     call mpi_bcast(ival,1,mpi_integer,node,LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine i1bcast(ival,node,COMM)
     integer  :: ival(:)
     integer, intent(in) :: node
     integer, optional   :: COMM
#if defined _MPI
     integer::LOCAL_COMM  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     call mpi_bcast(ival(1),size(ival),mpi_integer,node,LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine c0bcast(cval,node,COMM)
     complex(SP):: cval
     integer, intent(in) :: node
     integer, optional :: COMM
#if defined _MPI
     integer::LOCAL_COMM  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_bcast(cval,1,local_type,node,LOCAL_COMM,i_err)
#endif
   end subroutine
   !
   subroutine c1bcast(array,node,COMM)
     complex(SP):: array(:)
     integer, intent(in) :: node
     integer, optional :: COMM
#if defined _MPI
     integer::LOCAL_COMM  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_bcast(array(1),size(array),local_type, node,LOCAL_COMM, i_err)
#endif
   end subroutine
   !
   subroutine r1bcast(array,node,COMM)
     real(SP):: array(:)
     integer, intent(in) :: node
     integer, optional :: COMM
#if defined _MPI
     integer::LOCAL_COMM  ! Work Space
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_REAL
     if (SP==DP) local_type=MPI_DOUBLE_PRECISION
     !
     call mpi_bcast(array(1),size(array),local_type, node,LOCAL_COMM, i_err)
#endif
   end subroutine
   !
   subroutine ch0bcast(chval,node,COMM)
     character(len=*):: chval
     integer, intent(in) :: node
     integer, optional :: COMM
#if defined _MPI
     integer::LOCAL_COMM  ! Work Space
     integer::imsg(len(chval)), i
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     do i = 1, len(chval)
       imsg(i) = ichar(chval(i:i))
     enddo
     !
     call i1bcast(imsg,node,LOCAL_COMM)
     !
     do i = 1, len(chval)
       chval(i:i) = char(imsg(i))
     enddo
#endif
   end subroutine
   !
   subroutine c2bcast(array,node,COMM)
     implicit none
     complex(SP):: array(:,:)
     integer, intent(in) :: node
     integer, optional :: COMM
#if defined _MPI
     integer::LOCAL_COMM  ! Work Space
     integer::local_type
     !
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_bcast(array,size(array),local_type, node, LOCAL_COMM, i_err)
#endif
   end subroutine c2bcast
   !
   subroutine c3bcast(array,node,COMM)
     implicit none
     complex(SP):: array(:,:,:)
     integer, intent(in) :: node
     integer, optional :: COMM
#if defined _MPI
     integer::LOCAL_COMM  ! Work Space
     integer::local_type
     !
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_bcast(array,size(array),local_type, node, LOCAL_COMM, i_err)
#endif
   end subroutine c3bcast
   !
#if ! defined _DOUBLE
   !
   subroutine z3bcast(array,node,COMM)
     implicit none
     complex(DP):: array(:,:,:)
     integer, intent(in) :: node
     integer, optional :: COMM
#if defined _MPI
     integer::LOCAL_COMM  ! Work Space
     integer::local_type
     !
     if (ncpu==1) return
     !
     if (present(COMM)) then
       LOCAL_COMM=COMM
     else
       LOCAL_COMM=mpi_comm_world
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     local_type=MPI_DOUBLE_COMPLEX
     !
     call mpi_bcast(array,size(array),local_type, node, LOCAL_COMM, i_err)
#endif
   end subroutine z3bcast
   !
#endif
   !============
   ! PP_snd_rcv
   !============
   subroutine PP_snd_rcv_r2(mode,array,node,COMM,TAG)
     character(*):: mode
     real(SP)    :: array(:,:)
     integer, intent(in) :: node
     integer, optional   :: COMM
     integer, optional   :: TAG
#if defined _MPI
     integer, dimension(MPI_STATUS_SIZE) :: MP_status
     integer::LOCAL_COMM,LOCAl_TAG,i_err! Work Space
     if (ncpu==1) return
     !
     local_type=MPI_REAL
     if (SP==DP) local_type=MPI_DOUBLE_PRECISION
     !
     LOCAL_COMM=mpi_comm_world
     if (present(COMM)) then
       LOCAL_COMM=COMM
     endif
     LOCAL_TAG=1
     if (present(TAG)) then
       LOCAL_TAG=TAG
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     if (mode=="send"   ) call MPI_SEND(array,size(array),local_type,node ,LOCAL_TAG, LOCAL_COMM,i_err)
     if (mode=="receive") call MPI_RECV(array,size(array),local_type,node ,LOCAL_TAG, LOCAL_COMM, MP_status, i_err)
     !
#endif
   end subroutine
   !
   subroutine PP_snd_rcv_c2(mode,array,node,COMM,TAG)
     character(*):: mode
     complex(SP) :: array(:,:)
     integer, intent(in) :: node
     integer, optional   :: COMM
     integer, optional   :: TAG
#if defined _MPI
     integer, dimension(MPI_STATUS_SIZE) :: MP_status
     integer::LOCAL_COMM,LOCAl_TAG,i_err! Work Space
     if (ncpu==1) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     LOCAL_COMM=mpi_comm_world
     if (present(COMM)) then
       LOCAL_COMM=COMM
     endif
     LOCAL_TAG=1
     if (present(TAG)) then
       LOCAL_TAG=TAG
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     if (mode=="send"   ) call MPI_SEND(array,size(array),local_type,node ,LOCAL_TAG, LOCAL_COMM,i_err)
     if (mode=="receive") call MPI_RECV(array,size(array),local_type,node ,LOCAL_TAG, LOCAL_COMM, MP_status, i_err)
     !
#endif
   end subroutine
   !   
   subroutine PP_snd_rcv_c1(mode,array,node,COMM,TAG)
     character(*):: mode
     complex(SP) :: array(:)
     integer, intent(in) :: node
     integer, optional   :: COMM
     integer, optional   :: TAG
#if defined _MPI
     integer, dimension(MPI_STATUS_SIZE) :: MP_status
     integer::LOCAL_COMM,LOCAl_TAG,i_err! Work Space
     if (ncpu==1) return
     !
     local_type=MPI_COMPLEX
     if (SP==DP) local_type=MPI_DOUBLE_COMPLEX
     !
     LOCAL_COMM=mpi_comm_world
     if (present(COMM)) then
       LOCAL_COMM=COMM
     endif
     LOCAL_TAG=1
     if (present(TAG)) then
       LOCAL_TAG=TAG
     endif
     if (LOCAL_COMM==comm_default_value) return
     !
     if (mode=="send"   ) call MPI_SEND(array,size(array),local_type,node ,LOCAL_TAG, LOCAL_COMM,i_err)
     if (mode=="receive") call MPI_RECV(array,size(array),local_type,node ,LOCAL_TAG, LOCAL_COMM, MP_status, i_err)
     !
#endif
   end subroutine
   !
end module parallel_int
