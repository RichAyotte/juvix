#### Mendler

Mendler style F-algebras have the unique advantage of being strongly normalising for positive and negative inductive datatypes without sacrificing constant time destructors or a linear-space representation. This is achieved through the Mendler representation of the algebraic datatype being a catamorphism with an explicit recursive deconstructor. The strongly normalising property of the Mendler style algebra is only achieved in the absence of deconstructors that are not the internal catamorphism, which shall be referred to as external deconstructors (todo :: find source).

Let us first explore the core of the encoding by first assuming we have access to a non inductive algebraic data type, then strip these assumptions until just base lambda calculus is left.

The first example we will explore is the natural numbers. Recall that the natural numbers can be defined as such

```
-- Normal Haskell way of defining Nat
data Nat = Z
         | S Nat

```

Now, let us strip the recursive nature of this data type using pseudo-Haskell syntax
```
data N r = Z
         | S r

let in = \r. \f. f (\d. d f) r

type AlgebraM (f :: * → *) (x :: *) = forall (r :: *). (r → x) → (f r) → x

type FixM f = forall x. AlgebraM f x → x

type Nat = FixM N

let zero = in Z : Nat
let succ = \n. in (S n) : Nat → Nat
```

The definitions above that are in need of serious attention are `AlgebraM` and `in`.

`AlgebraM` states that for any F-algebra `f` and result `x`, if we have a function, say `g`, from any `r` to `x` and the F-algebra is over `r`, then we can receive a `x` back through `g`.

The interesting aspect here is that `g` does not work over the outer algebraic structure, but instead the nested data inside of it. In our above example this would be the `r` in the definition of ℕ. This inner recursion on `r` without any other external deconstructors is what allows this encoding to be strongly normalising.

The form that allows us to inhabit `AlgebraM` is the `in` abstraction. To better understand how `in` works, an example of Nat's usage and expansion to `in` would be the most informative.

```
let isEven = \rec. \n.
  case n of
  | Z   → True
  | S n → not (rec n)

let two = succ (succ zero)

two isEven — ===> True

two isEven
= (succ (succ zero))   isEven             — (1) by definition
= (in S (in S (in Z))) isEven             — (2) by definition of succ and zero
= isEven (\d. d isEven) (S (in S (in Z))) — (3) by definition of in
= case (S (in S (in Z))) of               — (4) by definition of isEven
  | Z   → True
  | S n → not ((\d. d isEven) n)
= not ((in S (in Z)) isEven)              — (5) by case expansion
```

In the above example, we can see that `two` inhibits the type FixM ℕ, meaning that the F-Algebra we are working over is `N r` for some `r`. So the algebra must take a function `r → x` and the `f r` itself. this corresponds to the `rec` and `n` in `isEven` respectively. We can see that `rec` only works with the `r` parameter which in the case of `two` is the Mendler encoded `succ zero`. By step `5` of the expansion the definition of `in` finally becomes clear in that $(λd. d f)$ shows itself to satisfy the inner recursive form.

However there is one small problem. In untyped lambda calculus we could define pred as follows:

```
let pred_alg = \rec. \n.
  case n of
  | Z   → zero
  | S n → n
```

We can see that this definition of `pred_alg` is O(1), as the call to `rec` is optional and not forced unlike other encodings. However if we were to type this using the normal Hindley-Milner type system, this does not work out. [The Cedille Cast](https://youtu.be/HqvBBf_cjDo?t=1020) talks about this fact and deals with this issue by having a O(1) cast arising from dependent intersections.

Instead we have to define a function `out` which turns a `FixM f` into a `f (FixM f)` with the additional constraint that `f` must be a functor. This is a hard constraint that type systems without dependent intersection types and O(1) heterogeneous equality must have [@cedille]. The force of using `out` in `pred_alg` makes getting the predecessor of a ℕ O(n).

Another property of this algebra is that this encoding is able to achieve linear space unlike previous encodings that took quadratic if not exponential space to achieve proof of termination and O(1) predecessor [@cedille].

Now that we have some understanding of the inductive nature of the Mendler encoding, we must also strip the ADT tags of `Z` and `S` into base lambda. We will first only consider sum types which contains at most one field, and then investigate how we can modify our representation to include product types with more fields.

```

-- D is added to be illustrative of the effect of adding another case
data Nat n = Z | S n | D n

let inl = \x. \k. \l. k x

let inr = \y. \k. \l. l y

let zero-c = inl ()
let succ-c = \c. inr (inl c)
let dup-c  = \c. inr (inr c)

let zero = in zero-c : Nat
let succ = in succ-c : Nat
let dup  = in dup-c  : Nat
```

There are many valid ways to encode sum types, however for simplicity we have chosen to create a list of cases with our use of `inl` and `inr`. So, we can view inl as `head` and `inr` as tail, thus our encoding is simply the dotted list `(zero succ . dup)` [@dotted-pair-notation]. On the term level, `inl` just applies the first abstraction `k` over the value, and inr simply applies the second abstraction `l` over the inputted value.

One obvious optimisation one can make, is simply turning this dotted list encoding into a balanced tree.

Another issue, is that this encoding can not support fields with multiple arguments, `l` or `k` are simply applied on the first argument given and no more. This can be remedied by swapping the application order of `inl` and `inr`, allowing the first argument to feed `l` or `k` the proper arguments.

```
data Nat n = Z | S n | D n N

let inl-op = \x. \k. \l. x k

let inr-op = \y. \k. \l. y l

let zero-c = inl ()
let succ-c = \c. inr (inl c)
let dup-c  = \a1. \ a2. inr (inr-op (\fun. fun a1 a2))

let zero = in zero-c : Nat
let succ = in succ-c : Nat
let dup  = in dup-c  : Nat

```

As we can also see, this enhancement only affects the last inr/inl in which the representation takes multiple arguments.

#### Scott

Scott encoding, unlike the Mendler F-Algebra, does not contain an internal catamorphism. Instead Scott encodings are laid out as a simple "case switch". We can see the general layout here for some branch $Cᵢ$ which contains $n$ pieces of data that resides in a sum type with $m$ constructors. Due to this simple "case switch" layout, the encoding takes linear space.

$((λx₁…xₙ.\, λC₁…Cᵢ…Cₘ.\, Cᵢ \, x₁…xₙ))$

Since the constructor simply chooses which lambda to apply to the next term, we get O(1) predecessor (or case analysis generally). However since the form is not a catamorphism there is no proof of termination in an unrestricted setting.

A concrete form of the naturals with duplication is listed below to get a concrete understanding of the encoding.

```
data Nat n = Z | S n | D n n

let rec pred Z     = Z
let rec pred S n   = n
let rec pred D x y = D (pred x) (pred y)

let zero =         \zero. \succ. \dup. zero
let succ = \x.     \zero. \succ. \dup. succ x
let dup  = \x. \y. \zero. \succ. \dup. dup x y

let rec pred =
  \nat. nat zero
            (\n. n)
            (\x. \y. D (pred x) (pred y))
```
Another important aspect to Scott encodings is that they can not be typed in `System-F` alone, but instead `System-F` extended with covariant recursive types[@scott]. Due to this, Scott encodings can be typed safely in Juvix Core.

#### Desugaring

For recursive functions that are not too restricted, transforming Mendler algebras into arbitrary recursive function takes some work. As such, the Scott encoding is currently the default encoding at the EAL* level. However, at a future date Mendler encodings will be added.
