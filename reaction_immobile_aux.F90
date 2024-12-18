module Reaction_Immobile_Aux_module

#include "petsc/finclude/petscsys.h"
  use petscsys

  use Reaction_Database_Aux_module

  use PFLOTRAN_Constants_module

  implicit none

  private

  type, public :: immobile_species_type
    PetscInt :: id
    character(len=MAXWORDLENGTH) :: name
    PetscReal :: molar_weight
    PetscBool :: print_me
    type(immobile_species_type), pointer :: next
  end type immobile_species_type

  type, public :: immobile_constraint_type
    ! Any changes here must be incorporated within ReactionProcessConstraint()
    ! where constraints are reordered
    character(len=MAXWORDLENGTH), pointer :: names(:)
    PetscReal, pointer :: constraint_conc(:)
    character(len=MAXWORDLENGTH), pointer :: constraint_aux_string(:)
    PetscBool, pointer :: external_dataset(:)
  end type immobile_constraint_type

  type, public :: immobile_decay_rxn_type
    PetscInt :: id
    character(len=MAXWORDLENGTH) :: species_name
    PetscReal :: rate_constant
    PetscReal :: half_life
    PetscBool :: print_me
    type(immobile_decay_rxn_type), pointer :: next
  end type immobile_decay_rxn_type

  type, public :: immobile_type

    PetscInt :: nimmobile
    PetscBool :: print_all

    type(immobile_species_type), pointer :: list
    type(immobile_decay_rxn_type), pointer :: decay_rxn_list

    ! immobile species
    character(len=MAXWORDLENGTH), pointer :: names(:)
    PetscBool, pointer :: print_me(:)

    ! decay rxn
    PetscInt :: ndecay_rxn
    PetscInt, pointer :: decayspecid(:)
    PetscReal, pointer :: decay_rate_constant(:)

  end type immobile_type

  interface ReactionImGetSpeciesIDFromName
    module procedure ReactionImGetSpeciesIDFromName1
    module procedure ReactionImGetSpeciesIDFromName2
  end interface

  public :: ReactionImCreateAux, &
            ReactionImSpeciesCreate, &
            ReactionImConstraintCreate, &
            ReactionImDecayRxnCreate, &
            ReactionImGetCount, &
            ReactionImConstraintDestroy, &
            ReactionImGetSpeciesIDFromName, &
            ReactionImDestroyAux

contains

! ************************************************************************** !

function ReactionImCreateAux()
  !
  ! Allocate and initialize immobile object
  !
  ! Author: Glenn Hammond
  ! Date: 01/11/13
  !
  implicit none

  type(immobile_type), pointer :: ReactionImCreateAux

  type(immobile_type), pointer :: immobile

  allocate(immobile)
  nullify(immobile%list)
  nullify(immobile%decay_rxn_list)
  immobile%nimmobile = 0
  immobile%print_all = PETSC_FALSE
  nullify(immobile%names)
  nullify(immobile%print_me)

  immobile%ndecay_rxn = 0
  nullify(immobile%decayspecid)
  nullify(immobile%decay_rate_constant)

  ReactionImCreateAux => immobile

end function ReactionImCreateAux

! ************************************************************************** !

function ReactionImSpeciesCreate()
  !
  ! Allocate and initialize a immobile species object
  !
  ! Author: Glenn Hammond
  ! Date: 01/02/13
  !
  implicit none

  type(immobile_species_type), pointer :: ReactionImSpeciesCreate

  type(immobile_species_type), pointer :: species

  allocate(species)
  species%id = 0
  species%name = ''
  species%molar_weight = 0.d0
  species%print_me = PETSC_FALSE
  nullify(species%next)

  ReactionImSpeciesCreate => species

end function ReactionImSpeciesCreate

! ************************************************************************** !

function ReactionImConstraintCreate(immobile,option)
  !
  ! Creates a immobile constraint object
  !
  ! Author: Glenn Hammond
  ! Date: 01/07/13
  !
  use Option_module

  implicit none

  type(immobile_type) :: immobile
  type(option_type) :: option
  type(immobile_constraint_type), pointer :: ReactionImConstraintCreate

  type(immobile_constraint_type), pointer :: constraint

  allocate(constraint)
  allocate(constraint%names(immobile%nimmobile))
  constraint%names = ''
  allocate(constraint%constraint_conc(immobile%nimmobile))
  constraint%constraint_conc = 0.d0
  allocate(constraint%constraint_aux_string(immobile%nimmobile))
  constraint%constraint_aux_string = ''
  allocate(constraint%external_dataset(immobile%nimmobile))
  constraint%external_dataset = PETSC_FALSE

  ReactionImConstraintCreate => constraint

end function ReactionImConstraintCreate

! ************************************************************************** !

function ReactionImDecayRxnCreate()
  !
  ! Allocate and initialize a immobile decay reaction
  !
  ! Author: Glenn Hammond
  ! Date: 03/31/15
  !
  implicit none

  type(immobile_decay_rxn_type), pointer :: ReactionImDecayRxnCreate

  type(immobile_decay_rxn_type), pointer :: rxn

  allocate(rxn)
  rxn%id = 0
  rxn%species_name = ''
  rxn%rate_constant = 0.d0
  rxn%half_life = 0.d0
  rxn%print_me = PETSC_FALSE
  nullify(rxn%next)

  ReactionImDecayRxnCreate => rxn

end function ReactionImDecayRxnCreate

! ************************************************************************** !

function ReactionImGetCount(immobile)
  !
  ! Returns the number of immobile species
  !
  ! Author: Glenn Hammond
  ! Date: 01/02/13
  !

  implicit none

  PetscInt :: ReactionImGetCount
  type(immobile_type) :: immobile

  type(immobile_species_type), pointer :: immobile_species

  ReactionImGetCount = 0
  immobile_species => immobile%list
  do
    if (.not.associated(immobile_species)) exit
    ReactionImGetCount = ReactionImGetCount + 1
    immobile_species => immobile_species%next
  enddo

end function ReactionImGetCount

! ************************************************************************** !

function ReactionImGetSpeciesIDFromName1(name,immobile,option)
  !
  ! Returns the id of named immobile species
  !
  ! Author: Glenn Hammond
  ! Date: 01/28/13
  !
  use Option_module
  use String_module

  implicit none

  character(len=MAXWORDLENGTH) :: name
  type(immobile_type) :: immobile
  type(option_type) :: option

  PetscInt :: ReactionImGetSpeciesIDFromName1

  ReactionImGetSpeciesIDFromName1 = &
    ReactionImGetSpeciesIDFromName2(name,immobile,PETSC_TRUE,option)

end function ReactionImGetSpeciesIDFromName1

! ************************************************************************** !

function ReactionImGetSpeciesIDFromName2(name,immobile,stop_on_error,option)
  !
  ! Returns the id of named immobile species
  !
  ! Author: Glenn Hammond
  ! Date: 01/28/13
  !

  use Option_module
  use String_module

  implicit none

  character(len=MAXWORDLENGTH) :: name
  type(immobile_type) :: immobile
  PetscBool :: stop_on_error
  type(option_type) :: option

  PetscInt :: ReactionImGetSpeciesIDFromName2

  type(immobile_species_type), pointer :: species
  PetscInt :: i

  ReactionImGetSpeciesIDFromName2 = UNINITIALIZED_INTEGER

  ! if the primary species name list exists
  if (associated(immobile%names)) then
    do i = 1, size(immobile%names)
      if (StringCompare(name,immobile%names(i), &
                        MAXWORDLENGTH)) then
        ReactionImGetSpeciesIDFromName2 = i
        exit
      endif
    enddo
  else
    species => immobile%list
    i = 0
    do
      if (.not.associated(species)) exit
      i = i + 1
      if (StringCompare(name,species%name,MAXWORDLENGTH)) then
        ReactionImGetSpeciesIDFromName2 = i
        exit
      endif
      species => species%next
    enddo
  endif

  if (stop_on_error .and. ReactionImGetSpeciesIDFromName2 <= 0) then
    option%io_buffer = 'Species "' // trim(name) // &
      '" not found among immobile species in ReactionImGetSpeciesIDFromName().'
    call PrintErrMsg(option)
  endif

end function ReactionImGetSpeciesIDFromName2

! ************************************************************************** !

subroutine ReactionImDestroyImmobileSpecies(species)
  !
  ! Deallocates a immobile species
  !
  ! Author: Glenn Hammond
  ! Date: 01/02/13
  !

  implicit none

  type(immobile_species_type), pointer :: species

  if (.not.associated(species)) return

  deallocate(species)
  nullify(species)

end subroutine ReactionImDestroyImmobileSpecies

! ************************************************************************** !

recursive subroutine ReactionImDestroyDecayRxn(rxn)
  !
  ! Deallocates a general reaction
  !
  ! Author: Glenn Hammond
  ! Date: 03/31/15
  !

  implicit none

  type(immobile_decay_rxn_type), pointer :: rxn

  if (.not.associated(rxn)) return

  call ReactionImDestroyDecayRxn(rxn%next)
  nullify(rxn%next)
  deallocate(rxn)
  nullify(rxn)

end subroutine ReactionImDestroyDecayRxn

! ************************************************************************** !

subroutine ReactionImConstraintDestroy(constraint)
  !
  ! Destroys a immobile constraint object
  !
  ! Author: Glenn Hammond
  ! Date: 03/12/10
  !

  use Utility_module, only: DeallocateArray

  implicit none

  type(immobile_constraint_type), pointer :: constraint

  if (.not.associated(constraint)) return

  call DeallocateArray(constraint%names)
  call DeallocateArray(constraint%constraint_conc)
  call DeallocateArray(constraint%constraint_aux_string)
  call DeallocateArray(constraint%external_dataset)

  deallocate(constraint)
  nullify(constraint)

end subroutine ReactionImConstraintDestroy

! ************************************************************************** !

subroutine ReactionImDestroyAux(immobile)
  !
  ! Deallocates a immobile object
  !
  ! Author: Glenn Hammond
  ! Date: 05/29/08
  !

  use Utility_module, only: DeallocateArray

  implicit none

  type(immobile_type), pointer :: immobile

  type(immobile_species_type), pointer :: cur_immobile_species, &
                                         prev_immobile_species

  if (.not.associated(immobile)) return

  ! immobile species
  cur_immobile_species => immobile%list
  do
    if (.not.associated(cur_immobile_species)) exit
    prev_immobile_species => cur_immobile_species
    cur_immobile_species => cur_immobile_species%next
    call ReactionImDestroyImmobileSpecies(prev_immobile_species)
  enddo
  nullify(immobile%list)

  call DeallocateArray(immobile%names)
  call DeallocateArray(immobile%print_me)

  call ReactionImDestroyDecayRxn(immobile%decay_rxn_list)
  call DeallocateArray(immobile%decayspecid)
  call DeallocateArray(immobile%decay_rate_constant)

  deallocate(immobile)
  nullify(immobile)

end subroutine ReactionImDestroyAux

end module Reaction_Immobile_Aux_module
