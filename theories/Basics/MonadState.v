(* begin hide *)
From Coq Require Import
     Setoid
     Morphisms.

From ExtLib Require Import
     Structures.Monad.

From ITree Require Import
     Basics.Basics
     Basics.Category
     Basics.CategoryKleisli
     Basics.CategoryKleisliFacts
     Basics.HeterogeneousRelations
     Basics.Tacs
     Basics.Monad
     Basics.MayRet
.

Import ITree.Basics.Basics.Monads.
Import CatNotations.
Import RelNotations.
Local Open Scope relationH_scope.
Local Open Scope cat_scope.
Local Open Scope cat.

Section State.
  Variable m : Type -> Type.
  Variable S : Type.
  Context {EqmRm : EqmR m}.
  Context {Mm : Monad m}.
  Context {EqmROKm : EqmR_OK m}.
  Context {ML : EqmRMonad m}.

  Global Instance EqmR_stateT : EqmR (stateT S m) :=
    {| eqmR :=
         fun A B (R : A -> B -> Prop)
             (f : stateT S m A) (g : stateT S m B) =>
           forall (s : S), eqmR (prod_rel eq R) (f s) (g s) |}.

  Global Instance EqmR_OK_stateT : EqmR_OK (stateT S m).
  Proof.
    split; unfold eqmR, EqmR_stateT; intros.
    - red. reflexivity.
    - red. symmetry; auto.
    - red. intros. eapply transitivity; eauto.
    - specialize (H s). specialize (H0 s).
      rewrite <- (eq_id_r eq). 
      rewrite prod_compose.
      eapply eqmR_rel_trans; auto.
      + apply H.
      + apply H0.
    - split; intros smb sma Heq s.
      + specialize (Heq s).
        apply eqmR_lift_transpose in Heq; auto.
        rewrite transpose_prod in Heq.
        rewrite transpose_sym_eq_rel in Heq; auto.
      + unfold transpose in Heq. specialize (Heq s).
        rewrite <- transpose_sym_eq_rel; auto.
        rewrite <- transpose_prod.
        apply eqmR_lift_transpose; auto.
    - do 3 red. intros. split; intros.
      +  specialize (H0 s). specialize (H1 s). specialize (H2 s).
         rewrite prod_rel_eq in H0.
         rewrite prod_rel_eq in H1.
         rewrite <- H0.
         rewrite <- H1.
         rewrite H in H2.
         assumption.
      + specialize (H0 s). specialize (H1 s). specialize (H2 s).
        rewrite prod_rel_eq in H0.
        rewrite prod_rel_eq in H1.
        assert (eq_rel (prod_rel (@eq S) x) (prod_rel eq y)).
        rewrite H. reflexivity.
        rewrite H3. rewrite H1. rewrite H0. assumption.
    - do 3 red. intros. specialize (H0 s).
      eapply (eqmR_Proper_mono) in H0.
      + apply H0.
      + apply EqmROKm.
      + apply prod_rel_monotone; auto. apply subrelationH_Reflexive.
  Qed.

  Lemma ret_ok :  forall {A1 A2} (RA : A1 -> A2 -> Prop) (a1:A1) (a2:A2),
      RA a1 a2 -> (eqmR RA (ret a1) (ret a2)).
  Proof.
    unfold eqmR, EqmR_stateT.
    intros.
    repeat red. apply eqmR_ret. assumption.
    constructor; auto.
  Qed.

  Instance EqmRMonad_stateT (HS: inhabited S) : @EqmRMonad (stateT S m) _ _.
  Proof.
  constructor.
  - intros; apply ret_ok. assumption.
  - intros.
    unfold eqmR, EqmR_stateT.
    intros s.
    eapply eqmR_bind_ProperH. assumption.
    apply H.
    intros. destruct a1. destruct a2.
    cbn. unfold eqmR, EqmR_stateT in H0.
    inversion H1; subst.
    apply H0. assumption.
   - intros A B RA RB.
     red. intros k HProper a HRA s.
     eapply eqmR_bind_ret_l; auto.
     + instantiate (1:=eq ⊗ RA).
       do 2 red.
       intros sa1 sa2 Hsa.
       destruct sa1 as (s1 & a1). simpl.
       destruct sa2 as (s2 & a2). simpl.
       inversion Hsa. subst.
       apply HProper. assumption.
     + auto.
   - intros.
     unfold eqmR, EqmR_stateT in *. intros.
     specialize (ma_OK s).
     cbn in *.
     Typeclasses eauto := 5.
     setoid_rewrite <- surjective_pairing.
     auto.
     eapply eqmR_bind_ret_r; assumption.
   - unfold eqmR, EqmR_stateT in *.
     intros.
     cbn in *.
     eapply eqmR_bind_bind; try assumption.
     + apply ma_OK.
     + repeat red.
       intros. destruct x. destruct y.
       cbn. inversion H. subst. apply f_OK. assumption.
     + repeat red.
       intros. destruct x. destruct y.
       cbn. inversion H. subst. apply g_OK. assumption.
  Qed.

  Context {Im: Iter (Kleisli m) sum}.
  Context {Cm: Iterative (Kleisli m) sum}.

  Definition iso {a b:Type} (sab : S * (a + b)) : (S * a) + (S * b) :=
    match sab with
    | (s, inl x) => inl (s, x)
    | (s, inr y) => inr (s, y)
    end.

  Definition iso_inv {a b:Type} (sab : (S * a) + (S * b)) : S * (a + b) :=
    match sab with
    | inl (s, a) => (s, inl a)
    | inr (s, b) => (s, inr b)
    end.

  Definition internalize {a b:Type} (f : Kleisli (stateT S m) a b) : Kleisli m (S * a) (S * b) :=
    fun (sa : S * a) => f (snd sa) (fst sa).

  Lemma internalize_eq {a b:Type} (f g : Kleisli (stateT S m) a b) :
    eq2 f g <-> eq2 (internalize f) (internalize g).
  Proof.
    split.
    - intros.
      repeat red. destruct a0.
      unfold internalize. cbn.  specialize (H a0 s). unfold eqmR in H.
      rewrite prod_rel_eq in H. apply H.
    - intros.
      repeat red. intros.
      unfold internalize in H.
      specialize (H (s, a0)).
      rewrite prod_rel_eq.
      apply H.
  Qed.

  Lemma internalize_cat {a b c} (f : Kleisli (stateT S m) a b) (g : Kleisli (stateT S m) b c) :
    (internalize (f >>> g)) ⩯ ((internalize f) >>> (internalize g)).
  Proof.
    repeat red.
    destruct a0.
    cbn.
    unfold internalize.
    unfold cat, Cat_Kleisli.
    cbn.
    reflexivity.
  Qed.

  Lemma internalize_pure {a b c} (f : Kleisli (stateT S m) a b) (g : S * b -> S * c) :
    internalize f >>> pure g   ⩯   (internalize (f >>> (fun b s => ret (g (s,b))))).
  Proof.
    repeat red.
    destruct a0.
    unfold internalize, cat, Cat_Kleisli. cbn.
    apply Proper_bind; auto.
    - reflexivity.
    - repeat red.
      destruct a1.
      unfold pure. reflexivity.
  Qed.

  Global Instance Iter_stateT : Iter (Kleisli (stateT S m)) sum.
  Proof.
    exact
      (fun (a b : Type) (f : a -> S -> m (S * (a + b))) (x:a) (s:S) =>
        iter ((internalize f) >>> (pure iso)) (s, x)).
  Defined.

  Global Instance Proper_Iter_stateT : forall a b, @Proper (Kleisli (stateT S m) a (a + b) -> (Kleisli (stateT S m) a b)) (eq2 ==> eq2) iter.
  Proof.
    destruct Cm.
    repeat red.
    intros a b x y H a0 s.
    rewrite prod_rel_eq.
    apply iterative_proper_iter.
    repeat red.
    destruct a1.
    cbn.
    apply Proper_bind.
    - unfold internalize. cbn. (specialize (H a1 s0)). rewrite prod_rel_eq in H. apply H.
    - repeat red. destruct a2 as [s' [x1|y1]]; reflexivity.
  Qed.

  Global Instance IterUnfold_stateT : IterUnfold (Kleisli (stateT S m)) sum.
  Proof.
  destruct Cm.
  unfold IterUnfold.
  intros a b f.
  repeat red.
  intros a0 s.
  unfold cat, Cat_Kleisli.
  unfold iter, Iter_stateT.
  rewrite iterative_unfold.  (* SAZ: why isn't iter_unfold exposed here? *)
  unfold cat, Cat_Kleisli.
  simpl.
  rewrite bind_bind. rewrite prod_rel_eq.
  apply Proper_bind.
  + reflexivity.
  + repeat red. destruct a1 as [s' [x | y]]; simpl.
    * unfold pure. rewrite bind_ret_l.
      reflexivity.
    * unfold pure. rewrite bind_ret_l.
      reflexivity.
  Qed.

  Global Instance IterNatural_stateT : IterNatural (Kleisli (stateT S m)) sum.
  Proof.
    destruct Cm.
    unfold IterNatural.
    intros a b c f g.
    repeat red.
    intros a0 s.
    setoid_rewrite iterative_natural. rewrite prod_rel_eq.
    apply iterative_proper_iter.
    repeat red.
    destruct a1.
    unfold cat, Cat_Kleisli.
    cbn.
    rewrite! bind_bind.
    apply Proper_bind.
    - reflexivity.
    - repeat red. destruct a2 as [s' [x | y]]; simpl.
      + unfold pure. rewrite bind_ret_l.
        cbn. unfold cat, Cat_Kleisli. cbn.
        rewrite bind_bind.
        rewrite bind_ret_l.
        rewrite bind_ret_l.
        cbn.
        unfold id_, Id_Kleisli. unfold pure. rewrite bind_ret_l. reflexivity.
      + unfold pure. rewrite bind_ret_l.
        cbn. unfold cat, Cat_Kleisli. cbn.
        rewrite bind_bind.
        apply Proper_bind.
        * reflexivity.
        * repeat red. destruct a2.
          cbn.
          rewrite bind_ret_l. reflexivity.
  Qed.

  Lemma internalize_pure_iso {a b c} (f : Kleisli (stateT S m) a (b + c)) :
    ((internalize f) >>> pure iso) ⩯ (fun sa => (bind (f (snd sa) (fst sa))) (fun sbc => ret (iso sbc))).
  Proof.
    reflexivity.
  Qed.

  Lemma eq2_to_eqm : forall a b (f g : Kleisli (stateT S m) a b) (x:a) (s:S),
      eq2 f g ->
      eqm (f x s) (g x s).
  Proof.
    intros a b f g x s H.
    specialize (H x s). rewrite prod_rel_eq in H.
    apply H.
  Qed.

  Lemma iter_dinatural_helper:
    forall (a b c : Type) (f : Kleisli (stateT S m) a (b + c)) (g : Kleisli (stateT S m) b (a + c)),
      internalize (f >>> case_ g inr_) >>> pure iso ⩯ internalize f >>> pure iso >>> case_ (internalize g >>> pure iso) inr_.
  Proof.
    destruct Cm.
    intros a b c f g.
    repeat red.
    destruct a0.
    unfold cat, Cat_Kleisli, internalize.
    cbn.
    repeat rewrite bind_bind.
    apply Proper_bind.
    - reflexivity.
    - repeat red.
      destruct a1 as [s' [x | y]].
      + unfold pure.
        rewrite bind_ret_l.
        unfold case_, Case_Kleisli, Function.case_sum.
        reflexivity.
      + unfold pure. rewrite bind_ret_l.
        unfold case_, Case_Kleisli, Function.case_sum.
          cbn.
          rewrite bind_ret_l. reflexivity.
  Qed.


  Global Instance IterDinatural_stateT : IterDinatural (Kleisli (stateT S m)) sum.
  Proof.
    destruct Cm.
    unfold IterDinatural.
    repeat red.
    intros a b c f g a0 a1.
    unfold iter, Iter_stateT.
    eapply transitivity. rewrite prod_rel_eq.
    eapply iterative_proper_iter.
    apply iter_dinatural_helper.
    rewrite iterative_dinatural.
    cbn.
    unfold cat, Cat_Kleisli.
    rewrite bind_bind.
    unfold internalize. cbn. rewrite prod_rel_eq.
    apply Proper_bind.
    - reflexivity.
    - repeat red.
      destruct a2 as [s [x | y]].
      + unfold pure.
        rewrite bind_ret_l.
        cbn.
        eapply iterative_proper_iter.
        repeat red.
        destruct a2.
        cbn. rewrite! bind_bind.
        apply Proper_bind.
        * reflexivity.
        * repeat red.
          destruct a2 as [s' [x' | y]].
          ** cbn.  rewrite bind_ret_l. unfold case_, Case_Kleisli, Function.case_sum.
             reflexivity.
          ** cbn.  rewrite bind_ret_l. unfold case_, Case_Kleisli, Function.case_sum.
             rewrite bind_ret_l. reflexivity.
      + unfold pure.
        rewrite bind_ret_l.
        cbn.
        reflexivity.
    Qed.


  Global Instance IterCodiagonal_stateT : IterCodiagonal (Kleisli (stateT S m)) sum.
  Proof.
    destruct Cm.
    unfold IterCodiagonal.
    intros a b f.
    unfold iter, Iter_stateT.
    repeat red.
    intros.
    eapply transitivity. rewrite prod_rel_eq.
    eapply iterative_proper_iter.
    eapply Proper_cat_Kleisli.

    assert (internalize (fun (x:a) (s:S) => iter (internalize f >>> pure iso) (s, x))
                       ⩯
                       iter (internalize f >>> pure iso)).
    { repeat red.
      intros a2.
      destruct a2.
      unfold internalize.
      cbn.  reflexivity.
    }
   apply H.
   reflexivity.
   eapply transitivity. rewrite prod_rel_eq.

   eapply iterative_proper_iter.
   apply iterative_natural.
   rewrite iterative_codiagonal. rewrite prod_rel_eq.
   eapply iterative_proper_iter.
   rewrite internalize_cat.
   (* SAZ This proof can probably use less unfolding *)
   repeat red. intros a2.
   destruct a2.
   unfold cat, Cat_Kleisli. cbn.
   repeat rewrite bind_bind.
   unfold internalize, pure.
   cbn.
   apply Proper_bind.
    - reflexivity.
    - repeat red.
      intros a3.
      destruct a3 as [s' [x | [y | z]]].
      + rewrite bind_ret_l.
        cbn. unfold id_, Id_Kleisli, pure.
        rewrite bind_ret_l.
        unfold cat, Cat_Kleisli.
        rewrite bind_bind.
        rewrite bind_ret_l.
        cbn.  unfold inl_, Inl_Kleisli, pure.
        rewrite bind_ret_l. reflexivity.
      + rewrite bind_ret_l.
        cbn.
        rewrite bind_ret_l.
        unfold cat, Cat_Kleisli.
        rewrite bind_bind, bind_ret_l. cbn.
        unfold inr_, Inr_Kleisli, pure.
        rewrite bind_ret_l. reflexivity.
      + rewrite bind_ret_l.
        cbn.
        rewrite bind_ret_l.
        unfold cat, Cat_Kleisli.
        rewrite bind_bind, bind_ret_l. cbn.
        unfold inr_, Inr_Kleisli, pure.
        rewrite bind_ret_l.
        reflexivity.
  Qed.

  Global Instance Iterative_stateT : Iterative (Kleisli (stateT S m)) sum.
  Proof.
  constructor;
  typeclasses eauto.
  Qed.

End State.
