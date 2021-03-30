using Fermi.HartreeFock

export RCCSD

abstract type RCCSDAlgorithm end

function get_rccsd_alg()
    implemented = [RCCSDa()]
    N = Options.get("cc_alg")
    try 
        return implemented[N]
    catch BoundsError
        throw(InvalidFermiOption("implementation number $N not available for RCCSD."))
    end
end

"""
    Fermi.CoupledCluster.RCCSD
    TODO

Fermi struct that holds information about RCCSD wavefunctions

# Fields

    CorrelationEnergy   CCSD correlation energy
    T1                  T1 amplitudes
    T2                  T2 amplitudes

_struct tree:_

**RCCSD** <: AbstractCCWavefunction <: AbstractCorrelatedWavefunction <: AbstractWavefunction
"""
struct RCCSD{T} <: AbstractCCWavefunction 
    guessenergy::T
    correlation::T
    T1::AbstractArray{T,2}
    T2::AbstractArray{T,4}
    converged::Bool
end

function RCCSD()
    aoints = IntegralHelper{Float64}()
    rhf = RHF(aoints)
    moints = IntegralHelper(orbitals=rhf.orbitals)
    RCCSD(moints, aoints)
end

function RCCSD(moints::IntegralHelper{T1,Chonky,O}, aoints::IntegralHelper{T2,Chonky,AtomicOrbitals}) where {T1<:AbstractFloat,
                                                                                        T2<:AbstractFloat,O<:AbstractOrbitals}
    Fermi.Integrals.mo_from_ao(moints, aoints, "Fd","OOOO", "OOOV", "OOVV", "OVOV", "OVVV", "VVVV")
    RCCSD(moints)
end

function RCCSD(moints::IntegralHelper{T1,E1,O}, aoints::IntegralHelper{T2,E2,AtomicOrbitals}) where {T1<:AbstractFloat,T2<:AbstractFloat,
                                                                                E1<:AbstractDFERI,E2<:AbstractDFERI,O<:AbstractOrbitals}
    Fermi.Integrals.mo_from_ao(moints, aoints, "Fd","BOO", "BOV", "BVV")
    RCCSD(moints)
end

function RCCSD{Float64}(mol = Molecule(), ints = IntegralHelper{Float64}())

    # Compute Restricted Hartree-Fock
    refwfn = RHF(mol, ints)

    # Delete integrals that are not gonna be used anymore
    delete!(ints, "S", "T", "V", "JKERI")
    RCCSD{Float64}(refwfn, ints)
end

function RCCSD{Float32}(mol = Molecule(), ints = IntegralHelper{Float32}())

    # Note that using this method a new IntegralHelper object
    # is created within the RHF call. This is necessary becasue
    # RHF needs a double precision integral helper

    # Compute Restricted Hartree-Fock
    refwfn = RHF(mol)

    RCCSD{Float32}(refwfn, ints)
end

function RCCSD(moints::IntegralHelper{T,E,O}) where {T<:AbstractFloat,E<:AbstractERI,O<:AbstractRestrictedOrbitals}

    # Create zeroed guesses for amplitudes

    o = moints.molecule.Nα - Options.get("drop_occ")
    v = size(moints.orbitals.C,1) - Options.get("drop_vir") - moints.molecule.Nα
    T1guess = FermiMDzeros(T, o, v)
    T2guess = FermiMDzeros(T, o, o, v, v)
    RCCSD(moints, T1guess, T2guess, get_rccsd_alg())
end


"""
    Fermi.CoupledCluster.RCCSD{T}()

Compute a RCCSD wave function for a given precision T (Float64 or Float32)
"""
function RCCSD{T}(guess::RCCSD{Tb}) where { T <: AbstractFloat,
                                           Tb <: AbstractFloat }
    alg = select_algorithm(Fermi.CurrentOptions["cc_alg"])
    RCCSD{T}(guess,alg)
end

# For each implementation a singleton type must be create
struct RCCSDa <: RCCSDAlgorithm end
include("RCCSDa.jl")