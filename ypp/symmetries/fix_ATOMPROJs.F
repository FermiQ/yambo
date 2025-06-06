!
! License-Identifier: GPL
!
! Copyright (C) 2019 The Yambo Team
!
! Authors (see AUTHORS file for details): DS
!
subroutine fix_ATOMPROJs(E,k,k_save,kpoints_map,old_nsym,old_dl_sop,old_sop_inv,S_contains_TR)
 !
 use pars,                ONLY:SP,lchlen,cZERO
 use com,                 ONLY:msg,core_io_path,more_io_path
 use IO_int,              ONLY:io_control
 use IO_m,                ONLY:NONE,OP_APP_CL,OP_RD,VERIFY,&
&                              OP_APP,cp_file,OP_RD_CL,RD_CL,RD,DUMP
 use electrons,           ONLY:n_sp_pol
 use LIVE_t,              ONLY:live_timing
 use stderr,              ONLY:intc
 use R_lattice,           ONLY:bz_samp
 use electrons,           ONLY:levels
 use atom_proj
 !
#include<y_memory.h>
 !
 type(levels),intent(in)  :: E
 !
 type(bz_samp),intent(in) :: k
 type(bz_samp),intent(in) :: k_save
 integer,intent(in)       :: kpoints_map(2,k%nibz)
 !
 integer,intent(in)       :: old_nsym
 real(SP),intent(in)      :: old_dl_sop(3,3,old_nsym)
 integer,intent(in)       :: old_sop_inv(old_nsym)
 logical,intent(in)       :: S_contains_TR(old_nsym)
 !
 ! Work space
 !
 character(lchlen)     :: core_io_path_save,fragment_name,fragment_name_new
 integer               :: n_steps,ID
 integer               :: ierr,io_err
 !
 complex(SP),allocatable :: atom_proj_store(:,:,:,:)
 !
 ! Dummies
 !
 integer               :: is,i_sp_pol,ik,ik_save,ifrag,ifrag_new
 !
 ! External functions
 !
 integer, external :: io_ATMPROJ_pwscf
 !
 ! Check the presence of ATOMPROJs DB
 !
 n_steps=k%nibz-k_save%nibz
 !
 io_err = -1
 !
 call io_control(ACTION=OP_RD_CL,COM=NONE,SEC=(/1/),MODE=VERIFY,ID=ID)
 io_err=io_ATMPROJ_pwscf(ID)
 !
 if (io_err/=0) return
 !
 call section('=',"Atomic projections (PWSCF)")
 !
 call io_control(ACTION=OP_RD,COM=NONE,SEC=(/1/),MODE=DUMP,ID=ID)
 io_err=io_ATMPROJ_pwscf(ID)
 !
 YAMBO_ALLOC(atom_proj_store,(n_atom_wfc,n_proj_bands,k_save%nibz,n_sp_pol))
 !
 do i_sp_pol=1,n_sp_pol
   do ik=1,k_save%nibz
     !
     ifrag=ik+(i_sp_pol-1)*k_save%nibz
     !
     if (ifrag< n_sp_pol*k_save%nibz) call io_control(ACTION=RD,SEC=(/ifrag+1/),ID=ID)
     if (ifrag==n_sp_pol*k_save%nibz) call io_control(ACTION=RD_CL,SEC=(/ifrag+1/),ID=ID)
     io_err=io_ATMPROJ_pwscf(ID)
     !
     atom_proj_store(:,:,ik,i_sp_pol)=atomic_projections(:,:,ik,i_sp_pol)
     !
   enddo
 enddo
 !
 core_io_path_save=core_io_path
 core_io_path=more_io_path
 !
 YAMBO_FREE(atomic_projections)
 YAMBO_ALLOC(atomic_projections,(n_atom_wfc,n_proj_bands,k%nibz,n_sp_pol))
 atomic_projections=cZERO
 !
   !
   call msg('s',' Copying existing database ...')
   !
   call cp_file(trim(core_io_path_save)//"/SAVE/ns.atom_proj_pwscf",trim(more_io_path)//"/SAVE",ierr)
   do i_sp_pol=1,n_sp_pol
     do ik=1,k_save%nibz
       ifrag=ik+(i_sp_pol-1)*k_save%nibz
       ifrag_new=ik+(i_sp_pol-1)*k%nibz
       fragment_name    ='ns.atom_proj_pwscf_fragment_'//trim(intc(ifrag))
       fragment_name_new='ns.atom_proj_pwscf_fragment_'//trim(intc(ifrag_new))
       call cp_file(trim(core_io_path_save)//"/SAVE/"//trim(fragment_name),&
&                   trim(more_io_path)//"/SAVE/"//trim(fragment_name),ierr)
       fragment_name='s.atom_proj_pwscf_fragment_'//trim(intc(ifrag))
       fragment_name_new='s.atom_proj_pwscf_fragment_'//trim(intc(ifrag_new))
       call cp_file(trim(core_io_path_save)//"/SAVE/"//trim(fragment_name),&
&                   trim(more_io_path)//"/SAVE/"//trim(fragment_name),ierr)
     enddo
   enddo
   !
   if(n_steps>0) call live_timing('Atomic projections rotation',n_steps*n_sp_pol)
   !
   call warning(' After rotation m projections will be meaningless')
   !
   ! 2019/01/10: to fix this the rotation matrix in the angular momentum
   !             channel should be used
   !
   do i_sp_pol=1,n_sp_pol
     do ik=k_save%nibz+1,k%nibz
       !
       ifrag=ik+(i_sp_pol-1)*k%nibz
       !
       ik_save=kpoints_map(1,ik)
       is=kpoints_map(2,ik)
       !
       atomic_projections(:,:,ik,i_sp_pol)=atom_proj_store(:,:,ik_save,i_sp_pol)
       !
       call io_control(ACTION=OP_APP_CL,COM=NONE,SEC=(/ifrag+1/),ID=ID)      
       io_err=io_ATMPROJ_pwscf(ID)
       !
       call live_timing(steps=1)
       !
     enddo
   enddo
   !
   if(n_steps>0) call live_timing()
   !
 core_io_path=core_io_path_save
 !
end subroutine fix_ATOMPROJs
