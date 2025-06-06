!
! License-Identifier: GPL
!
! Copyright (C) 2015 The Yambo Team
!
! Authors (see AUTHORS file for details): AM DS
!
function TDDFT_ALDA_eh_space_R_kernel(is,os,isp,osp,tddft_wf,mode) result(H_x)
 !
 ! Calculates the F_xc scattering 
 !
 ! mode 1 
 !
 !  (ic(1),ik(1),is(1)) --<--:...:--<-- (ic(2),ik(2),is(2))
 !                              :Fxc:
 !  (iv(1),ik(3),is(3)) -->--:...:-->-- (iv(2),ik(4),is(4))
 !
 ! mode 2
 !
 !  (ic(1),ik(1),is(1)) --<--:...:--<-- (iv(2),ik(2),is(2))
 !                              :Fxc:
 !  (iv(1),ik(3),is(3)) -->--:...:-->-- (ic(2),ik(4),is(4))
 !
 use pars,           ONLY:SP,pi,cZERO
 use FFT_m,          ONLY:fft_size
 use xc_functionals, ONLY:F_xc_mat
 use BS,             ONLY:l_BS_magnons
 use wrapper_omp,    ONLY:V_dot_V_omp
 use electrons,      ONLY:n_spinor,n_sp_pol,n_spin
 use timing_m,       ONLY:timing
 use interfaces,     ONLY:WF_apply_symm
 use TDDFT,          ONLY:tddft_wf_t
 !
 implicit none
 !
 complex(SP) :: H_x
 !
 integer,          intent(in)  :: is(4),os(4),isp(4),osp(4)
 character(3),     intent(in)  :: mode
 type(tddft_wf_t), target, intent(inout) :: tddft_wf 
 ! 
 ! Work Space
 !
 integer     :: i_spinor,j_spinor,ip_spinor,jp_spinor,ifft,irhotw,&
 &              is_yambo,os_yambo,i_spinor_y,j_spinor_y,isp_loc(4),osp_loc(4)
 !
 complex(SP), pointer :: rhotwr1_p(:)
 complex(SP), pointer :: rhotwr2_p(:)
 complex(SP), pointer :: WF_symm1_p(:,:)
 complex(SP), pointer :: WF_symm2_p(:,:)
 !
 call timing('T_space ALDA scatt.',OPR='start')
 !
 if ((is(4)/=os(4).or.isp(4)/=osp(4)).and.((.not.l_BS_magnons).or. n_sp_pol==1)) call error(" TDDFT_ALDA_R_space: wrong spin index")
 if ((is(4)==os(4).or.isp(4)==osp(4)).and.((     l_BS_magnons).and.n_sp_pol==2)) call error(" TDDFT_ALDA_R_space: wrong spin index")
 if (mode/="RES" .and. mode/="CPL" ) call error(" TDDFT_ALDA_R_space: unkown mode")
 !
 H_x=cZERO
 !
 WF_symm1_p => tddft_wf%WF_symm1
 WF_symm2_p => tddft_wf%WF_symm2
 rhotwr1_p  => tddft_wf%rhotwr1
 rhotwr2_p  => tddft_wf%rhotwr2
 !
 WF_symm1_p=cZERO
 WF_symm2_p=cZERO
 rhotwr1_p =cZERO
 rhotwr2_p =cZERO
 !
 ! Use pointers both for CUDA and to avoid continuous allocation and de-allocation
 !
 !
 call WF_apply_symm(is,WF_symm1_p)
 call WF_apply_symm(os,WF_symm2_p)
 !
 if(n_spinor==1) rhotwr1_p(:)=conjg(WF_symm1_p(:,1))*WF_symm2_p(:,1)
 !
 if(n_spinor==2) then
   do i_spinor=1,n_spinor
     do j_spinor=1,n_spinor
       do ifft=1,fft_size
         irhotw=ifft+(i_spinor-1)*fft_size+(j_spinor-1)*n_spinor*fft_size
	 rhotwr1_p(irhotw)=conjg(WF_symm1_p(ifft,i_spinor))*WF_symm2_p(ifft,j_spinor)
       enddo
     enddo
   enddo
 endif
 !
 if (mode=="RES") then
   isp_loc=isp
   osp_loc=osp
 else if (mode=="CPL") then
   ! Same momenta, inverted band and spin indexes
   isp_loc=(/osp(1),isp(2),isp(3),osp(4)/)
   osp_loc=(/isp(1),osp(2),osp(3),isp(4)/)
 endif
 !
 call WF_apply_symm(isp_loc,WF_symm1_p)
 call WF_apply_symm(osp_loc,WF_symm2_p)
 !
 if( n_spin==1 ) then
   rhotwr2_p(:)=F_xc_mat(:,1,1,1,1)*WF_symm1_p(:,1)*conjg(WF_symm2_p(:,1))
 endif
 !
 if(n_sp_pol==2) then
   ! This takes into account the different conventions between the definition of the spin indexes
   ! between yambo and the derivation of fxc in spin space for magnons
   ! This happens because in the yambo convention the left indexes "v sigma_v, c sigma_c, k" are inverted
   ! with respect to the standard convention, i.e. "c sigma_c, v sigma_v, k"
   ! As a result f_\up\dn,\dn\up is in yambo f_\dn\up,\dn\up and so on
   is_yambo=os(4)
   os_yambo=is(4)
   ! To check/fix the spinorial version 
   rhotwr2_p(:)=F_xc_mat(:,is_yambo,os_yambo,isp(4),osp(4))*WF_symm1_p(:,1)*conjg(WF_symm2_p(:,1))
 endif
 !
 if(n_spinor==2) then
   rhotwr2_p=cZERO
   do i_spinor=1,n_spinor
     do j_spinor=1,n_spinor
       i_spinor_y=j_spinor
       j_spinor_y=i_spinor
       do ip_spinor=1,n_spinor
         do jp_spinor=1,n_spinor
           do ifft=1,fft_size
             irhotw=ifft+(i_spinor-1)*fft_size+(j_spinor-1)*n_spinor*fft_size
             rhotwr2_p(irhotw)=rhotwr2_p(irhotw)+                        &
             & F_xc_mat(ifft,i_spinor_y,j_spinor_y,ip_spinor,jp_spinor)* &
	     & WF_symm1_p(ifft,ip_spinor)*conjg(WF_symm2_p(ifft,jp_spinor))
           enddo
         enddo
       enddo
     enddo
   enddo
 endif
 !
 ! SUM
 !=====
 H_x=V_dot_V_omp(fft_size*n_spinor*n_spinor,rhotwr1_p,rhotwr2_p)
 !
 ! tddft_alda_r_space should be mutiplied by X, it is mutiplied by Co in K
 ! X  = fft_size*spin_occ/DL_vol/Nq 
 ! Co =     4*pi*spin_occ/DL_vol/Nq
 ! --> X/Co = fft_size/4/pi
 !
 H_x=H_x*real(fft_size,SP)/4._SP/pi
 !
 nullify(WF_symm1_p)
 nullify(WF_symm2_p)
 nullify(rhotwr1_p)
 nullify(rhotwr2_p)
 !
 call timing('T_space ALDA scatt.',OPR='stop')
 !
end function
