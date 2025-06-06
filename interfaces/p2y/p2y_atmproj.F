!
! License-Identifier: GPL
!
! Copyright (C) 2018 The Yambo Team
!
! Authors (see AUTHORS file for details): DS DV
!
subroutine p2y_atmproj(filename,k)
 !
 use pars,                  ONLY:SP,DP,schlen
 use R_lattice,             ONLY:bz_samp
 use electrons,             ONLY:n_sp_pol
 use atom_proj,             ONLY:atomic_projections,atomic_table,n_atom_wfc,n_proj_bands
 use IO_int,                ONLY:io_control
 use IO_m,                  ONLY:OP_WR_CL,OP_APP_CL,REP
 !
 use atmproj_tools_module,  ONLY:atmproj_read_ext !,nwfcx
 use qe_pseudo_m,           ONLY:nsp
 !
#include<y_memory.h>
 !
 character(schlen), intent(in) :: filename
 type(bz_samp),     intent(in) :: k
 !
 ! Work space
 !
 integer  :: nkpts,nspin,ik,i_sp_pol
 !
 ! I/O
 !
 integer           :: io_err,ID
 integer, external :: io_ATMPROJ_pwscf
 !
 ! Allocs
 !
 complex(DP), allocatable  :: atomic_projections_dp(:,:,:,:)
 !
 ! (a) get dimensions
 !
 call atmproj_read_ext(filename,NBND=n_proj_bands,NKPT=nkpts,NSPIN=nspin,NATOMWFC=n_atom_wfc,IERR=io_err)
 !
 if (nspin/=n_sp_pol) call error(' nspin is not consistent with n_sp_pol')
 !
 ! (b) get projetions
 !
 YAMBO_ALLOC(atomic_projections_dp,(n_atom_wfc,n_proj_bands,nkpts,nspin))
 !
 call atmproj_read_ext(filename,proj=atomic_projections_dp,IERR=io_err)
 !
 ! (c) consstructu the indexes and store them in yambo format
 !
 YAMBO_ALLOC(atomic_projections,(n_atom_wfc,n_proj_bands,nkpts,nspin))
 YAMBO_ALLOC(atomic_table,(6,n_atom_wfc))
 !
 call fill_atomic_table()
 !
 call io_control(ACTION=OP_WR_CL,COM=REP,SEC=(/1/),ID=ID)
 io_err=io_ATMPROJ_pwscf(ID)
 !
 do i_sp_pol=1,n_sp_pol
   do ik=1,nkpts
     !
     atomic_projections(:,:,ik,i_sp_pol)=cmplx(atomic_projections_dp(:,:,ik,i_sp_pol),kind=SP)
     !
     call io_control(ACTION=OP_APP_CL,COM=REP,SEC=(/ik+(i_sp_pol-1)*nkpts+1/),ID=ID)
     io_err=io_ATMPROJ_pwscf(ID)
     !
   enddo
 enddo
 !
 YAMBO_FREE(atomic_projections)
 YAMBO_FREE(atomic_table)
 !
 contains
   !
   subroutine fill_atomic_table()
     !
     use qe_pseudo_m,      ONLY:ityp,nat
     use uspp_param,       ONLY:upf
     !
     implicit none
     !
     integer ::   ia,itype,iwfc,il,im,indx,j2,j2_lims(2)
     !
     indx=0
     do ia = 1, nat
       itype = ityp(ia)
       j2=0
       do iwfc = 1,upf(itype)%nwfc
         il = upf(itype)%lchi(iwfc)+1
         !
         if ( any(upf(:)%has_so) ) then
           !
           ! Case with SOC
           !
           if (      upf(itype)%has_so ) j2_lims = nint(2._SP*upf(itype)%jchi(iwfc))
           if ( .not.upf(itype)%has_so ) then
             if( il==1) j2_lims = (/il,il/)
             if( il/=1) j2_lims = (/2*il-3,2*il-1/)
           endif
           do j2=j2_lims(1),j2_lims(2),2 
             if ( .not. upf(itype)%oc(iwfc) >= 0.0d0 ) cycle
             do im=1,j2+1
               !DEBUG <
               !write(*,*) ia,itype,real(j2,SP)/2._SP,il-1._SP,real(im-1,SP)-real(j2)/2._SP
               !DEBUG >
               indx=indx+1
               atomic_table(:,indx)=(/ia,itype,iwfc,j2,il,im/)
             enddo
           enddo
           !
         else
           !
           ! Case without SOC
           !
           do im=1,2*il-1
             !DEBUG <
             !write(*,*)ia,itype,il-1._SP,real(im-il,SP)
             !DEBUG >
             indx=indx+1
             atomic_table(:,indx)=(/ia,itype,iwfc,j2,il,im/)
           enddo
           !
         endif
         !
       enddo
     enddo
     !
     !DEBUG <
     !write(*,*) "nproj= ",indx
     !DEBUG >
     !
   end subroutine fill_atomic_table
   !
end subroutine p2y_atmproj
