!
! License-Identifier: GPL
!
! Copyright (C) 2013 The Yambo Team
!
! Authors (see AUTHORS file for details): AM
!
subroutine COLLISIONS_alloc_and_free(what,elements,actions,I)
 !
 use pars,           ONLY:cZERO,rZERO,DP,SP
 use plasma,         ONLY:N_plasma_poles_global
 use R_lattice,      ONLY:nqbz,nkibz
 use parallel_m,     ONLY:PAR_nPlasma,PAR_nQ_bz
 use collision_ext,  ONLY:COLLISIONS_element,COH_COLL_element,HXC_COLL_element,GW_NEQ_COLL_element,&
&                         COLL_bands,COLLISIONS_load_SP,&
&                         GW_NEQ_collisions,COH_collisions,HXC_collisions,P_collisions,COLLISIONS_group
#if defined _QED
 use QP_m,           ONLY:QP_QED_ng
 use collision_ext,  ONLY:P_COLL_element
#endif
 !
#include<y_memory.h>
 !
 character(*)             :: what,elements,actions
 integer                  :: I
 !
 ! Work Space
 !
 integer :: D(3,2),COLL_range(2),J,K,mem_size(5),size_
 logical :: l_COH,l_HXC,l_GW_NEQ,l_v3,l_v1,l_table,l_all,l_alloc,&
&           l_clean,l_collision,l_distribute,l_Momentum,l_complex,l_real
 !
 ! What
 !
 l_COH     =index(what,"COH")     >0
 l_HXC     =index(what,"HXC")     >0.or.index(what,"SEX")>0.or.&
&           index(what,"FOCK")>0.or.index(what,"HARTREE")>0.or.&
&           index(what,"GS_xc")>0
 l_GW_NEQ  =index(what,"GW_NEQ")  >0
 l_Momentum=index(what,"Momentum")>0
 !
 ! Dimension
 !
 if (I==0) then
   if (l_COH)      COLL_range=(/1,   COH_collisions%PAR_N/)
   if (l_HXC)      COLL_range=(/1,   HXC_collisions%PAR_N/)
   if (l_GW_NEQ)   COLL_range=(/1,GW_NEQ_collisions%PAR_N/)
   if (l_Momentum) COLL_range=(/1,     P_collisions%PAR_N/)
   size_=COLL_range(2)
 endif
 if (I> 0) COLL_range=(/I,I/)
 if (I> 0) size_=1
 !
 l_complex=l_COH.or.l_HXC
 l_real   =l_GW_NEQ.or.l_Momentum
 !
 ! Elements
 !
 l_v1   =index(elements,"v1")>0
 l_v3   =index(elements,"v3")>0
 l_all  =index(elements,"all")>0
 l_table    =index(elements,"table")>0
 l_collision=index(elements,"coll")>0
 !
 ! Actions
 !
 l_alloc     =index(actions,"alloc")>0
 l_clean     =index(actions,"clean")>0
 l_distribute=index(actions,"distribute")>0
 !
 if (l_COH) then
   D(1,:)=COLL_bands
   D(2,:)=COLL_bands
   D(3,:)=(/1,nkibz/)
   if (l_collision.and.l_alloc) then
     allocate(COH_COLL_element(size_))
     COH_COLL_element%N=size_
   endif
   call local_alloc_and_free(COH_COLL_element,COH_collisions)
   if ((l_collision.or.l_all).and.l_clean) then
     if (allocated(COH_COLL_element)) then
       call local_alloc_and_free(COH_COLL_element,COH_collisions)
       deallocate(COH_COLL_element)
     endif
   endif
 endif
 !
 if (l_HXC) then
   D(1,:)=COLL_bands
   D(2,:)=COLL_bands
   D(3,:)=(/1,nkibz/)
   if (l_collision.and.l_alloc) then
     allocate(HXC_COLL_element(size_))
     HXC_COLL_element%N=size_
   endif
   call local_alloc_and_free(HXC_COLL_element,HXC_collisions)
   if ((l_collision.or.l_all).and.l_clean) then
     if (allocated(HXC_COLL_element)) then
       call local_alloc_and_free(HXC_COLL_element,HXC_collisions)
       deallocate(HXC_COLL_element)
     endif
   endif
 endif
 !
#if defined _QED
 !
 if (l_Momentum) then
   D(1,:)=(/1,QP_QED_ng/)
   D(2,:)=COLL_bands
   D(3,:)=(/1,nqbz/)
   if (l_collision.and.l_alloc) then
     allocate(P_COLL_element(size_))
     P_COLL_element%N=size_
   endif
   call local_alloc_and_free(P_COLL_element,P_collisions)
   if ((l_collision.or.l_all).and.l_clean) then
     if (allocated(P_COLL_element)) then
       call local_alloc_and_free(P_COLL_element,P_collisions)
       deallocate(P_COLL_element)
     endif
   endif
 endif
 !
#endif
 !
 if (l_GW_NEQ) then
   D(1,:)=(/1,N_plasma_poles_global/)
   D(2,:)=(/1,1/)
   D(3,:)=(/1,nqbz/)
   if (l_distribute.and.(l_v3.or.l_table)) then
     D(1,:)=(/1,PAR_nPlasma/)
     D(3,:)=(/1,PAR_nQ_bz/)
   endif
   if (l_collision.and.l_alloc) then
     allocate(GW_NEQ_COLL_element(size_))
     GW_NEQ_COLL_element%N=size_
   endif
   call local_alloc_and_free(GW_NEQ_COLL_element,GW_NEQ_collisions)
   if((l_collision.or.l_all).and.l_clean) then
     if (allocated(GW_NEQ_COLL_element)) then
       call local_alloc_and_free(GW_NEQ_COLL_element,GW_NEQ_collisions)
       deallocate(GW_NEQ_COLL_element)
     endif
   endif
 endif
 !
 contains
   !
   subroutine local_alloc_and_free(COLL,COLL_grp)
     type(COLLISIONS_group)   :: COLL_grp
     type(COLLISIONS_element) :: COLL(COLL_grp%N)
     if(COLL_grp%N==0) return
     mem_size=0
     do J=COLL_range(1),COLL_range(2)
       !
       ! Here I assign to each collision element an index corresponding to the REAL collision
       ! allocated. This is because J runs on the parallel components and not on the real ones.
       !
       do K=1,COLL_grp%N
         if (COLL_grp%PAR_map(K)==J) COLL(J)%I=K
       enddo
       !
       if (l_alloc.and.(l_v3.or.l_all)) then
         if(l_real) then
           YAMBO_ALLOC(COLL(J)%v3_r,(D(1,1):D(1,2),D(2,1):D(2,2),D(3,1):D(3,2)))
           COLL(J)%v3_r=rZERO
           mem_size(1)=mem_size(1)+size(COLL(J)%v3_r)
         endif
         if(l_complex) then
           YAMBO_ALLOC(COLL(J)%v3_c,(D(1,1):D(1,2),D(2,1):D(2,2),D(3,1):D(3,2)))
           COLL(J)%v3_c=cZERO
           mem_size(2)=mem_size(2)+size(COLL(J)%v3_c)
         endif
         COLL_grp%D=D
       endif
       if (l_clean.and.(l_v3.or.l_all)) then
         if (l_real   .and.allocated(COLL(J)%v3_r)) then
           YAMBO_FREE(COLL(J)%v3_r)
         endif
         if (l_complex.and.allocated(COLL(J)%v3_c)) then
            YAMBO_FREE(COLL(J)%v3_c)
         endif
       endif
       if (l_alloc.and.(l_v1.or.l_all)) then
         if(l_real) then
           YAMBO_ALLOC(COLL(J)%v_r,(COLL(J)%N))
           COLL(J)%v_r=rZERO
           mem_size(3)=mem_size(3)+size(COLL(J)%v_r)
         endif
         if(l_complex) then
           YAMBO_ALLOC(COLL(J)%v_c,(COLL(J)%N))
           COLL(J)%v_c=cZERO
           mem_size(4)=mem_size(4)+size(COLL(J)%v_c)
           if(SP==DP.and.COLLISIONS_load_SP) then
             YAMBO_ALLOC(COLL(J)%v_c_SP,(COLL(J)%N))
             COLL(J)%v_c_SP=cZERO
             mem_size(4)=mem_size(4)+size(COLL(J)%v_c_SP)
           endif
         endif
       endif
       if (l_clean.and.(l_v1.or.l_all)) then
         YAMBO_FREE(COLL(J)%v_c)
         if(SP==DP.and.allocated(COLL(J)%v_c_SP)) then
            YAMBO_FREE(COLL(J)%v_c_SP)
         endif
         YAMBO_FREE(COLL(J)%v_r)
       endif
       if (l_alloc.and.(l_table.or.l_all)) then
         !AMBO_ALLOC(COLL(J)%table,(D(1,1):D(1,2),D(2,1):D(2,2),D(3,1):D(3,2)))
         allocate(COLL(J)%table(D(1,1):D(1,2),D(2,1):D(2,2),D(3,1):D(3,2)))
         COLL(J)%table='f'
         COLL_grp%D=D
         mem_size(5)=mem_size(5)+size(COLL(J)%table)
       endif
       if (l_clean.and.(l_table.or.l_all)) then
         !AMBO_FREE(COLL(J)%table)
         deallocate(COLL(J)%table)
       endif
     enddo
     !
   end subroutine
   !
end subroutine
