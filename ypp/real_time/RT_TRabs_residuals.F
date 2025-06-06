!
! License-Identifier: GPL
!
! Copyright (C) 2021 The Yambo Team
!
! Authors (see AUTHORS file for details): DS AM
!
subroutine RT_TRabs_residuals(what,N_trans,N_dirs,DIP_dir,Xen,Xk,nb,l_EQ)
 !
 use pars,            ONLY:SP,pi,cI
 use R_lattice,       ONLY:bz_samp
 use electrons,       ONLY:levels,n_sp_pol,spin,spin_occ
 use X_m,             ONLY:global_gauge
 use YPP_real_time,   ONLY:TRabs_RES_left,TRabs_RES_right,TRabs_E,TRabs_Eeh_treshold
 use BS,              ONLY:BS_K_dim
 use BS_solvers,      ONLY:BSS_eh_table,BS_mat
 use YPPm,            ONLY:BS_E
 use real_time,       ONLY:RT_bands
 use parallel_m,      ONLY:PAR_IND_DIPk_ibz,PAR_IND_VAL_BANDS_DIP,PAR_IND_CON_BANDS_DIP
 !
#include<y_memory.h>
 !
 character(*)      :: what
 integer           :: N_trans,nb(2),N_dirs
 type(levels)      :: Xen
 type(bz_samp)     :: Xk
 real(SP)          :: DIP_dir(3,3)
 logical           :: l_EQ
 !
 ! Work space
 !
 integer           :: i_lp,i_v,i_c,i_kbz,i_kibz,i_spin,i_l,bands(2,2),i_n,i_np,i_dir
 real(SP)          :: E_eh
 complex(SP)       :: DIP_rotated(3),f_eh(2),DIP_dot,DIP(3)
 !
 ! BSE residuals
 ! -------------
 if (index(what,"BSE")>0) then
   !
   do i_l=1,BS_K_dim(1)
     !
     do i_lp = 1,BS_K_dim(1)
       !
       i_kbz   = BSS_eh_table(i_lp,1)
       i_kibz  = Xk%sstar(i_kbz,1)
       i_v     = BSS_eh_table(i_lp,2)
       i_c     = BSS_eh_table(i_lp,3)
       i_spin  = spin(BSS_eh_table(i_lp,:))
       !
       if (i_v<RT_bands(1) .or. i_c>RT_bands(2) ) cycle
       !
       if (.not. PAR_IND_CON_BANDS_DIP%element_1D(i_c)) cycle
       if (.not. PAR_IND_VAL_BANDS_DIP%element_1D(i_v)) cycle
       if (.not. PAR_IND_DIPk_ibz%element_1D(i_kibz)) cycle
       !
       f_eh=gimme_f_and_delta_f(i_v,i_c,i_kibz,i_spin)
       call DIPOLE_rotate(i_c,i_v,i_kbz,i_spin,"DIP_iR",Xk,DIP)
       DIP_rotated=conjg(-cI*DIP)
       !
       do i_dir=1,N_dirs
         !
         DIP_dot=dot_product(DIP_dir(i_dir,:),DIP_rotated)
         !
         TRabs_RES_right(i_l,i_dir,1)= TRabs_RES_right(i_l,i_dir,1)+&
&                                      conjg(DIP_dot)*BS_mat(i_lp,i_l)*sqrt(f_eh(1))
         TRabs_RES_right(i_l,i_dir,2)= TRabs_RES_right(i_l,i_dir,2)+&
&                                      conjg(DIP_dot)*BS_mat(i_lp,i_l)*f_eh(2)/sqrt(f_eh(1))/sqrt(2._SP)
         TRabs_RES_left(i_l,i_dir,1) = TRabs_RES_left(i_l,i_dir,1)+&
&                                      DIP_dot*conjg(BS_mat(i_lp,i_l))*sqrt(f_eh(1))
         TRabs_RES_left(i_l,i_dir,2) = TRabs_RES_left(i_l,i_dir,2)+&
&                                      DIP_dot*conjg(BS_mat(i_lp,i_l))*f_eh(2)/sqrt(f_eh(1))/sqrt(2._SP)
       enddo
       !
       if (i_l==1) TRabs_E(i_lp)   = real(BS_E(i_lp),SP)
       !
     enddo
     !
   enddo
   !
   N_trans=BS_K_dim(1)
   !
   return
   !
 endif
 !
 ! IP residuals
 ! -------------
 if (index(what,"IP")>0) then
   !
   if (index(what,"cv")>0) then
     bands(1,:)=(/nb(1)+1,RT_bands(2)/)
     bands(2,:)=(/RT_bands(1),nb(2)/)
   else if (index(what,"vv")>0) then
     bands(1,:)=(/RT_bands(1),nb(1)/)
     bands(2,:)=bands(1,:)
   else if (index(what,"cc")>0) then
     bands(1,:)=(/nb(2)+1,RT_bands(2)/)
     bands(2,:)=bands(1,:)
   endif
   !
   do i_kbz=1,Xk%nbz
     i_kibz=Xk%sstar(i_kbz,1)
     do i_spin=1,n_sp_pol
       do i_n=bands(1,1),bands(1,2)
         do i_np=bands(2,1),bands(2,2)
           !
           E_eh=Xen%E(i_n,i_kibz,i_spin)-Xen%E(i_np,i_kibz,i_spin)
           f_eh=gimme_f_and_delta_f(i_np,i_n,i_kibz,i_spin)
           !
           ! Select just "resonant" (in the causal sense) transitions
           if (real(f_eh(1)+f_eh(2))<0._SP) cycle
           !
           if (l_EQ) f_eh(2)=f_eh(2)+f_eh(1)
           !
           if (abs(E_eh) < TRabs_Eeh_treshold.and. trim(global_gauge)=="length") cycle
           !
           N_trans=N_trans+1
           !
           if (.not. PAR_IND_DIPk_ibz%element_1D(i_kibz)) cycle
           if (.not. PAR_IND_CON_BANDS_DIP%element_1D(i_np)) cycle
           if (.not. PAR_IND_VAL_BANDS_DIP%element_1D(i_n)) cycle
           !
           TRabs_E(N_trans)=E_eh
           call DIPOLE_rotate(i_np,i_n,i_kbz,i_spin,"DIP_iR",Xk,DIP)
           DIP_rotated=conjg(-cI*DIP)
           !
           do i_dir=1,N_dirs
             TRabs_RES_right(N_trans,i_dir,1)= conjg(dot_product(DIP_dir(i_dir,:),DIP_rotated))*sqrt(f_eh(2))
             TRabs_RES_left(N_trans,i_dir,1) =       dot_product(DIP_dir(i_dir,:),DIP_rotated) *sqrt(f_eh(2))
           enddo
           !
         enddo
       enddo
     enddo
   enddo
   !
   return
   !
 endif
 !
 contains
   !
   function gimme_f_and_delta_f(ib,ibp,ik,i_sp)
     complex(SP) :: gimme_f_and_delta_f(2)
     real(SP)    :: Delta_f,Delta_df
     integer     :: ib,ibp,i_sp,ik
     Delta_f=(Xen%fo(ib,ik,i_sp)-Xen%fo(ibp,ik,i_sp))/spin_occ
     Delta_df=(Xen%f(ib,ik,i_sp)-Xen%f(ibp,ik,i_sp))/spin_occ-Delta_f
     gimme_f_and_delta_f(1)=Delta_f
     gimme_f_and_delta_f(2)=Delta_df
   end function 
   !
end subroutine RT_TRabs_residuals
