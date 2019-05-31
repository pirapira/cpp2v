Require Import Coq.ZArith.BinInt.
Require Import Coq.micromega.Lia.
Require Import Coq.Lists.List.
Require Import Coq.Strings.String.
Require Import Coq.Logic.ClassicalDescription.

From Coq.Classes Require Import
     RelationClasses Morphisms.

From ChargeCore.SepAlg Require Import SepAlg.

From ChargeCore.Logics Require Import
     ILogic BILogic ILEmbed Later.

From Cpp Require Import
     Ast.
From Cpp.Sem Require Import
     Semantics Logic Expr.
From Cpp.Auto Require Import
     Discharge.

Module Type cclogic.


  (* fractional points to relation val_{Q} -> val
     I comment out this fractional points to relation
     as we can encode this through RA. So there is no
     need for a hard-coded default one.
  *)
  (*Parameter fptsto : val -> Q -> val -> mpred.*)
  
  (****** Logical State ********)
  
  (*carrier is the data type through which we would like to 
     represent bookkeeping in resource algebra. Simply, the 
    type to be passed to the resource algebra -- carrier.
    ex: Inductive FracPerm_Carrier :=
                | QPermission (f:Q)
                | QPermissionUndef.
    Note: Deciding what the carrier is going to be depends on
    the verification problem.
   *)
  Definition carrier := Type.

  (*
    Resource Algebra Record: TODO: Ask Gregory the type for the ChargeCore. 
    For now let's call it carrier_monoid but normally it has to have 
    
    Here is an example to a carrier_monoid
    
    Program Definition FracPerm_{
      RA :> Type // Ex: we pass our FracPerm_Carrier type
                 // Ex: we create one instance of FracPerm via 
                 // a constructor of the carrier QPermission(1/2)

      RA_emp     // Ex: Define what is Emp for FracPerm_Carrier and pass it here
      RA_plus/join // Ex: Composition of the two FracPerm_Carriers has to be defined and passed here
      ...
      RA_refl
      RA_trans
      //structural rules    
    }

   *)

  Parameter carrier_monoid : Type.

  (* carrier_monoid has to be guarded against duplicability *)
  Parameter carrier_guard : carrier_monoid -> list carrier_monoid -> mpred.
  Variable guard_container : list carrier_monoid.

  (*A generic fractional points to relation encoded using monoids x points to v with permission p.  
   Ex: logical_fptsto FracPerm (bookeeping_already_existing_resources) (QPermission frac) x v 
  *)
  Axiom logical_fptsto: forall  (perm : carrier_monoid) (guard : In perm guard_container)  (p : Set (*todo(isk): has to be perm*)) (x : val) (v : val), mpred.

  (*A generic ghost location gl and a value kept gv.  ghost *)
  Axiom logical_ghost: forall (ghost : carrier_monoid) (guard : In ghost guard_container)  (gl : Set (*todo(isk): has to be ghost*)) (gv : val), mpred.

  (*Introducing ghost*)
  (*
    Gregory suggests emp |- Exists g. g:m
  *)
  Parameter wp_ghst : Expr -> (val -> mpred) -> mpred.

   (*
     {P} E {Q}
    ------------
    {P} E {Q * exists l. l:g} //ghost location l carries the ghost resource g
   *)

  (**************************************
    A General Note to Gregory : If we want to refer to resources encoded via monoids -- let's say Pg -- then we have to bookkeep/pass
    guard and containers (guard: In monoid_instance guard_container). Specs below assume that we do not refer to any resource encoded 
    via monoids so there exists no guard and monoid container that we defined above. In case we want you can introduce them to the specs below.
  **************************************)

  (*******Atomic Instruction Specification*******)

  Axiom rule_ghost_intro:
  forall  g P E Qp CMI (guard: In CMI guard_container) (ptriple: P |-- (wp_ghst E Qp)),
     P |-- ( wp_ghst E (fun v =>  (Qp v) ** (Exists l, logical_ghost CMI  guard l g))). 

 (* list ValCat * Expr*)
  Parameter wp_atom : AtomicOp -> list val -> type -> (val -> mpred) -> mpred.

  Axiom wp_rhs_atomic: forall rslv ti r ao es ty Q,
    wps (wpAnys (resolve:=rslv) ti r) es  (fun (vs : list val) (free : FreeTemps) => wp_atom ao vs ty (fun v=> Q v free)) empSP
        |-- wp_rhs (resolve:=rslv) ti r (Eatomic ao es ty) Q.
  
  Definition atomdec (P: Prop) :=
   if (excluded_middle_informative P) then true else false.

  (*Ideas adopted from the paper: Relaxed Separation Logic: A program logic for C11 Concurrency -- Vefeiadis et al. *)

  (*Facts that needs to hold when a location is initialized*)
  Parameter Init: val -> mpred.
  
  (*Atomic CAS access permission*)
  Parameter AtomCASPerm :  val -> (val ->mpred) -> mpred .
  
  (*Atomic READ access permission*)
  Parameter AtomRDPerm: val -> (val -> mpred) -> mpred.
  
  (*Atomic WRITE access permission*)
  Parameter AtomWRTPerm: val -> (val -> mpred) -> mpred.

  (* Perm LocInv l * Perm LocInv' l -|- Perm LocInv*LocInv' l 
    Composability of two location invariant maps: val -> mpred on location l
    todo(isk): Existentials are weak?
   *)
  Axiom Splittable_RDPerm: forall (LocInv: val->mpred) (LocInv':val->mpred) l ,  AtomRDPerm l LocInv **  AtomRDPerm l LocInv' 
                          -|- Exists v, (Exists LocInv'', (LocInv'' v -* (LocInv' v ** LocInv v)) //\\ (AtomRDPerm v LocInv'')). 
  
  (*Init is freely duplicable*)
  Axiom Persistent_Initialization : forall l , Init  l -|- Init  l ** Init  l.
  
  (*Atomic CAS access permission is duplicable*)
  Axiom Persistent_CASPerm : forall l LocInv,  AtomCASPerm l LocInv -|- AtomCASPerm l LocInv  ** AtomCASPerm l LocInv.

  (*Generate atomic access token via consuming the initially holding invariant*)
  Axiom Generate_CASPerm : forall x (t:type) (Inv:val->mpred) , Exists v, tptsto t x v **  Inv v  |-- AtomCASPerm x Inv.

  (*Memory Ordering Patterns: Now we only have _SEQ_CST *)
  Definition _SEQ_CST := Vint 5.
  Definition Vbool (b : bool) :=
    Vint (if b then 1 else 0).
  
  (* *)
  Axiom Splittable_WRTPerm: forall (LocInv: val->mpred) (LocInv':val->mpred) l ,  AtomRDPerm l LocInv **  AtomRDPerm l LocInv' 
                           -|- Exists v, (Exists LocInv'', (LocInv'' v -* (LocInv' v \\// LocInv v)) //\\ (AtomRDPerm v LocInv'')).
  
  (* r := l.load -- we can think of this as r := l.load(acc_type) *)
  (*todo(isk): give up the permission to read the same value again with same permission *)
  Axiom rule_atomic_load: forall (acc_type:type)  l (LocInv: val -> mpred),
      (Init  l ** AtomRDPerm l LocInv) |--
            (wp_atom AO__atomic_load (l::nil) acc_type
            (fun r => LocInv r)).

 
  (* l.store(v) -- we can think of it as l.store(v,acc_type)
     
  *)
   Axiom rule_atomic_store : forall (acc_type:type) v l (LocInv: val -> mpred),
      (AtomWRTPerm l LocInv ** LocInv l)
        |-- (wp_atom AO__atomic_store (l::v::nil) acc_type
            (fun r => Init l ** AtomWRTPerm l LocInv)).
  
  
  (*atomic compare and exchange rule
   todo(isk): check the number of args -- 6 -- and order of them.
  *)
  Axiom rule_atomic_compare_exchange :
    forall P E E' E'' Qp  Q
           (acc_type : type) 
           (preserve:  P ** Qp E'  |-- Qp E'' ** Q),
      (P  ** AtomCASPerm E Qp)
        |-- (wp_atom AO__atomic_compare_exchange (E::E'::E''::nil) acc_type
            (fun x => if excluded_middle_informative (x = E') then
                                  Q else
                        P  ** AtomCASPerm E Qp)).
  (*Atomic compare and exchange n -- we use this in spinlock module*)
  Axiom rule_atomic_compare_exchange_n:
    forall P E E' E'' wk succmemord failmemord Qp Q'  (Q:mpred)
           (acc_type : type) 
           (preserve:  P ** Qp E'  |-- Qp E'' ** Q),
      (P  ** AtomCASPerm E Qp ** [|wk = Vbool false|] ** [|succmemord = _SEQ_CST|] ** [| failmemord = _SEQ_CST |]) **
       (Forall x, (if excluded_middle_informative (x = E') then
                                  Q else
                    P  ** AtomCASPerm E Qp) -* Q' x) |-- 
       wp_atom AO__atomic_compare_exchange_n (E::succmemord::E'::failmemord::E''::wk::nil) acc_type Q'.
         
  (*atomic fetch and add rule*)
  Axiom rule_atomic_fetch_add : 
    forall P released keptforinv E Qp pls
         (acc_type : type)
         (split: forall v,  P |-- (released v) ** (keptforinv v))
         (atom_xchng: forall v, ((released v) ** (AtomCASPerm E Qp)) |--
                        (wp_atom AO__atomic_compare_exchange  (E::v::pls::nil) acc_type
                                 (fun x => if (excluded_middle_informative(x = v)) then
                                                 (keptforinv v) else
                                                 ((released v) ** (AtomCASPerm E Qp))))),
      (P ** (AtomCASPerm E Qp)) |--
              (wp_atom AO__atomic_fetch_add (E::pls::nil) acc_type
                       (fun x:val => keptforinv x)).
  
End cclogic.

Declare Module CCL : cclogic.

Export CCL.

Export ILogic BILogic ILEmbed Later.
