From ChargeCore.Logics Require Import
     ILogic BILogic ILEmbed Later.

From Cpp Require Import
     Ast
     HoareSemantics.

Axiom lob_ind : forall P S,
    S //\\ |> P |-- P ->
    S |-- P.

(* note that the meaning of a module must be persistent,
 * if you have non-persistent terms (e.g. ptsto), then you either need
 * to put them inside invariants, or prove that they do not depend on
 * the imports (this would only be a problem if they are initialized via
 * a function call, but I don't think that you can actually do that).
 *)
Definition module (imports exports : mpred) : mpred :=
  (|> imports) -->> exports.

Theorem module_self_link (E : mpred) :
  module E E |-- E.
Proof.
  eapply lob_ind.
  unfold module.
  eapply landAdj. reflexivity.
Qed.

Theorem module_link (I1 I2 E1 E2 : mpred) :
  module (E2 ** I1) E1 ** module (E1 ** I2) E2
  |-- module (I1 ** I2) (E1 ** E2).
Proof. Abort.


Definition module_link (a b : list Decl) : list Decl := a ++ b.

Axiom denoteModule_link : forall nss a b,
    denoteModule nss (module_link a b) -|- denoteModule nss a ** denoteModule nss b.

Lemma lob_link : forall A B : mpred,
    ((|> A) -* B) ** ((|> B) -* A) |-- A ** B.
Proof.
  intros.
  eapply sepSPAdj'.
  rewrite <- empSPL.
  eapply sepSPAdj.
  rewrite <- (landtrueR empSP).
  apply landL2.
  eapply spec_lob.
Abort.
    (* |>A ==> B
     * |>B ==> A
     * A //\\ B
     *)

Axiom illater_wandSP : forall P Q, |> (P -* Q) |-- (|> P) -* (|> Q).
Axiom illater_sepSP : forall P Q, |> (P ** Q) |-- (|> P) ** (|> Q).


Axiom cglob'_dup : forall resolve p fs,
    cglob' (resolve:=resolve) p fs -|- cglob' (resolve:=resolve) p fs ** cglob' (resolve:=resolve) p fs.
Axiom denote_module_dup : forall module,
    denoteModule nil module -|- denoteModule nil module ** denoteModule nil module.