!
! License-Identifier: GPL
!
! Copyright (C) 2020 The Yambo Team
!
! Authors (see AUTHORS file for details): CA
!
subroutine excitons_bands(k,Xk,en,Xen,q)
 !
 use pars,          ONLY:SP,schlen,rZERO
 use LIVE_t,        ONLY:live_timing
 use R_lattice,     ONLY:bz_samp
 use interpolate,   ONLY:INTERPOLATION_BZ
 use electrons,     ONLY:levels
 use functions,     ONLY:Fermi_fnc_derivative
 use units,         ONLY:HA2EV
 use YPPm,          ONLY:EXCITONS_user_indexes,EXCITONS_n_user_states,coo_out, &
&                        BANDS_steps,INTERP_grid,K_transform,CIRCUIT_k,DOS_E_step, &
&                        DOS_E_steps,DOS_broadening,USER_k
 use parser_m,      ONLY:parser
 use com,           ONLY:msg,of_open_close
 use stderr,        ONLY:intc
 use vec_operate,   ONLY:iku_v_norm
 use LIVE_t,        ONLY:live_timing
 use parallel_m,    ONLY:PP_indexes,myid,PP_indexes_reset
 use parallel_int,  ONLY:PP_redux_wait,PARALLEL_index

 !
#include<y_memory.h> 
 !
 type(bz_samp) ::Xk,k,q
 type(levels)  ::Xen,en
 !
 ! Work space
 !
 integer :: iq,i_c,i_l,ID_INTERP_EXC,i_E
 real(SP), allocatable    :: BSE_interp_E(:,:),values(:)
 type(bz_samp)            :: GRID_q
 character(schlen)        :: file_name
 character(schlen), allocatable :: headings(:)
 logical                  :: BANDS_built_in,GRID_interpolate,l_prt_dos
 real(SP)                 :: tmp_q(3)
 real(SP)                 :: dos_E(DOS_E_steps),exc_DOS(DOS_E_steps)
 real(SP)                 :: BS_all_E(EXCITONS_n_user_states,q%nibz)
 type(PP_indexes)         :: px
 !
 ! Parse the different interpolations
 !
 call parser('PrtDOS',l_prt_dos)
 call parser('BANDS_built_in',BANDS_built_in)
 GRID_interpolate    = all(INTERP_grid>0)
 !
 if(l_prt_dos.and..not.GRID_interpolate) call error("You need to specify a Q-grid for the DOS")
 !
 ! Allocate arrays for all eigenvalues/eigenvectors
 ! 
 YAMBO_ALLOC(values,(EXCITONS_n_user_states+4))
 allocate(headings(EXCITONS_n_user_states+4))
 !
 ! Read and interpolate excitons dispersion
 !
 ID_INTERP_EXC=1
 call excitons_interpolate_setup(k,Xk,en,Xen,q,BS_all_E,ID_INTERP_EXC,.TRUE.)
 !
 ! Interpolate and write on disk
 !
 call k_circuit_made_of_user_points( )
 !
 if(USER_k%nbz>0.and.BANDS_steps>0)  then
   !
   call msg('s','Exciton bands')
   !   
   YAMBO_ALLOC(BSE_interp_E,(EXCITONS_n_user_states,CIRCUIT_k%nibz))      
   call INTERPOLATION_BZ(K=CIRCUIT_k,NK=CIRCUIT_k%nbz,R1D=BSE_interp_E,ID=ID_INTERP_EXC)
   !
   call print_interpolated_BANDS()
   !
   if (BANDS_built_in) call print_built_in_BANDS()
   !
 endif
 !
 ! Interpolate exciton on a grid
 !
 if (GRID_interpolate) then
   !      
   call msg('s','Exciton Grid')
   !
   GRID_q%description="INTERP"
   call INTERPOLATION_grid(GRID_q,'i',INTERP_grid)
   !
   YAMBO_ALLOC(BSE_interp_E,(EXCITONS_n_user_states,GRID_q%nibz))
   !
   call INTERPOLATION_BZ(K=GRID_q,NK=GRID_q%nibz,R1D=BSE_interp_E,ID=ID_INTERP_EXC)
   !
   call print_INTERP_GRID()
   !
 endif
 !
 ! Interpolate exciton on a grid and calculate the DOS
 !
 if(l_prt_dos) then
   !      
   call msg('s','Exciton Density of States')
   !
   call electrons_dos_setup(BSE_interp_E, dos_E, (/1,EXCITONS_n_user_states/))
   !
   call PP_indexes_reset(px)
   call PARALLEL_index(px,(/DOS_E_steps/))
   !
   exc_DOS=rZERO
   !
   call live_timing("EXC DOS",px%n_of_elements(myid+1))
   !
   do i_E=1,DOS_E_steps
     if (.not.px%element_1D(i_E)) cycle
     do iq=1,GRID_q%nibz
       do i_c=1,EXCITONS_n_user_states
         exc_DOS(i_E)=exc_DOS(i_E)+Fermi_fnc_derivative((BSE_interp_E(i_c,iq)-dos_E(i_E)),DOS_broadening)*GRID_q%weights(iq)
       enddo
     enddo
     call live_timing(steps=1)
   enddo
   !
   call live_timing( )
   !
   call PP_redux_wait(exc_DOS)
   !
   call print_DOS()
   !
 endif
 !
 YAMBO_FREE(values)
 deallocate(headings)
 !
 contains 
   !
   subroutine print_DOS()
     implicit none
     ! 
     file_name="excitons_dos"
     call of_open_close(trim(file_name),'ot')
     headings(1)=" E [eV] "
     headings(2)=" Dos    "
     call msg('o '//trim(file_name),"#",headings(1:2),INDENT=0,USE_TABS=.true.)
     call msg('o '//trim(file_name),"#")
     do i_E=1,DOS_E_steps
       values(1)=dos_E(i_E)*HA2EV
       values(2)=exc_DOS(i_E)
       call msg('o '//trim(file_name),' ',values(1:2),INDENT=0,USE_TABS=.true.)
     enddo
     !
     call of_open_close(trim(file_name))
     !
   end subroutine print_DOS
   ! 
   subroutine print_interpolated_BANDS()
     implicit none
     !
     headings(1)=" |q| (a.u.) "
     do i_c=1,EXCITONS_n_user_states
        i_l=EXCITONS_user_indexes(i_c)
        headings(i_c+1)=' e'//intc(i_l)
     enddo
     headings(EXCITONS_n_user_states+2:EXCITONS_n_user_states+4)=&
&           (/"q_x ("//trim(coo_out)//")","q_y ("//trim(coo_out)//")","q_z ("//trim(coo_out)//")"/)
     !
     file_name="excitons_interpolated"
     call of_open_close(trim(file_name),'ot')
     call msg('o '//trim(file_name),"#",headings,INDENT=0,USE_TABS=.true.)
     call msg('o '//trim(file_name),"#")
     !
     values=0._SP
     !
     do iq=1,CIRCUIT_k%nibz
       !
       if (iq>1) values(1)=values(1)+iku_v_norm(CIRCUIT_k%pt(iq,:3)-CIRCUIT_k%pt(iq-1,:3))
       !
       tmp_q=CIRCUIT_k%pt(iq,:3)
       !
       call K_transform(tmp_q,'iku')
       values(1+1:EXCITONS_n_user_states+1)=BSE_interp_E(:,iq)*HA2EV
       values(EXCITONS_n_user_states+2:EXCITONS_n_user_states+4)=tmp_q
       call msg('o '//trim(file_name),' ',values,INDENT=0,USE_TABS=.true.)
     enddo
     call of_open_close(trim(file_name))
     !
   end subroutine print_interpolated_BANDS
   ! 
   subroutine print_built_in_BANDS()
     implicit none
     !
     integer               :: i_point,n_points,n_points_max,iq_bz_grid,iq_ibz_grid
     real(SP)              :: value_k,values(EXCITONS_n_user_states+4)
     integer,  allocatable :: Grid_to_path_map(:,:)
     real(SP), allocatable :: tmp_var(:,:),tmp_q(:,:),tmp_k_dist(:,:)
     !
     call k_ibz2bz(q,'iku',.true.)
     !
     YAMBO_ALLOC(Grid_to_path_map,(USER_k%nbz,q%nbz))
     call define_grid_map(q,USER_k,Grid_to_path_map,n_points_max)
     YAMBO_ALLOC(tmp_var,(EXCITONS_n_user_states,n_points_max))
     !
     YAMBO_ALLOC(     tmp_q,(3,n_points_max))
     YAMBO_ALLOC(tmp_k_dist,(3,n_points_max))
     !
     headings(1)=" |q| (a.u.) "
     do i_c=1,EXCITONS_n_user_states
        i_l=EXCITONS_user_indexes(i_c)
        headings(i_c+1)=' e'//intc(i_l)
     enddo
     headings(EXCITONS_n_user_states+2:EXCITONS_n_user_states+4)=&
&           (/"q_x ("//trim(coo_out)//")","q_y ("//trim(coo_out)//")","q_z ("//trim(coo_out)//")"/)
     !
     file_name="excitons_built_in"
     call of_open_close(trim(file_name),'ot')
     call msg('o '//trim(file_name),"#",headings,INDENT=0,USE_TABS=.true.)
     call msg('o '//trim(file_name),"#")
     !
     values=0._SP
     !
     do iq=1,USER_k%nibz
       !
       if (iq>1) value_k=value_k+iku_v_norm(USER_k%pt(iq,:3)-USER_k%pt(iq-1,:3))
       !
       n_points=0
       !
       do iq_bz_grid=1,q%nbz
         if( Grid_to_path_map(iq,iq_bz_grid)==-1 ) cycle
         n_points=n_points+1
         iq_ibz_grid=q%sstar(iq_bz_grid,1)
         !
         tmp_k_dist(:,n_points)=q%ptbz(iq_bz_grid,:)-USER_k%pt(iq,:)
         tmp_q(:,n_points)=q%ptbz(iq_bz_grid,:)
         !
         tmp_var(:,n_points)=BS_all_E(:,iq_ibz_grid)
         !
       enddo
       !
       do i_point=1,n_points
         !
         call K_transform(tmp_q(:,i_point),'iku')
         !
         values(1)=value_k+iku_v_norm(tmp_k_dist(:,i_point))
         values(2:EXCITONS_n_user_states+1)=tmp_var(:,i_point)*HA2EV
         values(EXCITONS_n_user_states+2:EXCITONS_n_user_states+4)=tmp_q(:,i_point)
         !
         call msg('o '//trim(file_name),' ',values,INDENT=0,USE_TABS=.true.)
       enddo
       !
     enddo
     !
     call of_open_close(trim(file_name))
     !
   end subroutine print_built_in_BANDS
   !
   subroutine print_INTERP_GRID()
     implicit none
     !
     headings(1)=" |q| (a.u.) "
     do i_c=1,EXCITONS_n_user_states
        i_l=EXCITONS_user_indexes(i_c)
        headings(i_c+1)=' e'//intc(i_l)
     enddo
     headings(EXCITONS_n_user_states+2:EXCITONS_n_user_states+4)=&
&           (/"q_x ("//trim(coo_out)//")","q_y ("//trim(coo_out)//")","q_z ("//trim(coo_out)//")"/)
     !
     file_name="excitons_interpolated_IBZ"
     call of_open_close(trim(file_name),'ot')
     call msg('o '//trim(file_name),"#",headings,INDENT=0,USE_TABS=.true.)
     call msg('o '//trim(file_name),"#")
     !
     do iq=1,GRID_q%nibz
       !
       if (iq>1) values(1)=iku_v_norm(GRID_q%pt(iq,:3))
       !
       tmp_q = GRID_q%pt(iq,:3)
       !
       call K_transform(tmp_q,'iku')
       values(1+1:EXCITONS_n_user_states+1)=BSE_interp_E(:,iq)*HA2EV
       values(EXCITONS_n_user_states+2:EXCITONS_n_user_states+4)=tmp_q
       call msg('o '//trim(file_name),' ',values,INDENT=0,USE_TABS=.true.)
     enddo
     call of_open_close(trim(file_name))
     !
   end subroutine print_INTERP_GRID
 !
end subroutine
