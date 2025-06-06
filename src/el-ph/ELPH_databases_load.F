!
! License-Identifier: GPL
!
! Copyright (C) 2006 The Yambo Team
!
! Authors (see AUTHORS file for details): AM FP
!
subroutine ELPH_databases_load(GKKP_sq,E,k,q,n_bands,q_range,K_mode,SCATT_mode)
 ! 
 ! mode can be combination of
 !
 !  BZ/IBZ + bare/dressed + square 
 ! 
 use pars,           ONLY:SP,rZERO,schlen
 use electrons,      ONLY:levels
 use R_lattice,      ONLY:bz_samp
 use IO_int,         ONLY:io_control
 use IO_m,           ONLY:OP_RD_CL
 use ELPH,           ONLY:PH_freqs_sq,GKKP,ph_modes,MAX_gkkp,Q_io_map,GKKP_me,K_io_map,&
&                         l_GKKP_DB_exists,l_GKKP_expanded_DB_exists,elph_nQ,GKKP_bare
 use ALLOC,          ONLY:ELPH_alloc
 use parallel_int,   ONLY:PP_redux_wait
 use LIVE_t,         ONLY:live_timing
 use parallel_m,     ONLY:PAR_Q_bz_index,PAR_IND_Q_bz,PAR_nQ_bz,PAR_Xk_nibz,PAR_Xk_ibz_index,PAR_IND_Xk_ibz,&
&                         PAR_COM_Q_INDEX,PAR_COM_Xk_ibz_INDEX,PARs_PH_Q_ibz,PARs_PH_Q_ibz
 !
#include<y_memory.h>
 ! 
 integer,      intent(in)    :: n_bands(2),q_range(2)
 type(levels), intent(in)    :: E
 type(bz_samp),intent(in)    :: k,q
 character(*), intent(in)    :: K_mode,SCATT_mode
 type(GKKP_me),intent(inout) :: GKKP_sq
 !
 ! Work Space
 !
 integer             ::iq,ID,io_err,ik,i_n,i_np,ik_bz,ik_mem,iq_mem,NK,NQ,iq_s,idb,iq_ibz
 real(SP)            ::ph_Esq_local(elph_nQ,ph_modes)
 real(SP),allocatable::MAX_gkkp_expanded_at_kpq(:,:),GKKP_to_sym(:,:,:)
 integer, external   ::io_ELPH
 character(1)        ::sym_mode
 character(schlen)   ::db_name
 logical             ::l_K_BZ,l_K_IBZ,l_Q_BZ,l_Q_IBZ,l_bare,l_dressed,l_mixed,l_cycle
 !
 ! What?
 !=======
 if (index(K_mode,"K-sym")>0) sym_mode="K"
 if (index(K_mode,"Q-sym")>0) sym_mode="Q"
 l_K_IBZ   = index(K_mode,"K-IBZ")>0
 l_K_BZ    = .not.l_K_IBZ
 l_Q_IBZ   = index(K_mode,"Q-IBZ")>0
 l_Q_BZ    = .not.l_Q_IBZ
 l_bare    = index(SCATT_mode,"bare-bare")>0
 l_dressed = index(SCATT_mode,"dressed-dressed")>0
 l_mixed   = index(SCATT_mode,"dressed-bare")>0.or.index(SCATT_mode,"bare-dressed")>0
 !
 ! DB name
 !=========
 if (l_Q_IBZ) then
   if (l_GKKP_DB_exists         ) db_name="gkkp"
   if (l_GKKP_expanded_DB_exists) db_name="gkkp_expanded"
 endif
 if (l_Q_BZ) db_name="gkkp_expanded"
 !
 ! Allocation
 !============
 YAMBO_ALLOC(MAX_gkkp_expanded_at_kpq,(k%nbz,q_range(1):q_range(2)))
 YAMBO_ALLOC(GKKP_to_sym,(ph_modes,n_bands(2),n_bands(2)))
 if (l_Q_IBZ) NQ=PARs_PH_Q_ibz%N_par
 if (l_Q_BZ ) NQ=PAR_nQ_bz
 if (l_K_IBZ) NK=PAR_Xk_nibz
 if (l_K_BZ ) NK=k%nbz
 call ELPH_alloc("dV_sq",GKKP=GKKP_sq,Nk_mem=NK,Nq_mem=NQ,NB=n_bands)
 MAX_gkkp_expanded_at_kpq=rZERO
 ph_Esq_local=rZERO
 !
 call live_timing('El-Ph matrix-elements I/O ('//trim(SCATT_mode)//' and '//trim(K_mode)//')',NQ)
 !
 do iq=q_range(1),q_range(2)
   !
   !...map
   idb=Q_io_map(iq)
   !
   iq_ibz=iq
   iq_s  =1
   if (l_GKKP_expanded_DB_exists) then
     iq_ibz=q%sstar(iq,1)
     iq_s  =q%sstar(iq,2)
   endif
   !
   !... cycle?
   if (l_Q_BZ ) l_cycle=.not.PAR_IND_Q_bz%element_1D(iq)
   if (l_Q_IBZ) l_cycle=iq_s/=1.or..not.PARs_PH_Q_ibz%IND%element_1D(iq)
   if (l_cycle) cycle
   !
   !...IO
   call io_control(ACTION=OP_RD_CL,SEC=(/idb+1/),ID=ID)
   io_err=io_ELPH(ID,trim(db_name))
   !
   ph_Esq_local(iq,:)=PH_freqs_sq(idb,:)
   !
   do ik_bz=1,k%nbz
     !
     ik=k%sstar(ik_bz,1)
     !
     l_cycle=.FALSE.
     !DEBUG-AM
     !if (l_K_BZ)  l_cycle=.not.PAR_IND_Xk_bz%element_1D(ik) ! TO CODE
     !DEBUG-AM
     if (l_K_IBZ) l_cycle=k%sstar(ik_bz,2)/=1.or..not.PAR_IND_Xk_ibz%element_1D(ik)
     if (l_cycle) cycle
     !
     if (l_Q_IBZ) iq_mem = PARs_PH_Q_ibz%table(iq)
     if (l_Q_BZ ) iq_mem = PAR_Q_bz_index(iq)
     if (l_K_IBZ) ik_mem = PAR_Xk_ibz_index(ik)
     !DEBUG-AM
     if (l_K_BZ)  ik_mem = ik_bz ! PAR_Xk_ibz_index(ik_bz)! TO CODE
     !DEBUG-AM
     !
     do i_n=1,n_bands(2)
       do i_np=1,n_bands(2)
         !
         ! There has been a key error in the definition of the el-ph SE of the BKE (Eq. 30_9_11.18)
         ! where the band indexes have been exchanged. Instead of doing a global change of the notes
         ! and of the code I decided, here, to exchange the indexes:
         !
         !  <i_n ik|g(q_YAMBO l r)|i_np ik-q_YAMBO> = [<i_np ik+q_PW|g(q_PW l r)|i_n ik>]^* = 
         !                                             elph_gkkp(il,i_np_gkkp,i_n_gkkp,ik_bz_gkkp)^*
         !
         if (l_dressed) then
           GKKP_to_sym(:,i_n,i_np)=abs(GKKP%dVc(:,i_np,i_n,K_io_map(ik_bz),1))**2
         elseif (l_bare) then
           GKKP_to_sym(:,i_n,i_np)=abs(GKKP_bare%dVc(:,i_np,i_n,K_io_map(ik_bz),1))**2
         elseif (l_mixed) then
           GKKP_to_sym(:,i_n,i_np)= &
&          get_mixed_couplings(GKKP%dVc(:,i_np,i_n,K_io_map(ik_bz),1), GKKP_bare%dVc(:,i_np,i_n,K_io_map(ik_bz),1))
         endif
         !
       enddo
     enddo
     !
     call ELPH_databases_symmetrize(sym_mode,E,k,q,ik_bz,iq,n_bands,GKKP_to_sym)
     !
     GKKP_sq%dVr(:,:,:,ik_mem,iq_mem)=GKKP_to_sym(:,n_bands(1):n_bands(2),n_bands(1):n_bands(2))
     !
     MAX_gkkp_expanded_at_kpq(ik_bz,iq)=maxval(sqrt(GKKP_sq%dVr(:,:,:,ik_mem,iq_mem)))
     !
   enddo
   !
   call live_timing(steps=1)
   !
 enddo
 !
 PH_freqs_sq=ph_Esq_local
 !
 if (l_Q_BZ ) then
   call PP_redux_wait(PH_freqs_sq,COMM=PAR_COM_Q_INDEX%COMM)
   call PP_redux_wait(MAX_gkkp_expanded_at_kpq,COMM=PAR_COM_Q_INDEX%COMM)
   call PP_redux_wait(MAX_gkkp_expanded_at_kpq,COMM=PAR_COM_Xk_ibz_INDEX%COMM)
 else
   call PP_redux_wait(PH_freqs_sq,COMM=PARs_PH_Q_ibz%COMM_i%COMM)
   call PP_redux_wait(MAX_gkkp_expanded_at_kpq,COMM=PARs_PH_Q_ibz%COMM_i%COMM)
 endif
 !
 if (any(PH_freqs_sq<0._SP)) call warning('Imaginary phonon frequencies found. Please check.')
 !
 MAX_gkkp=maxval(MAX_gkkp_expanded_at_kpq)
 !
 call ELPH_alloc("FREE",GKKP=GKKP)
 call ELPH_alloc("FREE",GKKP=GKKP_bare)
 !
 contains
   !
   ! Here we construct the asymmetric bare-dressed coupling expression (notes by FP 23_10_20)
   function get_mixed_couplings(GKKP_dVc,GKKP_bare_dVc) result(GKKP_sq_eff)
     complex(SP), intent(in) :: GKKP_dVc(ph_modes)
     complex(SP), intent(in) :: GKKP_bare_dVc(ph_modes)
     real(SP)                :: GKKP_sq_eff(ph_modes)
     GKKP_sq_eff = real(GKKP_dVc)*real(GKKP_bare_dVc)+aimag(GKKP_dVc)*aimag(GKKP_bare_dVc)
   end function
   !
end subroutine ELPH_databases_load
