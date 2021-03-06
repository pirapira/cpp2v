(*
 * Copyright (C) BedRock Systems Inc. 2020 Gregory Malecha
 *
 * SPDX-License-Identifier: LGPL-2.1 WITH BedRock Exception for use over network, see repository root for details.
 *)
From bedrock.lang.cpp Require Import ast semantics.
From bedrock.lang.cpp.logic Require Import
     pred path_pred heap_pred.

Set Primitive Projections.

Section with_cpp.
  Context `{Σ : cpp_logic ti}.

  (* "points to" *)
  Structure AT : Type :=
  { AT_lhs    : Type
  ; #[canonical(false)] AT_rhs    : Type
  ; #[canonical(false)] AT_result : Type
  ; #[canonical(false)] AT_at     :> AT_lhs -> AT_rhs -> AT_result
  }.
  Arguments AT_at {!AT} _ _ : rename.

  Canonical Structure mpred_AT : AT :=
    {| AT_at := heap_pred._at (Σ:=Σ) |}.

  Canonical Structure Rep_AT : AT :=
    {| AT_at := heap_pred._offsetR (Σ:=Σ) |}.

  Canonical Structure mpred_val_AT : AT :=
    {| AT_at v := heap_pred._at (Σ:=Σ) (_eqv v) |}.

  Canonical Structure mpred_ptr_AT : AT :=
    {| AT_at v := heap_pred._at (Σ:=Σ) (_eq v) |}.

  Canonical Structure Rep_field_AT {σ : genv} : AT :=
    {| AT_at v := heap_pred._offsetR (Σ:=Σ) (_field (resolve:=σ) v) |}.

  (* coercions to Offset *)
  Structure TO_OFFSET : Type :=
  { TO_OFFSET_from :> Type
  ; #[canonical(false)] _to_offset : TO_OFFSET_from -> Offset
  }.
  Arguments _to_offset {!TO_OFFSET} _ : rename.

  Canonical Structure TO_OFFSET_field {σ : genv} := {| _to_offset := @_field _ Σ σ |}.
  Canonical Structure TO_OFFSET_offset := {| _to_offset := @id Offset |}.

  (* paths *)
  Structure DOT : Type :=
  { DOT_from : Type
  ; #[canonical(false)] DOT_to : Type
  ; #[canonical(false)] DOT_dot : Offset -> DOT_from -> DOT_to
  }.
  Arguments DOT_dot {!AT} _ _ : rename.

  Canonical Structure DOT_offset_loc : DOT :=
    {| DOT_dot := _offsetL |}.
  Canonical Structure DOT_field_offset {σ : genv} : DOT :=
    {| DOT_dot o f := path_pred._dot (@_field _ Σ σ f) o |}.
  Canonical Structure DOT_offset_offset : DOT :=
    {| DOT_dot := path_pred._dot |}.
  Canonical Structure DOT_ptr_offset : DOT :=
    {| DOT_dot o p := _offsetL o (_eq p) |}.
  Canonical Structure DOT_val_offset : DOT :=
    {| DOT_dot o p := _offsetL o (_eqv p) |}.

End with_cpp.

(* notations *)
Local Ltac simple_refine ____x :=
  let x' := eval cbv beta iota delta
                 [ ____x
                   AT_lhs AT_rhs AT_result  AT_at
                   mpred_AT Rep_AT mpred_val_AT mpred_ptr_AT Rep_field_AT
                   TO_OFFSET_from  _to_offset
                   TO_OFFSET_field TO_OFFSET_offset
                   DOT_from DOT_to DOT_dot
                   DOT_offset_loc DOT_field_offset DOT_offset_offset DOT_ptr_offset DOT_val_offset ] in ____x in
  exact x'.

Notation "l |-> r" := (match @AT_at _ l r with
                       | ____x => ltac:(simple_refine ____x)
                       end)
  (at level 15, r at level 20, right associativity, only parsing).
Notation "l |-> r" := (_at l r)
  (at level 15, r at level 20, right associativity, only printing).
Notation "l |-> r" := (_offsetR l r)
  (at level 15, r at level 20, right associativity, only printing).

Notation "p ., o" := (match @DOT_dot _ _ _ (@_to_offset _ _ _ o) p with
                      | ____x => ltac:(simple_refine ____x)
                      end)
  (at level 11, left associativity, only parsing).

Notation "p .[ t ! n ]" := (match @DOT_dot _ _ _ (@_sub _ _ _ t n%Z) p with
                            | ____x => ltac:(simple_refine ____x)
                            end)
  (at level 11, left associativity, only parsing).
Notation ".[ t ! n ]" := ((@_sub _ _ _ t n%Z))
  (at level 11, only parsing).

Notation "p ., o" := (_dot o p)
  (at level 11, left associativity, only printing,
   format "p  .,  o").
Notation "p ., o" := (_offsetL o p)
  (at level 11, left associativity, only printing,
   format "p  .,  o").

Notation ".[ t ! n ]" := ((@_sub _ _ _ t n))
  (at level 11, no associativity, only printing, format ".[  t  !  n  ]").
Notation "p .[ t ! n ]" := (_offsetL (@_sub _ _ _ t n) p)
  (at level 11, left associativity, only printing, format "p  .[  t  '!'  n  ]").

Existing Class genv.

(* Test suite *)
Section test_suite.

  Context {σ : genv} `{Σ : cpp_logic ti} (R : Rep) (f g : field) (o : Offset) (l : Loc) (p : ptr) (v : val).

  Open Scope bi_scope.

  Example _0 := |> l |-> R.

  Example _1 := |> l ., f |-> R.

  Example _2 := l |-> f |-> R.

  Example _3 := l .[ T_int ! 0 ] |-> R.

  Example _4 := l |-> f .[ T_int ! 0 ] |-> R.

  Example _5 := l .[ T_int ! 0 ] .[ T_int ! 3 ] |-> R.

  Example _6 := l ., f .[ T_int ! 0 ] ., g |-> R.

  Example _7 := l ., g ., f .[ T_int ! 1 ] .[ T_int ! 0 ] ., f |-> f |-> R.

  Example _8 := p ., g ., f .[ T_int ! 1 ] .[ T_int ! 0 ] ., f |-> .[ T_int ! 1 ] |-> R.

  Example _9 := o ., g ., f .[ T_int ! 1 ] .[ T_int ! 0 ] ., f |-> R.

  Example _10 := o ., g ., f .[ T_int ! 1 ] .[ T_int ! 0 ] ., f |-> R.

  Example _11 := o .[ T_int ! 1 ] |-> R.

  Example _12 := o .[ T_int ! 1 ] |-> R.

  Example _13 := v .[ T_int ! 1 ] |-> R.

  Example _14 := .[ T_int ! 1 ] |-> R.

  Example _15 := |> .[ T_int ! 1 ] |-> |> R.

  Fail Example _16 := l |-> ▷ R ∗ R.
  Fail Example _16 := l |-> |> R ** R. (* requires parsing as [(l |-> |> R) ** R] *)

  Fail Example _f := l |-> R ** R. (* requires parsing as [(l |-> R) ** R] *)

  Fail Example _BAD := l |-> R q.

End test_suite.
