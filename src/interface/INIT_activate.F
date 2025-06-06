!
! License-Identifier: GPL
!
! Copyright (C) 2006 The Yambo Team
!
! Authors (see AUTHORS file for details): AM DS
!
subroutine INIT_activate()
 !
 use BS_solvers,     ONLY:BSS_mode
 use QP_m,           ONLY:QP_solver,COHSEX_use_empties
 use stderr,         ONLY:intc,STRING_match
 use global_XC,      ONLY:WF_exx_fraction,WF_exx_screening
 use drivers,        ONLY:l_em1s,l_acfdt,l_HF_and_locXC,l_col_cut,l_alda_fxc,l_bs_fxc,l_optics,l_bse,l_bss,&
&                         l_chi,l_cohsex,l_life,l_rpa_IP,l_td_hf,l_setup,l_sc_run,l_rim,l_rim_w,&
&                         l_real_time,l_ppa,l_mpa,l_lrc_fxc,l_gw0,l_elel_corr,l_elel_scatt,l_elph_corr,l_td_sex,&
&                         l_elph_Hamiltonian,l_elph_scatt,l_elphoton_corr,l_elphoton_scatt,l_em1d,l_eval_collisions,&
&                         l_sc_magnetic,l_sc_electric,l_dipoles,l_pf_fxc,l_nl_optics,l_phel_corr,l_nl_p_and_p,l_X
#if defined _SC || defined _RT
 use hamiltonian,    ONLY:H_potential
#endif
#if defined _SC
 use magnetic,       ONLY:MAG_landau
#endif
#if defined _RT
 use fields,         ONLY:n_ext_fields
#endif
#if defined  _ELPH 
 use ELPH,           ONLY:elph_use_q_grid
#endif
#if defined _SCALAPACK
 use drivers,        ONLY:l_slk_test
#endif
 use drivers,        ONLY:l_gpu_test
 !
 implicit none
 !
#if defined _RT
 integer          :: i1
#endif
 character(2)     :: X_kind
 !
 !Common
 !
 call initactivate(1,'StdoHash Nelectro ElecTemp BoseTemp OccTresh NLogCPUs DBsIOoff DBsFRAGpm EvalMagn MEM_tresh DegFix')
 !
 !FFT
 !
 if (any((/l_optics.and.l_chi,l_optics.and.l_bse,l_em1d,l_X,&
&          l_em1s,l_acfdt,l_HF_and_locXC,l_col_cut/))) call initactivate(1,'FFTGvecs WFbuffIO')
 !
 ! CPU structure
 !
 if (l_dipoles.or.l_elphoton_corr) then
   call CPU_activate("DIP")
   call initactivate(1,'DIP_Threads')
 endif
 !
 ! CPU structure
 !
 if((l_optics.and..not.l_bse).or.l_em1s.or.l_em1d.or.l_ppa.or.l_mpa.or.l_life.or.l_X) then
     if (l_em1s.or.l_em1d.or.l_ppa.or.l_mpa.or.l_life.or.l_X) then
       call CPU_activate("X_and_IO")
     else
       call CPU_activate("X")
     endif
     call initactivate(1,'X_Threads')
   if (l_elel_corr.or.l_elphoton_corr) then
     call CPU_activate("DIP")
     call initactivate(1,'X_Threads DIP_Threads')
   endif
 endif
 !
 if(l_sc_run) then
   call CPU_activate("X_and_IO")  ! Required for finite E-field, l_sc_exx, SC_up_W_iter
 endif
 !
 if ( (l_HF_and_locXC.or.l_gw0.or.l_cohsex.or.l_life) .and. .not.(l_sc_run.or.l_eval_collisions.or.l_phel_corr) ) then
   call CPU_activate("SE")
   call initactivate(1,'SE_Threads')
 endif
 !
#if defined _SCALAPACK
 if (l_slk_test) then
   call initactivate(1,"SLKdim")
   call CPU_activate("SLK")
 endif
#endif
 !
 if (l_gpu_test) then
   call initactivate(1,"GPUdim")
   !call CPU_activate("SLK")
 endif
 !
#if defined _SC
 if (l_eval_collisions .or. l_sc_run) then
   call CPU_activate("SE")
   call initactivate(1,'SE_Threads')
 endif
#endif
 !
#if defined _RT 
 if (l_eval_collisions .or. l_real_time) then
   call CPU_activate("RT")
   call initactivate(1,'RT_Threads')
 endif
#endif
 !
#if defined _NL
 if (l_nl_optics) then
   call CPU_activate("NL")
   call CPU_activate("DIP")
   call CPU_activate("OSCLL")
   call initactivate(1,'DIP_Threads NL_Threads OSCLL_Threads')
 endif
#endif
 !
 if (l_bse) then
   call CPU_activate("BS")
   call CPU_activate("DIP")
   call initactivate(1,'X_Threads DIP_Threads K_Threads')
 endif
 !
#if defined  _ELPH 
 if ((l_life.or.l_gw0).and.l_phel_corr) then
   call CPU_activate("PH_SE")
 endif
#endif
 !
 !Setup
 !
 if (l_setup) call initactivate(1,'MaxGvecs Gthresh K_grids IkSigLim IkXLim NoDiagSC EvalMagn')
#if defined  _ELPH 
 if (l_setup) call initactivate(1,'BSEscatt')
#endif
 !
 !
 if (any((/(l_optics.and.l_chi),(l_optics.and.l_bse)/)))  call initactivate(1,'NonPDirs MolPos')
 !
 !RIM
 !
 if (l_rim) call initactivate(1,'RandQpts RandGvec QpgFull Em1Anys IDEm1Ref')
 !
 !RIM_W
 !
 if (l_rim_w) call initactivate(1,'RandQpts RandGvecW rimw_type')
 !
 !Col CUTOFF 
 !
 if (l_col_cut) call initactivate(1,'CUTGeo CUTBox CUTRadius CUTCylLen CUTwsGvec CUTCol_test')
 !
 !XX
 !
 if (l_HF_and_locXC) call initactivate(1,'EXXRLvcs VXCRLvcs UseNLCC')  
 !
 ! Kernels
 !
 if (l_em1s.or.l_em1d.or.l_X.or.l_mpa)      call initactivate(1,'Chimod ChiLinAlgMod')
 if (l_optics.and.l_chi)           call initactivate(1,'Chimod ChiLinAlgMod')
 if (l_optics.and.l_bse)           call initactivate(1,'BSKmod BSEmod Lkind')
 if (l_optics.and.l_bse.and.l_bss) call initactivate(1,'BSSmod')
 !
 if (l_dipoles) then
   call initactivate(1,'DipQpt DipBands DipBandsALL')
   call initactivate(1,'DipBandsALL DipApproach DipComputed DipPDirect ShiftedPaths DipoleEtresh')
#if defined _NL || defined _SC
   call initactivate(1,'EvPolarization')
#endif
 endif
 !
 if (l_optics.and.l_chi) then
   !
   ! BS based TDDFT (BS fxc is only of q=0 0 0). BS_fxc db exist
   if(l_bs_fxc) call initactivate(1,'FxcGRLc FxcSVdig FxcRetarded')
   !
   ! ALDA/LRC Tddft
   if (l_alda_fxc) call initactivate(1,'FxcGRLc FxcLibxc FxcMode UseNLCC')
   if (l_lrc_fxc)  call initactivate(1,'LRC_alpha LRC_beta')
   if (l_pf_fxc)   call initactivate(1,'PF_alpha')
   !
 endif
 !
 ! Optics(not bse) or GW (no PP)
 !
 if ((l_optics.and.l_chi).or.(l_em1d.and..not.(l_life.or.l_ppa.or.l_mpa.or.l_gw0)).or.l_X) then
   !
   X_kind         ="Xd"
   if (l_X) X_kind="Xx"
   !
   if (.not.l_rpa_IP) call X_activate(X_kind,(/'NGsBlk'/))
   !
   call X_activate(X_kind,(/'QpntsR','BndsRn',&
&                  'GrFnTp','EnRnge','DmRnge','DmERef','CGrdSp','ETStps','EMStps',&
&                  'DrudeW','EhEngy','LongDr'/))
   call initactivate(1,'DrClassic')
   if (.not.l_rpa_IP) call initactivate(1,'WriteXo')
   !
   call INIT_QP_ctl_switch('X')
   !
#if defined _RT
   call INIT_RT_ctl_switch('X')
#endif
   call initactivate(1,'Qdirection QShiftOrder')
   !
 endif
 !
 if (l_optics.or.(l_life.and.l_elel_corr)) then
   !
   ! Double Grid
   !
   call initactivate(1,'DbGdQsize')
   !
   ! Dipoles & Gauges
   !
   call initactivate(1,'DipApproach DipComputed DipPDirect ShiftedPaths Gauge')
   !
 endif
 !
 ! BSK
 !
 if (l_optics.and.l_bse) then
   !                     
   call initactivate(1,'BSENGexx ALLGexx')
   call initactivate(1,'Qdirection QShiftOrder')
   !
   if(l_td_hf.or.l_td_sex) call initactivate(1,'BSENGBlk')
   if(l_td_sex)            call initactivate(1,'WehDiag WehCpl')
   if(l_alda_fxc) then
     call initactivate(1,'BSENGfxc FxcLibxc FxcMode UseNLCC')
     if( (WF_exx_fraction>0.) .or. (WF_exx_screening>0.) ) call initactivate(1,'BSENGBlk WehDiag WehCpl')
   endif
   !
   ! BSE + TDDFT = no BS db, Fxc + LF on-fly
   ! Special case: The BSE equation is used to build up the BSE_Fxc kernel.
   if (l_bs_fxc) then
     call initactivate(1,'FxcGRLc FxcSVdig FxcRetarded FxcMEStps')
     call initactivate(1,'BLongDir QPropDir BEnRange BDmRange BEnSteps')
     !call initactivate(1,'EFieldDir QPropDir BEnRange BDmRange BEnSteps')
   endif
   !
 endif
 !
 ! BSE
 !
 if (l_optics.and.l_bse) then
   !
   call INIT_QP_ctl_switch('K')
   !
#if defined _RT
   call INIT_RT_ctl_switch('K')
   call INIT_RT_ctl_switch('R')
#endif
   !
   call initactivate(1,'NoCondSumRule MetDamp')
   !
#if defined _NL || defined _SC
   call initactivate(1,'EvPolarization FrSndOrd')
#endif
   !
   call initactivate(1,'PL_weights')
   !
   call initactivate(1,'DrudeWBS Reflectivity')
   call initactivate(1,'BoseCut ShiftedPaths')
   call initactivate(1,'BSEQptR BSEBands BSKCut BSKIOmode BSEEhEny BSehWind NoDiagSC')
   !
#if defined _RT
   call initactivate(1,'RTOccMode ForceEqTrans')
#endif
   !
 endif                    
 !
 ! BSE solver
 !
 if (l_optics.and.l_bse.and.l_bss.or.(l_bse.and.l_rpa_IP)) then
   !
   call initactivate(1,'BEnRange BDmRange BDmERef BEnSteps BLongDir QPropDir')
   !call initactivate(1,'BEnRange BDmRange BDmERef BEnSteps EFieldDir QPropDir')
   call initactivate(1,'BSEprop BSEdips')
   !
   ! Special case: the BSE_Fxc kernel has been constructed
   !               Thus I move to g-space to solve the Dyson equation
   !
   if (index(BSS_mode,'t')/=0 .and. l_bs_fxc) call initactivate(-1,'BSENGexx ALLGexx')
   if (index(BSS_mode,'t')/=0 .and. l_bs_fxc) call initactivate(-1,'BSENGBlk BSENGfxc')
   !
   if (index(BSS_mode,'i')/=0)  call initactivate(1,'BSSInvMode BSEPSInvTrs BSSInvPFratio BSSInvKdiag')
   if (index(BSS_mode,'d')/=0.or.index(BSS_mode,'s')/=0)  call initactivate(1,'WRbsWF BSSPertWidth')
   if (index(BSS_mode,'h')/=0)  call initactivate(1,'BSHayTrs BSHayTer BSHayItrIO BSHayItrMAX')
   if (index(BSS_mode,'s')/=0)  then
     call initactivate(1,'BSSNEig BSSEnTarget BSSSlepcApproach BSSSlepcPrecondition BSSSlepcExtraction')
     call initactivate(1,'BSSSlepcMaxIt BSSSlepcNCV BSSSlepcMPD BSSSlepcTol BSSSlepcMatrixFormat')
   endif
   !
   ! Special project dependent variables
   !
   if (index(BSS_mode,'i')/=0)  call initactivate(1,'BSPLInvTrs')
#if defined _ELPH 
   if (l_elph_corr.and..not.elph_use_q_grid) call initactivate(1,'ElPhRndNq')
#endif
 endif
 !
 ! Static screen 
 !
 if (l_em1s) then
   call INIT_QP_ctl_switch('X')
   !
#if defined _RT
   call INIT_RT_ctl_switch('X')
#endif
   !
   call initactivate(1,'ShiftedPaths')
   call X_activate('Xs',(/'QpntsR','BndsRn','NGsBlk','GrFnTp','DmRnge','CGrdSp','EhEngy','LongDr','DrudeW'/))
   call initactivate(1,'XTermKind')
   call initactivate(1,'XTermEn')
 endif
 !
 ! GW (PPA, MPA, & COHSEX) 
 !
 if ( (l_em1d.and.l_ppa) .or. (l_em1d.and.l_mpa) .or. (l_em1s.and.l_cohsex)) then
   call INIT_QP_ctl_switch('X')
   call initactivate(1,'RIM_W RIM_W_diag RIM_W_graph')
   !
#if defined _RT
   call INIT_RT_ctl_switch('X')
#endif
   !
   call initactivate(1,'ShiftedPaths')
   if (l_ppa) then
     call X_activate('Xp',(/'QpntsR','BndsRn','NGsBlk','CGrdSp',&
&                           'EhEngy','LongDr','PPAPnt'/))
   endif
   if (l_mpa) then
     call X_activate('Xm',(/'QpntsR','BndsRn','NGsBlk','CGrdSp',&
&                           'EhEngy','LongDr','EnSamp','EnGrid','EnRnge','ImRnge','DmRnge','ETStps','IntSol'/))
     call initactivate(1,'mpERdb')
   endif
   if (l_cohsex) then
     call X_activate('Xs',(/'QpntsR','BndsRn','NGsBlk','EhEngy','LongDr'/))
   endif
   call initactivate(1,'XTermKind')
   call initactivate(1,'XTermEn')
   call initactivate(1,'OptDipAverage')
 endif
 !
 ! ACFDT
 !
 if (l_acfdt) then
   call INIT_QP_ctl_switch('X')
   !
#if defined _RT
   call INIT_RT_ctl_switch('X')
#endif
   !
   call initactivate(1,'ShiftedPaths')
   call initactivate(1,'EXXRLvcs VXCRKvcs AC_n_LAM AC_n_FR AC_E_Rng')
   call X_activate('Xx',(/'QpntsR','BndsRn','NGsBlk','CGrdSp','EhEngy','LongDr'/))
 endif
 !
 ! GW/Life
 !
 if (l_gw0.or.l_life) then
   !
   if (l_gw0.and..not.trim(QP_solver)=="g".and.(l_elel_corr.or.l_elph_corr)) call initactivate(1,'QPsymmtrz')
   !
#if defined _QED
   if (l_elphoton_corr) then
     if (l_gw0) then
       call initactivate(1,'FFTGvecs RandQpts QEDRLvcs GbndRnge GDamping dScStep DysSolver') 
       if (trim(QP_solver)=="g") then
         call initactivate(1,'GEnSteps GEnRnge GEnMode GDmRnge GreenFTresh GreenF2QP') 
       else
         call initactivate(1,'SCEtresh')
         if (.not.l_cohsex) call initactivate(1,'NewtDchk ExtendOut OnMassShell QPExpand')
       endif
     else if (l_life) then
       call initactivate(1,'GbndRnge') 
     endif
   endif
#endif
   !
   if (l_elel_corr) then
     !
     call INIT_QP_ctl_switch('X')
     call INIT_QP_ctl_switch('G')
     !
#if defined _RT
     call INIT_RT_ctl_switch('X')
     call INIT_RT_ctl_switch('G')
#endif
     !
     call initactivate(1,'BoseCut ShiftedPaths')
     !
     if (l_gw0) then
       if (.not.l_cohsex.or.COHSEX_use_empties) call initactivate(1,'GbndRnge') 
       if (.not.l_cohsex.and.trim(QP_solver)/='g') call initactivate(1,'GDamping') 
       if (.not.l_cohsex) call initactivate(1,'dScStep') 
       if (.not.l_elphoton_corr) then
         if (.not.l_ppa.and..not.l_mpa.and..not.l_cohsex) &
&          call X_activate('Xd',(/'BndsRn','NGsBlk',&
&                          'DmRnge','DmERef','CGrdSp','ETStps','EMStps',&
&                          'DrudeW','EhEngy','LongDr'/)) 
         if (.not.l_cohsex) call initactivate(1,'GTermKind GTermEn DysSolver')
         if (     l_cohsex) call initactivate(1,'UseEbands')
         if (trim(QP_solver)=="g") then
           !DALV: switching off GsampType and GImRnge for now
           !call initactivate(1,'GsampType GEnSteps GEnRnge GImRnge GEnMode GDmRnge GreenFTresh GreenF2QP') 
           call initactivate(1,'GEnSteps GEnRnge GEnMode GDmRnge GreenFTresh GreenF2QP')
         else
           call initactivate(1,'SCEtresh')
           if (.not.l_cohsex) call initactivate(1,'NewtDchk ExtendOut OnMassShell QPExpand')
         endif
       endif
       !
     endif
     !
     if (l_life.and..not.l_phel_corr) then
       call initactivate(1,'LifeTrCG')
       if (l_elel_corr) call X_activate('Xd',(/'BndsRn','NGsBlk','DmRnge','CGrdSp','DrudeW','EhEngy','LongDr'/)) 
     endif
   endif
   !
#if defined  _PHEL 
   !
   if (l_phel_corr) then
     call initactivate(1,'ElecTemp BoseTemp PH_SE_mode GphBRnge GDamping PHELQpts ElPhModes PHDbGdsize DbGdQsize GDamping')
     call initactivate(1,'ExtendOut OnMassShell')
     if (      l_gw0) call initactivate(1,'DysSolver GEnSteps GEnRnge PHEL_QPH_En')
     if (.not. l_gw0) call initactivate(1,'GDamping PHELTrans') 
   endif
   !
#endif
#if defined  _ELPH 
   !
   if (l_elph_corr) then
     call INIT_QP_ctl_switch('G')
     call initactivate(1,'DysSolver')
     call initactivate(1,'GphBRnge FANdEtresh DWdEtresh ElPhModes GDamping dScStep ExtendOut ElPhRndNq RandQpts')
     call initactivate(1,'GkkpDB WRgFsq NewtDchk OnMassShell')
   endif
   if (trim(QP_solver)=="g".and.l_elph_corr) then
     call initactivate(1,'GEnSteps GEnRnge GEnMode GDmRnge GreenFTresh GreenF2QP') 
     call initactivate(-1,'WRgFsq NewtDchk GDamping ExtendOut OnMassShell')
   endif
   !
#endif
   !
 endif
 !
 if(l_alda_fxc.and.any((/l_em1s,l_em1d,l_acfdt,l_ppa,l_mpa,l_cohsex,l_gw0/)) ) call initactivate(1,'FxcGRLc')
 if( l_lrc_fxc.and.any((/l_em1s,l_em1d,l_acfdt,l_ppa,l_mpa,l_cohsex,l_gw0/)) ) call initactivate(1,'LRC_alpha LRC_beta')
 !
 ! El-Ph: Frohlich Hamiltonian
 !
#if defined _ELPH 
 !
 if (l_elph_Hamiltonian) then
   call initactivate(1,'ElPhHBRnge ElPhModes ElPhHKpt GDamping REStresh')
 endif
 !
#endif
 !
#if defined _SC || defined _RT
 !
 ! Collisions
 !
 if (l_eval_collisions) call initactivate( 0,'COLLBands')
 !
 if ( (l_eval_collisions.or.l_real_time).and.l_elel_scatt ) call initactivate(1,'PlasmaPerc')
 !
 if (l_eval_collisions.or.l_real_time.or.l_sc_run) then
   !
   if ( .not. STRING_match(trim(H_potential),"NONE") ) call initactivate(1,'HXC_Potential')
   !
   call initactivate( 1,'FFTGvecs')
   !
   call initactivate( 1,'COLLCut')
   !
   call initactivate(-1,'QpntsRXs')
   !
   if( index(H_potential,"IP")>0 )  call initactivate(1,'HARRLvcs ALLGHAR')
   if( index(H_potential,"HARTREE")>0 .or. index(H_potential,"DEFAULT")>0 )  call initactivate(1,'HARRLvcs ALLGHAR')
   if( index(H_potential,"GS_XC")>0   .or. index(H_potential,"DEFAULT")>0 ) call initactivate(1,'VXCRLvcs UseNLCC FxcLibxc')
   !
   if (l_eval_collisions) then
     if( STRING_match(trim(H_potential),"SEX").or.&
&        STRING_match(trim(H_potential),"FOCK") ) call initactivate(1,'EXXRLvcs ALLGexx')
     if( STRING_match(trim(H_potential),"SEX").or.&
&        STRING_match(trim(H_potential),"COH") ) call initactivate(1,'CORRLvcs ALLGexx')
   endif
   !
 endif
 !
#endif
 !
#if defined _SC 
 !
 ! Self-Consistency
 !
 if (l_sc_run) then
   !
   call initactivate( 1,'SCBands')
   !
   if( STRING_match(trim(H_potential),"SEX").or.&
&      STRING_match(trim(H_potential),"COH")  ) call initactivate(1,'UseEbands SCUpWIter')
   !
   if( STRING_match(trim(H_potential),"EXX").or.&
&      STRING_match(trim(H_potential),"SRPA") ) call initactivate(1,'OEPapprox OEPItSolver') 
   !
   call initactivate(1,'SCIter SCEtresh SCRhoTresh SC_precondition')
   call initactivate(1,'SCmixing SClwBand SCnlMix BandMix')
   call initactivate(1,'SCdiag Mean_Potential')
   !
   call initactivate(1,'SCneqKIND SCmu SCocc SCcohIt')
   !
 endif
 !
#endif
 !
#if defined _RT
 !
 ! AM March 2024: the following line has been added in order to perform
 ! e-p calculations on top of RT carriers distribution.
 !
 if (l_elph_corr) call INIT_RT_ctl_switch('G')
 !
 if (l_real_time) then
   !
   call INIT_QP_ctl_switch('G')
   !
   call INIT_RT_ctl_switch('G')
   !
   call initactivate(1,'RTskipImposeN RTeeImposeE InducedField')
   call initactivate(1,'Gauge VelGaugeCorr VelGaugeDiam PfromJ RTUpdateSOC RTUpdateE SaveGhistory')
   call initactivate(1,'RTEqScatt RTImpForMet RTzeroTempRef RTskipPHabs RTEvalEnergy RTEvalEntropy')
   call initactivate(1,'dTupdateTime dTupdateTimeSet dTupdateJump dTupdateTresh dT_MAX dT_SET')
   if (l_elel_scatt .or. l_elph_scatt .or. l_elphoton_scatt) then
     call initactivate(1,'LifeExtrapolation LifeExtrapSteps LifeFitTemp RelaxTimeApprox RTAtemp RTAchem LifeFitTemp')
   endif
   if (l_elph_scatt) call initactivate(1,'MemTresh RandQpts RT_T_evol ElPhModes UseDebyeE')
   if (l_elel_scatt) call initactivate( 1,'EERimPerc')
   !
   call initactivate(1,'RTBands Integrator GrKind TwoAlph RTehEny ScattTresh')
   call initactivate(1,'RADLifeTime RADmagnific PhLifeTime DephCVonly DephEThresh DephTRange')
   call initactivate(1,'RTstep NEsteps NETime DipoleEtresh SPINprojected')
   call initactivate(1,'IOtime IOCachetime')
   !
   ! n_ext_fields is by default 0.  It is set to the input number of fields when a command line option is provided (below in init.F)
   ! or parsed from the input file in INIT_load.F
   !
   do i1=1,n_ext_fields
     call Afield_activate(i1)
   enddo
   !
 endif
 !
#endif
 !
#if defined _NL
 if (l_nl_optics) then
   call initactivate(1,'FFTGvecs NLBands NLverbosity NLstep NLtime NLintegrator NLCorrelation NLLrcAlpha')
   call initactivate(1,'TestOSCLL')
   if(.not.l_nl_p_and_p) call initactivate(1,'NLEnRange NLEnSteps NLrotaxis NLAngSteps')
   call initactivate(1,'NLDamping RADLifeTime UseDipoles FrSndOrd NoComprCOLL EvalCurrent InducedField FrPolPerdic') 
   call initactivate(1,'TestOSCLL Gauge RADLifeTime HARRLvcs EXXRLvcs CORRLvcs') 
   call init_QP_ctl_switch('G')
 endif
 !
 do i1=1,n_ext_fields
   call Afield_activate(i1)
 enddo
 !
#endif
 !
#if defined _SC
 !
 ! Magnetic
 !
 if (l_sc_magnetic) then
   call initactivate(1,'Hamiltonian B_Field B_psi B_theta B_Gauge PhaseTrick')
   if (MAG_landau) call initactivate(1,'B_radius')
 endif
 !
 ! Electric
 !
 if (l_sc_electric) then
   call initactivate(1,'EvPolarization ExtF_Dir ExtF_Int FrSndOrd')
 endif
 !
#endif
 !
 contains
   !
#if defined _RT || defined _NL
   !
   subroutine Afield_activate(i1)
     integer     ::i1
     character(6)::field
     field='Field'//trim(intc(i1))
     call initactivate(1,field//'_Freq')
     call initactivate(1,field//'_NFreqs')
     call initactivate(1,field//'_DFreq')
     call initactivate(1,field//'_Int')
     call initactivate(1,field//'_Width')
     call initactivate(1,field//'_FWHM')
     call initactivate(1,field//'_kind')
     call initactivate(1,field//'_pol')
     call initactivate(1,field//'_Dir')
     call initactivate(1,field//'_Dir_circ')
     call initactivate(1,field//'_Tstart')
   end subroutine
   !
#endif
   !
   subroutine CPU_activate(what)
     character(*) :: what 
#if defined _MPI
     call initactivate(1,"PAR_def_mode")
     call initactivate(1,what//"_CPU")
     call initactivate(1,what//"_ROLEs")
     if (what=="X_and_IO".or.what=="X".or.what=="BS") call initactivate(1,what//"_nCPU_LinAlg_INV")
     if (what=="BS")                                  call initactivate(1,what//"_nCPU_LinAlg_DIAGO")
     if (what=="SE".and.l_sc_run)                     call initactivate(1,what//"_nCPU_LinAlg_DIAGO")
#endif
#if defined _SCALAPACK &&  defined _MPI
     if (what=="SLK")             call initactivate(1,what//"_nCPU_LinAlg_INV")
#endif
     !
   end subroutine
   !
   subroutine X_activate(mode,what)
     character(2)::mode
     character(6)::what(:)
     ! Work Space
     integer     ::i1
     do i1=1,size(what,1)
       call initactivate(1,what(i1)//mode)
     enddo
   end subroutine
   !
end subroutine
