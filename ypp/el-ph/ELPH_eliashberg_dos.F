!
! License-Identifier: GPL
!
! Copyright (C) 2020 The Yambo Team
!
! Authors (see AUTHORS file for details): AM
!
subroutine ELPH_eliashberg_dos(k,en,q)
 !
 use pars,                ONLY:SP,schlen,pi
 use units,               ONLY:HA2EV,HA2GHZ,HA2THZ 
 use com,                 ONLY:msg,of_open_close
 use electrons,           ONLY:levels,n_met_bands,n_full_bands
 use R_lattice,           ONLY:bz_samp
 use YPPm,                ONLY:l_dos
 use YPP_ELPH,            ONLY:elph_steps,elph_Ef,elph_gamma_broad,&
&                              ph_broad,l_eliashberg
 use ELPH,                ONLY:ph_modes,elph_nb,GKKP,PH_freqs_sq,PH_freqs,&
&                              PH_W_debye,elph_nQ,elph_use_q_grid,&
&                              GKKP,setup_k_plus_q_levels,use_PH_DbGd
 use IO_int,              ONLY:io_control
 use IO_m,                ONLY:manage_action,OP_RD,RD_CL_IF_END,DUMP,RD_CL,REP
 use ALLOC,               ONLY:ELPH_alloc
 use LIVE_t,              ONLY:live_timing
 use parallel_m,          ONLY:PP_indexes,myid
 use parallel_int,        ONLY:PP_redux_wait,PARALLEL_index 
 use functions,           ONLY:Fermi_fnc_derivative
 !
#include<y_memory.h>
 type(levels) ::en
 type(bz_samp)::k,q
 !
 ! Work Space 
 !
 integer           ::i1,i2,im,iq,nq_todo
 real(SP)          ::dos_ef,Ef_diff,E,q_weight,aF(elph_steps),&
&                    ph_dos(elph_steps),ph_energy(elph_steps),omega,e_step
 complex(SP)       ::d_elias_dos
 character(schlen) ::o_file_name,ch
 type(PP_indexes)  ::px
 real(SP), allocatable :: gamma(:,:)
 !
 !I/O
 !
 integer           :: io_err,ID,ID_DG,IO_ACT
 integer, external :: io_ELPH
 integer, external :: io_Double_Grid
 real(SP), external :: Eliashberg_Dos_Func
 !
 if (l_eliashberg) l_eliashberg=elph_gamma_broad>1.E-8.and.any(n_met_bands/=n_full_bands)
 if (l_dos)        l_dos       =ph_broad>1.E-8
 !
 if (l_eliashberg.and.l_dos) then
   call section("*","== Electron-Phonon Interface: phonon DOS & Eliashberg Function ==")
 else if (l_eliashberg) then
   call section("*","== Electron-Phonon Interface: Eliashberg Function ==")
 else if (l_dos) then
   call section("*","== Electron-Phonon Interface: phonon DOS ==")
 else
   return
 endif
 !-----------------------------------------------------------------------
 !
 Ef_diff=0.
 if (elph_Ef/=0.) Ef_diff=en%E_Fermi-elph_Ef
 !
 ! DOS @ Ef
 !
 dos_ef=0.
 do i1=1,k%nibz
   do i2=1,en%nb
     !
     E=en%E(i2,i1,1)+Ef_diff
     !             SPIN
     !             |
     dos_ef=dos_ef+2.*k%weights(i1)*Fermi_fnc_derivative(E,elph_gamma_broad)
     !
   enddo
 enddo
 !
 call io_control(ACTION=OP_RD,SEC=(/1/),MODE=DUMP,ID=ID)
 if (l_dos)        io_err=io_ELPH(ID,'no_matrix_elements')
 if (l_eliashberg) io_err=io_ELPH(ID,'gkkp')
 !
 call msg('s',' Checking database ...')
 if (io_err<0) then
   call msg('s','not found')
   return
 endif
 call msg('s','sane')
 !
 ! Energy range
 !
 e_step=PH_W_debye*1.10/(elph_steps-1)
 do i2=1,elph_steps
   ph_energy(i2)=(i2-1)*e_step
 enddo
 !
 if (elph_use_q_grid) then
   nq_todo=q%nibz
 else
   nq_todo=elph_nQ
 endif
 !
 ! Eliashberg Function & DOS function
 !====================================
 !
 aF=0.
 ph_dos=0.
 !
 if (l_eliashberg) then
   YAMBO_ALLOC(gamma,(nq_todo,ph_modes))
   gamma=0.
 endif
 !
 ! Fill the PH_freqs array
 !
 PH_freqs%nk=nq_todo
 PH_freqs%nb=ph_modes
 YAMBO_ALLOC(PH_freqs%E,(nq_todo,ph_modes,1))
 !
 ! Load double-grid if present
 !
 call io_control(ACTION=OP_RD,COM=REP,MODE=DUMP,SEC=(/1,2/),ID=ID_DG)
 io_err=io_Double_Grid(PH_freqs,q,ID_DG,'phonons')
 !
 if(io_err==0) then
   if(elph_use_q_grid.and..not.l_eliashberg) then
     call msg('sr','Phonon DOS calculated using PH-double-grid ')
     use_PH_DbGd=.TRUE.
     call k_build_up_BZ_tables(q)
   else
     call msg('sr','PH-double-grid not compatible with Random q-grids and Eliashberg functions!')
   endif
 endif
 !
 call PARALLEL_index(px,(/nq_todo/))
 if (l_eliashberg.and..not.l_dos) call live_timing('Eliashberg',px%n_of_elements(myid+1))
 if (.not.l_eliashberg.and.l_dos) call live_timing('ph-DOS',px%n_of_elements(myid+1))
 if (l_dos.and.l_eliashberg)      call live_timing('Eliashberg & DOS',px%n_of_elements(myid+1))
 !
 ! calculate q%weights
 !
 call k_expand(q) 
 !
 do iq=1,nq_todo 
   !
   ! I/O
   !
   IO_ACT=manage_action(RD_CL_IF_END,iq,1,nq_todo)
   call io_control(ACTION=IO_ACT,SEC=(/iq+1/),ID=ID)
   if (l_dos)        io_err=io_ELPH(ID,'no_matrix_elements')
   if (l_eliashberg) io_err=io_ELPH(ID,'gkkp')
   !
   PH_freqs%E(iq,:,1)= sqrt( MAX( PH_freqs_sq(iq,:),0. ) )
   !
   if (.not.elph_use_q_grid.and.l_eliashberg) call setup_k_plus_q_levels(iq,en%E_Fermi)
   !
   ! Q weight
   !
   q_weight=1./real(elph_nQ)
   if (elph_use_q_grid) q_weight=q%weights(iq)
   !
   if (.not.px%element_1D(iq)) cycle
   !
   if (io_err/=0) then
     call live_timing(steps=1)
     cycle
   endif
   !
   if (l_eliashberg) then
     !
     ! Gamma Factors
     !
     call elph_gamma(iq)
     !
   endif
   !
   do im=1,ph_modes
     !
     omega = sqrt( MAX( PH_freqs_sq(iq,im),0. ) )
     !
     if (omega<1.E-10) cycle
     !
     do i2=1,elph_steps
       !
       d_elias_dos=q_weight*Eliashberg_Dos_Func(iq, im, ph_energy(i2) ,ph_broad, PH_freqs, q)
       !
       if (l_eliashberg) aF(i2)=aF(i2)+gamma(iq,im)*d_elias_dos/omega/dos_ef
       if (l_dos)     ph_dos(i2)=ph_dos(i2)+real(d_elias_dos,SP)
       !
     enddo
   enddo
   !
   call live_timing(steps=1)
   !
 enddo
 !
 call live_timing()
 if (l_eliashberg) then
   call PP_redux_wait(gamma)
   call PP_redux_wait(aF)
 endif
 if (l_dos) call PP_redux_wait(ph_dos)
 !
 ! Output file
 !
 if (l_eliashberg) then
   o_file_name='eliashberg'
   call of_open_close(o_file_name,'ot')
   call msg('o eli','#',' Eliashberg Function & Gamma factors',INDENT=0)
   call msg('o eli','#','',INDENT=0)
   call msg('o eli',         '#  Bands              ',elph_nb,INDENT=0)
   call msg('o eli','#','',INDENT=0)
   do iq=1,nq_todo
     write (ch,'(a,i6.6,a)') '# Gamma (',iq,') [GHz]'
     call msg('o eli',trim(ch),(/gamma(iq,:)*HA2GHZ/) ,INDENT=0)
   enddo
   call msg('o eli','#','',INDENT=0)
   call msg('o eli','#',(/'E(THz)','a_F(w)'/),USE_TABS=.true.)
   call msg('o eli','#','',INDENT=0)
   do i1=1,elph_steps
     aF(i1)=aF(i1)/pi
     call msg('o eli','',(/ph_energy(i1)*HA2THZ,aF(i1)/),USE_TABS=.true.)
   enddo
   call of_open_close(o_file_name)
 endif
 if (l_dos) then
   o_file_name='ph_dos'
   call of_open_close(o_file_name,'ot')
   call msg('o dos','#',' Phonon DOS function',INDENT=0)
   call msg('o dos','#','',INDENT=0)
   call msg('o dos','#',(/'E(meV)','DOS(w)'/),USE_TABS=.true.)
   call msg('o dos','#','',INDENT=0)
   do i1=1,elph_steps
     ph_dos(i1)=ph_dos(i1)/pi
     call msg('o dos','',(/ph_energy(i1)*HA2EV*1000.,ph_dos(i1)/),USE_TABS=.true.)
   enddo
   call of_open_close(o_file_name)
 endif
 !
 !CLEAN
 !
 YAMBO_FREE(gamma)
 call ELPH_alloc('FREE',GKKP=GKKP)
 !
 contains
   !
   subroutine elph_gamma(iq)
   !------------------------
   !
   ! Taken from elphon.f90 (PWscf)
   !
   ! gamma = \pi \sum_k\sum_{i,j} \delta(e_{k,i}-Ef) \delta(e_{k+q,j}-Ef)
   !         | \sum_mu z(mu,nu) <psi_{k+q,j}|dvscf_q(mu)*psi_{k,i}> |^2
   !
   ! where z(mu,nu) is the mu component of normal mode nu (z = dyn)
   !
   ! gamma(nu) is the phonon linewidth of mode nu
   !
   ! The factor N(Ef)^2 that appears in most formulations of el-ph interact
   ! is absent because we sum, not average, over the Fermi surface.
   !
   ! lambda is the adimensional el-ph coupling for mode nu:
   ! lambda(nu)= gamma(nu)/(pi N(Ef) \omega_{q,nu}^2)
   !
   ! WARNING ! SPIN NOT INCLUDED HERE !
   !
   use R_lattice,     ONLY:qindx_X
   use vec_operate,   ONLY:degeneration_finder
   implicit none
   integer :: iq
   !
   !Work Space 
   !
   integer  ::iibz1,iibz2,im,ib1,ib2,first_el(ph_modes),n_of_el(ph_modes),&
&             n_deg_grp
   real(SP) ::weight,sym_gamma,Ek,Ekmq
   !
   do i1=1,k%nbz
     !
     iibz1=k%sstar(i1,1)
     if (elph_use_q_grid) iibz2=k%sstar(qindx_X(iq,i1,1),1)
     !
     do ib1=1,elph_nb
       do ib2=1,elph_nb
         !        
         Ek  =en%E(ib1,iibz1,1)+Ef_diff
         !
         if (elph_use_q_grid) Ekmq=en%E(ib2,iibz2,1)+Ef_diff
         if (.not.elph_use_q_grid) Ekmq=GKKP%E_kpq(iq)%E(ib2,i1,1)+Ef_diff
         !
         weight=Fermi_fnc_derivative(Ek,  elph_gamma_broad)*&
&               Fermi_fnc_derivative(Ekmq,elph_gamma_broad)
         !      
         weight=weight*2._SP/real(k%nbz)
         !             |
         !             SPIN
         ! The factor 2 is provided by the sum over spins
         !
         ! Note that in YAMBO 
         !
         ! gamma \propto \sum_k\sum_{ib1,ib2} \delta(e_{k,ib1}-Ef) \delta(e_{k-q,ib2}-Ef)
         !         | <psi_{k-q,ib2}|dvscf_q(mu)*psi_{k,ib1}> |^2
         !
         do im=1,ph_modes
           gamma(iq,im)=gamma(iq,im)+&
&                       conjg(GKKP%dVc(im,ib2,ib1,i1,1))*GKKP%dVc(im,ib2,ib1,i1,1)*weight
         enddo
       enddo
     enddo
   enddo
   !
   ! Gamma factors symmetrization
   !
   call degeneration_finder(abs(PH_freqs_sq(iq,:)),ph_modes,first_el,n_of_el,&
&                           n_deg_grp,1.E-10_SP)
   do i1=1,n_deg_grp
     !
     sym_gamma=0._SP
     do i2=first_el(i1),first_el(i1)+n_of_el(i1)-1
       sym_gamma=sym_gamma+gamma(iq,i2)/real( n_of_el(i1) )
     enddo
     do i2=first_el(i1),first_el(i1)+n_of_el(i1)-1
       gamma(iq,i2)=sym_gamma
     enddo
     !
   enddo
   !
   ! the factor 2 comes from the factor sqrt(hbar/2/M/omega) that appears
   ! in the definition of the electron-phonon matrix element g
   ! The sqrt(1/M) factor is actually hidden into the normal modes
   !
   gamma(iq,:)=gamma(iq,:)*pi/2.
   !
   end subroutine
   !
end subroutine
