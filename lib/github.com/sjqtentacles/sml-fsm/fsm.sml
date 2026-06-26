structure FSM :> FSM =
struct
  (* current state, transition function, declared states, and visited history
     (oldest first, including the initial state). *)
  type ('s, 'e) t =
    { cur : 's, trans : 's -> 'e -> 's option, decl : 's list, hist : 's list }

  fun make decl init transition =
    { cur = init, trans = transition, decl = decl, hist = [init] }

  fun current ({ cur, ... } : (''s, 'e) t) = cur

  fun send ({ cur, trans, decl, hist } : (''s, 'e) t) ev =
    case trans cur ev of
        SOME st' => { cur = st', trans = trans, decl = decl, hist = hist @ [st'] }
      | NONE     => { cur = cur, trans = trans, decl = decl, hist = hist }

  fun inState ({ cur, ... } : (''s, 'e) t) other = cur = other

  fun canSend ({ cur, trans, ... } : (''s, 'e) t) ev =
    case trans cur ev of SOME _ => true | NONE => false

  fun states ({ decl, ... } : (''s, 'e) t) = decl

  fun sendAll m evs = List.foldl (fn (e, acc) => send acc e) m evs

  fun history ({ hist, ... } : (''s, 'e) t) = hist

  fun toDot show ({ cur, decl, ... } : (''s, 'e) t) =
    let
      fun nodeLine s =
        let val label = show s
            val attrs = if s = cur then " [peripheries=2]" else ""
        in "  \"" ^ label ^ "\"" ^ attrs ^ ";" end
      val body = String.concatWith "\n" (List.map nodeLine decl)
    in "digraph fsm {\n" ^ body ^ "\n}" end
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
    | Parallel of int * 'ctx tree list
    | Succeeder of 'ctx tree
    | Failer of 'ctx tree
    | RepeatUntilSuccess of int * 'ctx tree

  fun action f = Action f
  fun condition p = Condition p
  fun sequence ts = Seq ts
  fun selector ts = Sel ts
  fun invert t = Invert t
  fun repeat n t = Repeat (n, t)
  fun parallel n ts = Parallel (n, ts)
  fun succeeder t = Succeeder t
  fun failer t = Failer t
  fun repeatUntilSuccess n t = RepeatUntilSuccess (n, t)

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
                     | other   => other)
          in go ts end
      | Sel ts =>
          let
            fun go [] = Failure
              | go (t :: rest) =
                  (case tick t ctx of
                       Failure => go rest
                     | other   => other)
          in go ts end
      | Invert t =>
          (case tick t ctx of
               Success => Failure
             | Failure => Success
             | Running => Running)
      | Repeat (n, t) =>
          let
            fun go 0 = Success
              | go k =
                  (case tick t ctx of
                       Failure => Failure
                     | _       => go (k - 1))
          in if n <= 0 then Success else go n end
      | Parallel (n, ts) =>
          let
            val results = List.map (fn t => tick t ctx) ts
            val succ = List.length (List.filter (fn r => r = Success) results)
            val anyRunning = List.exists (fn r => r = Running) results
          in
            if succ >= n then Success
            else if anyRunning then Running
            else Failure
          end
      | Succeeder t =>
          (case tick t ctx of Running => Running | _ => Success)
      | Failer t =>
          (case tick t ctx of Running => Running | _ => Failure)
      | RepeatUntilSuccess (n, t) =>
          let
            fun go 0 = Failure
              | go k =
                  (case tick t ctx of
                       Success => Success
                     | Running => Running
                     | Failure => go (k - 1))
          in if n <= 0 then Failure else go n end
end
