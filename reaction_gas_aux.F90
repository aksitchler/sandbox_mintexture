module Reaction_Gas_Aux_module

#include "petsc/finclude/petscsys.h"
  use petscsys

  use Reaction_Database_Aux_module

  use PFLOTRAN_Constants_module

  implicit none

  private

  PetscInt, parameter, public :: NULL_GAS = 0
  PetscInt, parameter, public :: ACTIVE_GAS = 1
  PetscInt, parameter, public :: PASSIVE_GAS = 2
  PetscInt, parameter, public :: ACTIVE_AND_PASSIVE_GAS = 3

  type, public :: gas_species_type
    PetscInt :: id
    character(len=MAXWORDLENGTH) :: name
    PetscReal :: itype
    PetscReal :: molar_volume
    PetscReal :: molar_weight
    PetscBool :: print_me
    type(database_rxn_type), pointer :: dbaserxn
    type(gas_species_type), pointer :: next
  end type gas_species_type

  type, public :: gas_type

    PetscInt :: ngas
    PetscInt :: nactive_gas
    PetscInt :: npassive_gas

    type(gas_species_type), pointer :: list

    ! gas species names
    character(len=MAXWORDLENGTH), pointer :: active_names(:)
    character(len=MAXWORDLENGTH), pointer :: passive_names(:)
    PetscBool :: print_all
    PetscBool :: print_concentration
    PetscBool :: print_partial_pressure
    PetscBool, pointer :: active_print_me(:)
    PetscBool, pointer :: passive_print_me(:)

    PetscInt, pointer :: acteqspecid(:,:)   ! (0:ncomp in rxn)
    PetscReal, pointer :: acteqstoich(:,:)
    PetscInt, pointer :: acteqh2oid(:)       ! id of water, if present
    PetscReal, pointer :: acteqh2ostoich(:)  ! stoichiometry of water, if present
    PetscReal, pointer :: acteqlogK(:)
    PetscReal, pointer :: acteqlogKcoef(:,:)

    PetscReal, pointer :: actmolarwt(:)
    PetscReal, pointer :: pasmolarwt(:)

    PetscInt, pointer :: paseqspecid(:,:)   ! (0:ncomp in rxn)
    PetscReal, pointer :: paseqstoich(:,:)
    PetscInt, pointer :: paseqh2oid(:)       ! id of water, if present
    PetscReal, pointer :: paseqh2ostoich(:)  ! stoichiometry of water, if present
    PetscReal, pointer :: paseqlogK(:)
    PetscReal, pointer :: paseqlogKcoef(:,:)

  end type gas_type


  public :: ReactionGasCreateAux, &
            ReactionGasCreateGasSpecies, &
            ReactionGasGetGasNames, &
            ReactionGasGetGasCount, &
            ReactionGasMergeDupGasSpecies, &
            ReactionGasDestroyAux, &
            ReactionGasGetGasIDFromName

contains

! ************************************************************************** !

function ReactionGasCreateAux()
  !
  ! Allocate and initialize gas reaction object
  !
  ! Author: Glenn Hammond
  ! Date: 08/01/16
  !

  implicit none

  type(gas_type), pointer :: ReactionGasCreateAux

  type(gas_type), pointer :: gas

  allocate(gas)

  gas%ngas = 0
  gas%nactive_gas = 0
  gas%npassive_gas = 0
  gas%print_all = PETSC_FALSE
  gas%print_concentration = PETSC_FALSE
  gas%print_partial_pressure = PETSC_FALSE
  nullify(gas%list)
  nullify(gas%active_names)
  nullify(gas%passive_names)
  nullify(gas%active_print_me)
  nullify(gas%passive_print_me)

  nullify(gas%acteqspecid)
  nullify(gas%acteqstoich)
  nullify(gas%acteqh2oid)
  nullify(gas%acteqh2ostoich)
  nullify(gas%acteqlogK)
  nullify(gas%acteqlogKcoef)

  nullify(gas%actmolarwt)
  nullify(gas%pasmolarwt)

  nullify(gas%paseqspecid)
  nullify(gas%paseqstoich)
  nullify(gas%paseqh2oid)
  nullify(gas%paseqh2ostoich)
  nullify(gas%paseqlogK)
  nullify(gas%paseqlogKcoef)

  ReactionGasCreateAux => gas

end function ReactionGasCreateAux

! ************************************************************************** !

function ReactionGasCreateGasSpecies()
  !
  ! Allocate and initialize a gas species object
  !
  ! Author: Glenn Hammond
  ! Date: 05/02/08
  !
  implicit none

  type(gas_species_type), pointer :: ReactionGasCreateGasSpecies

  type(gas_species_type), pointer :: gas_species

  allocate(gas_species)
  gas_species%id = 0
  gas_species%itype = NULL_GAS
  gas_species%name = ''
  gas_species%molar_volume = 0.d0
  gas_species%molar_weight = 0.d0
  gas_species%print_me = PETSC_FALSE
  nullify(gas_species%dbaserxn)
  nullify(gas_species%next)

  ReactionGasCreateGasSpecies => gas_species

end function ReactionGasCreateGasSpecies

! ************************************************************************** !

function ReactionGasGetGasNames(gas,gas_itype)
  !
  ! Returns the names of gases in an array
  !
  ! Author: Glenn Hammond
  ! Date: 10/21/08
  !

  implicit none

  type(gas_type) :: gas
  PetscInt :: gas_itype

  character(len=MAXWORDLENGTH), pointer :: ReactionGasGetGasNames(:)

  PetscInt :: count
  character(len=MAXWORDLENGTH), pointer :: names(:)
  type(gas_species_type), pointer :: gas_species

  count = ReactionGasGetGasCount(gas,gas_itype)
  allocate(names(count))

  count = 1
  gas_species => gas%list
  do
    if (.not.associated(gas_species)) exit
    if (gas_species%itype == gas_itype .or. &
        gas_species%itype == ACTIVE_AND_PASSIVE_GAS .or. &
        gas_itype == ACTIVE_AND_PASSIVE_GAS) then
      names(count) = gas_species%name
      count = count + 1
    endif
    gas_species => gas_species%next
  enddo

  ReactionGasGetGasNames => names

end function ReactionGasGetGasNames

! ************************************************************************** !

function ReactionGasGetGasCount(gas,gas_itype)
  !
  ! Returns the number of gas species in list
  !
  ! Author: Glenn Hammond
  ! Date: 08/02/16
  !
  implicit none

  type(gas_type) :: gas
  PetscInt :: gas_itype

  PetscInt :: ReactionGasGetGasCount

  type(gas_species_type), pointer :: gas_species

  ReactionGasGetGasCount = 0
  gas_species => gas%list
  do
    if (.not.associated(gas_species)) exit
    if (gas_species%itype == gas_itype .or. &
        gas_species%itype == ACTIVE_AND_PASSIVE_GAS .or. &
        gas_itype == ACTIVE_AND_PASSIVE_GAS) then
      ReactionGasGetGasCount = ReactionGasGetGasCount + 1
    endif
    gas_species => gas_species%next
  enddo

end function ReactionGasGetGasCount

! ************************************************************************** !

function ReactionGasGetGasIDFromName(gas,name)
  !
  ! Returns the id of gas with the corresponding name from a specific list
  !
  ! Author: Glenn Hammond
  ! Date: 08/02/16
  !
  use String_module

  implicit none

  type(gas_type) :: gas
  character(len=MAXWORDLENGTH) :: name

  PetscInt :: ReactionGasGetGasIDFromName
  type(gas_species_type), pointer :: gas_species

  ReactionGasGetGasIDFromName = UNINITIALIZED_INTEGER

  gas_species => gas%list
  do
    if (.not.associated(gas_species)) exit
    if (StringCompare(name,gas_species%name,MAXWORDLENGTH)) then
      ReactionGasGetGasIDFromName = gas_species%id
      exit
    endif
    gas_species => gas_species%next
  enddo

end function ReactionGasGetGasIDFromName

! ************************************************************************** !

subroutine ReactionGasMergeDupGasSpecies(gas_species_list)
  !
  ! Merges duplicate gas species from a list
  !
  ! Author: Glenn Hammond
  ! Date: 08/10/16
  !
  use String_module

  implicit none

  type(gas_species_type), pointer :: gas_species_list

  type(gas_species_type), pointer :: cur_species
  type(gas_species_type), pointer :: cur_species2
  type(gas_species_type), pointer :: prev_species

  cur_species => gas_species_list
  do
    if (.not.associated(cur_species)) exit
    prev_species => cur_species
    cur_species2 => cur_species%next
    do
      if (.not.associated(cur_species2)) exit
      if (StringCompare(cur_species%name,cur_species2%name, &
                        MAXWORDLENGTH)) then
        if (cur_species%itype /= cur_species2%itype) then
          cur_species%itype = ACTIVE_AND_PASSIVE_GAS
        endif
        prev_species%next => cur_species2%next
        call ReactionGasDestroyGasSpecies(cur_species2)
        cur_species2 => prev_species%next
      else
        prev_species => cur_species2
        cur_species2 => cur_species2%next
      endif
    enddo
    cur_species => cur_species%next
  enddo

end subroutine ReactionGasMergeDupGasSpecies

! ************************************************************************** !

recursive subroutine ReactionGasDestroyGasSpeciesList(gas_species)
  !
  ! Deallocates a gas species
  !
  ! Author: Glenn Hammond
  ! Date: 05/29/08
  !

  implicit none

  type(gas_species_type), pointer :: gas_species

  if (.not.associated(gas_species)) return

  if (associated(gas_species%next)) then
    call ReactionGasDestroyGasSpeciesList(gas_species%next)
  endif

  call ReactionGasDestroyGasSpecies(gas_species)

end subroutine ReactionGasDestroyGasSpeciesList

! ************************************************************************** !

recursive subroutine ReactionGasDestroyGasSpecies(gas_species)
  !
  ! Deallocates a gas species
  !
  ! Author: Glenn Hammond
  ! Date: 05/29/08
  !

  implicit none

  type(gas_species_type), pointer :: gas_species

  if (associated(gas_species%dbaserxn)) &
    call ReactionDBDestroyRxn(gas_species%dbaserxn)
  deallocate(gas_species)
  nullify(gas_species)

end subroutine ReactionGasDestroyGasSpecies

! ************************************************************************** !

subroutine ReactionGasDestroyAux(gas)
  !
  ! Deallocates a gas object
  !
  ! Author: Glenn Hammond
  ! Date: 08/01/16
  !

  use Utility_module, only: DeallocateArray

  implicit none

  type(gas_type), pointer :: gas

  if (.not.associated(gas)) return

  call ReactionGasDestroyGasSpeciesList(gas%list)

  call DeallocateArray(gas%active_names)
  call DeallocateArray(gas%passive_names)
  call DeallocateArray(gas%active_print_me)
  call DeallocateArray(gas%passive_print_me)

  call DeallocateArray(gas%acteqspecid)
  call DeallocateArray(gas%acteqstoich)
  call DeallocateArray(gas%acteqh2oid)
  call DeallocateArray(gas%acteqh2ostoich)
  call DeallocateArray(gas%acteqlogK)
  call DeallocateArray(gas%acteqlogKcoef)

  call DeallocateArray(gas%actmolarwt)
  call DeallocateArray(gas%pasmolarwt)

  call DeallocateArray(gas%paseqspecid)
  call DeallocateArray(gas%paseqstoich)
  call DeallocateArray(gas%paseqh2oid)
  call DeallocateArray(gas%paseqh2ostoich)
  call DeallocateArray(gas%paseqlogK)
  call DeallocateArray(gas%paseqlogKcoef)

  deallocate(gas)
  nullify(gas)

end subroutine ReactionGasDestroyAux

end module Reaction_Gas_Aux_module
