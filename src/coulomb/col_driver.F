!
! License-Identifier: GPL
!
! Copyright (C) 2006 The Yambo Team
!
! Authors (see AUTHORS file for details): AM
!
! DESCRIPTION :
! 
! the variables generated/read in this series of rotuines are:
!
! RIM_qpg(q,G1,G2)=\int_{BZ`(Gamma)} \d^3q`/(2*pi**3) 2/(|q+q`+G1||q+q`+G2|)
!
!  calculated by means of Montecarlo technique, that is
!
! \int_{BZ`(Gamma)} \d^3q` F(q`) \sim Volout/Nrout \sum_{ir} F(q_ir)      
!
! where ir=1,RIM_n_rand_pts is the index of the random points generated in the large
! volume 8.*k_grid_uc_vol (that must contain the region BZ`) that are in the
! region BZ`.
!
! Now some derivated quantities
!
! 4 pi / |q+G|^2 = 2 pi DLVol NqBZ qpg(q,G)                                  
! |q+G| = Sqrt[ 2 / ( DLVol NqBZ qpg(q,G)) ]                                  
!
#include<dev_defs.h>
!
subroutine col_driver(bare_NG,q)
 !
 !Here I launch the routine to create/read the 
 !db.RIM file after some important checks and definitions.
 !	
 use pars,          ONLY:SP,schlen,pi
 use drivers,       ONLY:l_rim,l_col_cut
 use parser_m,      ONLY:parser
 use stderr,        ONLY:STRING_pack,intc,gen_fmt,STRING_split
 use com,           ONLY:msg
 use vec_operate,   ONLY:iku_v_norm,sort
 use frequency,     ONLY:w_samp
 use D_lattice,     ONLY:DL_vol
 use R_lattice,     ONLY:d3q_factor,RIM_is_diagonal,RIM_qpg,bare_qpg,&
&                        nqibz,g_vec,q_pt,nqbz,RIM_ng,RIM_n_rand_pts,&
&                        bz_samp,q_norm,cutoff_presets,bare_qpg_d,&
&                        cut_geometry,cut_is_slab,idir,q0_def_norm
 use wave_func,     ONLY:wf_ng
 use IO_int,        ONLY:io_control
 use IO_m,          ONLY:OP_RD_CL,OP_WR_CL,REP,VERIFY
 !
#include<y_memory.h>
 !
 integer       :: bare_NG
 type(bz_samp) :: q
 !
 ! Work Space
 !
 type(w_samp) :: Xw
 logical          :: l_RandQpts,is_cut(3)
 integer          :: ig,iq,ID,io_err
 integer, external:: io_RIM
 !
 ! Messagging...
 !
 integer          :: q_norm_i(nqibz),i1,i2
 real(SP)         :: r_dum(2),q_norm_s(nqibz)
 character(schlen):: ch_dum,fmt_dum,msg_dum(2)
 character(schlen):: str_piece(5)
 !
 ! Bare interaction
 !
 YAMBO_ALLOC(bare_qpg,(nqibz,max(bare_NG,wf_ng)))
 bare_qpg(1,1)=q_norm(1)
 do ig=2,max(bare_NG,wf_ng)
   bare_qpg(1,ig)=iku_v_norm(g_vec(ig,:))
 enddo
 do iq=2,nqibz
   do ig=1,max(bare_NG,wf_ng)
     bare_qpg(iq,ig)=iku_v_norm(q_pt(iq,:)+g_vec(ig,:))
   enddo
 enddo
 !
 if (l_rim) l_rim=all((/RIM_ng>0,RIM_n_rand_pts>0/))
 !
 ! In case I am not using the RIM I need to reset
 ! NG and n_rand_pts as they are dumped from the DB and
 ! they are not zero even if l_rim=F. This means that the BS DB (for example)
 ! is not recalculated if l_rim=F whene there is a precalculated db.RIM
 !
 if (.not.l_rim) then
   RIM_ng=0
   call parser('RandQpts',l_RandQpts)
   if (.not.l_RandQpts) RIM_n_rand_pts=0
 endif
 !
 call parser('QpgFull',RIM_is_diagonal)
 RIM_is_diagonal=.not.RIM_is_diagonal
 !
 !Here, we need to check if we want to perform the RIM
 !of bare_qpg or the RIM of cutoff_slab
 !
 call STRING_split(cut_geometry,str_piece)
 !
 cut_is_slab=trim(str_piece(1))=='slab'
 !
 ! Cutoffed directions
 !
 is_cut(1)=index(str_piece(2),'x')/=0.or.index(str_piece(2),'X')/=0
 is_cut(2)=index(str_piece(2),'y')/=0.or.index(str_piece(2),'Y')/=0
 is_cut(3)=index(str_piece(2),'z')/=0.or.index(str_piece(2),'Z')/=0
 !
 if(is_cut(1)) then
   idir(1) = 1
   idir(2) = 2
   idir(3) = 3
 elseif(is_cut(2)) then
   idir(1) = 2
   idir(2) = 1
   idir(3) = 3
 elseif(is_cut(3)) then
   idir(1) = 3
   idir(2) = 2
   idir(3) = 1
 endif
 !
 if (l_rim) then
   !
   call section('*','Coloumb potential Random Integration (RIM)')
   !
   call io_control(ACTION=OP_RD_CL,COM=REP,MODE=VERIFY,SEC=(/1,2/),ID=ID)
   io_err=io_RIM(ID)
   !
   if (io_err/=0) then
     if (cut_is_slab) then
       call msg('nr','Performing RIM of v_slab')
     endif
     call rim("x",Xw)
     call io_control(ACTION=OP_WR_CL,COM=REP,SEC=(/1,2/),ID=ID)
     io_err=io_RIM(ID)
   endif
   !
   call msg('nr','Summary of Coulomb integrals for non-metallic bands |Q|[au] RIM/Bare')
   call sort(arrin=q_norm,arrout=q_norm_s,indx=q_norm_i)
   do i1=1,nqibz,2
     !
     msg_dum=' '
     !
     do i2=i1,min(i1+1,nqibz)
       !
       iq=q_norm_i(i2)
       ch_dum='Q ['//trim(intc(iq))//']'
       if (i1/=i2) ch_dum=' * Q ['//trim(intc(iq))//']'
       !
       r_dum(1)=q_norm(iq)
       r_dum(2)=2./(abs(bare_qpg(iq,1))**2.*DL_vol*real(nqbz))
       if (i2==1) r_dum(2)=2.*7.7956/(2.*pi)**3.*d3q_factor**(1./3.)
       r_dum(2)=RIM_qpg(iq,1,1)/r_dum(2)
       !
       fmt_dum='(a,2('//trim(gen_fmt(r_v=r_dum))//'))'
       write (msg_dum(i2-i1+1),trim(fmt_dum)) trim(ch_dum),r_dum
       !
     enddo
     if (i1==1) call msg('nr',trim(STRING_pack(msg_dum(1),msg_dum(2))))
     if (i1/=1) call msg(' r',trim(STRING_pack(msg_dum(1),msg_dum(2))))
   enddo
 endif
 !
 ! CUTOFF
 !
 if (.not.l_col_cut) then
   !
   call cutoff_presets()
   if (allocated(bare_qpg) .and. size(bare_qpg)>0) bare_qpg(1,1)=q0_def_norm
   !
 else
   !
   call cutoff_driver(q)
   q_norm(1)=q0_def_norm
   !
 endif
 !
 ! copy again,
 ! bare_qpg is modified by cutff_driver
 !
#ifdef _GPU
 YAMBO_FREE_GPU(DEV_VAR(bare_qpg))
 if (size(bare_qpg)>0) then
   YAMBO_ALLOC_GPU_SOURCE(DEV_VAR(bare_qpg),bare_qpg)
 endif
#endif
 !
end subroutine
