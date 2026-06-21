structure FSM :> FSM =
struct
  (* current state plus the transition function *)
  type ('s, 'e) t = 's * ('s -> 'e -> 's option)

  fun make _ init transition = (init, transition)

  fun current (st, _) = st

  fun send (st, transition) ev =
    case transition st ev of
        SOME st' => (st', transition)
      | NONE     => (st, transition)

  fun inState (st, _) other = st = other
end

structure BehaviorTree :> BEHAVIOR_TREE =
struct
  datatype result = Success | Failure | Running

  datatype 'ctx tree =
      Action of 'ctx -> result
    | Condition of 'ctx -> bool
    | Seq of 'ctx tree list
    | Sel of 'ctx tree list
    | Invert of 'ctx tree
    | Repeat of int * 'ctx tree

  fun action f = Action f
  fun condition p = Condition p
  fun sequence ts = Seq ts
  fun selector ts = Sel ts
  fun invert t = Invert t
  fun repeat n t = Repeat (n, t)

  fun tick tree ctx =
    case tree of
        Action f => f ctx
      | Condition p => if p ctx then Success else Failure
      | Seq ts =>
          let
            fun go [] = Success
              | go (t :: rest) =
                  (case tick t ctx of
                       Success => go rest
                     | other   => other)   (* Failure/Running short-circuits *)
          in go ts end
      | Sel ts =>
          let
            fun go [] = Failure
              | go (t :: rest) =
                  (case tick t ctx of
                       Failure => go rest
                     | other   => other)   (* Success/Running short-circuits *)
          in go ts end
      | Invert t =>
          (case tick t ctx of
               Success => Failure
             | Failure => Success
             | Running => Running)
      | Repeat (n, t) =>
          let
            (* tick t n times; first Failure returns Failure, else Success *)
            fun go 0 = Success
              | go k =
                  (case tick t ctx of
                       Failure => Failure
                     | _       => go (k - 1))
          in if n <= 0 then Success else go n end
end
