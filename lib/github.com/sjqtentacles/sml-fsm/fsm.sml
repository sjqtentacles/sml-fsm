structure FSM :> FSM =
struct
  (* current state, transition function, declared states, visited history
     (oldest first, including the initial state), an optional transition table
     (present only for makeTable machines, enabling introspection), and a
     history limit (<= 0 means unbounded). The table edges are stored as
     (from, event, to) but represented with the event rendered lazily; since we
     cannot store the equality event generically alongside a function-only
     machine, we keep an opaque per-machine table as a list of triples in the
     state's own type plus an event-projection closure used by toDotFull. *)
  type ('s, 'e) t =
    { cur : 's
    , trans : 's -> 'e -> 's option
    , decl : 's list
    , hist : 's list
    , limit : int
    , edges : ('s * 'e * 's) list option }

  fun trimHist limit hist =
    if limit <= 0 then hist
    else
      let val n = List.length hist
      in if n <= limit then hist
         else List.drop (hist, n - limit)
      end

  fun make decl init transition =
    { cur = init, trans = transition, decl = decl, hist = [init]
    , limit = 0, edges = NONE }

  fun makeTable decl init triples =
    let
      fun transition s e =
        let
          fun look [] = NONE
            | look ((f, ev, t) :: rest) =
                if f = s andalso ev = e then SOME t else look rest
        in look triples end
    in
      { cur = init, trans = transition, decl = decl, hist = [init]
      , limit = 0, edges = SOME triples }
    end

  fun current ({ cur, ... } : (''s, 'e) t) = cur

  fun send ({ cur, trans, decl, hist, limit, edges } : (''s, 'e) t) ev =
    case trans cur ev of
        SOME st' =>
          { cur = st', trans = trans, decl = decl
          , hist = trimHist limit (hist @ [st']), limit = limit, edges = edges }
      | NONE => { cur = cur, trans = trans, decl = decl, hist = hist
                , limit = limit, edges = edges }

  fun inState ({ cur, ... } : (''s, 'e) t) other = cur = other

  fun canSend ({ cur, trans, ... } : (''s, 'e) t) ev =
    case trans cur ev of SOME _ => true | NONE => false

  fun states ({ decl, ... } : (''s, 'e) t) = decl

  fun sendAll m evs = List.foldl (fn (e, acc) => send acc e) m evs

  fun history ({ hist, ... } : (''s, 'e) t) = hist

  fun setHistoryLimit ({ cur, trans, decl, hist, edges, ... } : (''s, 'e) t) n =
    { cur = cur, trans = trans, decl = decl
    , hist = trimHist n hist, limit = n, edges = edges }

  fun reset ({ cur = _, trans, decl, hist, limit, edges } : (''s, 'e) t) =
    let val init = case hist of h :: _ => h | [] => raise Empty
    in { cur = init, trans = trans, decl = decl, hist = [init]
       , limit = limit, edges = edges } end

  fun rewind ({ trans, decl, hist, limit, edges, ... } : (''s, 'e) t) =
    case List.rev hist of
        _ :: (prev :: _) =>
          let val newHist = List.rev (List.tl (List.rev hist))
          in SOME { cur = prev, trans = trans, decl = decl
                  , hist = newHist, limit = limit, edges = edges } end
      | _ => NONE

  fun accepts ({ cur, ... } : (''s, 'e) t) accepting =
    List.exists (fn s => s = cur) accepting

  fun run m evs accepting = accepts (sendAll (reset m) evs) accepting

  fun toDot show ({ cur, decl, ... } : (''s, 'e) t) =
    let
      fun nodeLine s =
        let val label = show s
            val attrs = if s = cur then " [peripheries=2]" else ""
        in "  \"" ^ label ^ "\"" ^ attrs ^ ";" end
      val body = String.concatWith "\n" (List.map nodeLine decl)
    in "digraph fsm {\n" ^ body ^ "\n}" end

  fun toDotFull showS showE ({ cur, decl, edges, ... } : (''s, ''e) t) =
    let
      fun nodeLine s =
        let val label = showS s
            val attrs = if s = cur then " [peripheries=2]" else ""
        in "  \"" ^ label ^ "\"" ^ attrs ^ ";" end
      val nodeBody = String.concatWith "\n" (List.map nodeLine decl)
      val edgeBody =
        case edges of
            NONE => ""
          | SOME es =>
              String.concatWith "\n"
                (List.map
                   (fn (f, e, t) =>
                      "  \"" ^ showS f ^ "\" -> \"" ^ showS t
                      ^ "\" [label=\"" ^ showE e ^ "\"];")
                   es)
      val sep = if edgeBody = "" then "" else "\n"
    in "digraph fsm {\n" ^ nodeBody ^ sep ^ edgeBody ^ "\n}" end

  fun reachableStates ({ cur, edges, ... } : (''s, ''e) t) =
    case edges of
        NONE => [cur]
      | SOME es =>
          let
            fun succs s =
              List.mapPartial (fn (f, _, t) => if f = s then SOME t else NONE) es
            fun mem x xs = List.exists (fn y => y = x) xs
            fun bfs [] visited = List.rev visited
              | bfs (s :: queue) visited =
                  if mem s visited then bfs queue visited
                  else bfs (queue @ succs s) (s :: visited)
          in bfs [cur] [] end

  fun validate ({ decl, edges, ... } : (''s, ''e) t) =
    case edges of
        NONE => []
      | SOME es =>
          let
            fun declared s = List.exists (fn d => d = s) decl
            fun chk (f, _, t) acc =
              let
                val acc = if declared f then acc
                          else ("undeclared source state in edge") :: acc
                val acc = if declared t then acc
                          else ("undeclared target state in edge") :: acc
              in acc end
          in List.rev (List.foldl (fn (e, acc) => chk e acc) [] es) end
end

structure MealyFSM :> MEALY_FSM =
struct
  type ('s, 'e, 'out) t =
    { cur : 's, trans : 's -> 'e -> ('s * 'out) option, decl : 's list }

  fun make decl init transition = { cur = init, trans = transition, decl = decl }

  fun current ({ cur, ... } : (''s, 'e, 'out) t) = cur

  fun step ({ cur, trans, decl } : (''s, 'e, 'out) t) ev =
    case trans cur ev of
        SOME (st', out) => ({ cur = st', trans = trans, decl = decl }, SOME out)
      | NONE => ({ cur = cur, trans = trans, decl = decl }, NONE)

  fun run m evs =
    let
      fun go acc outs [] = (acc, List.rev outs)
        | go acc outs (e :: rest) =
            let val (acc', outOpt) = step acc e
            in case outOpt of
                   SOME out => go acc' (out :: outs) rest
                 | NONE => go acc' outs rest
            end
    in go m [] evs end

  fun outputs m evs = #2 (run m evs)

  fun states ({ decl, ... } : (''s, 'e, 'out) t) = decl
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
    | Cooldown of ('ctx -> real) * real * real * 'ctx tree
    | Timeout of ('ctx -> real) * real * real * 'ctx tree

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
  fun cooldown getTime lastFire period t = Cooldown (getTime, lastFire, period, t)
  fun timeout getTime startTime limit t = Timeout (getTime, startTime, limit, t)

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
      | Cooldown (getTime, lastFire, period, t) =>
          if getTime ctx - lastFire >= period then tick t ctx else Failure
      | Timeout (getTime, startTime, limit, t) =>
          if getTime ctx - startTime > limit then Failure else tick t ctx
end
