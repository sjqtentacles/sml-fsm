structure Tests =
struct

  open BehaviorTree

  (* ---- FSM: traffic light ---- *)
  fun trafficTransition st ev =
    case (st, ev) of
        ("Red",    "go")   => SOME "Green"
      | ("Green",  "slow") => SOME "Yellow"
      | ("Yellow", "stop") => SOME "Red"
      | _                  => NONE

  fun traffic () = FSM.make ["Red", "Green", "Yellow"] "Red" trafficTransition

  (* ---- FSM: door ---- *)
  fun doorTransition st ev =
    case (st, ev) of
        ("Closed", "open")  => SOME "Open"
      | ("Open",   "close") => SOME "Closed"
      | ("Locked", "open")  => NONE   (* stays Locked *)
      | _                   => NONE

  fun door init = FSM.make ["Closed", "Open", "Locked"] init doorTransition

  fun run () =
    let
      val () = Harness.reset ()

      (* Section 1: FSM traffic light *)
      val () = Harness.section "FSM traffic light"
      val t0 = traffic ()
      val () = Harness.checkString "initial state" ("Red", FSM.current t0)
      val t1 = FSM.send t0 "go"
      val () = Harness.checkString "Red + go -> Green" ("Green", FSM.current t1)
      val t2 = FSM.send t1 "slow"
      val () = Harness.checkString "Green + slow -> Yellow" ("Yellow", FSM.current t2)
      val t3 = FSM.send t2 "stop"
      val () = Harness.checkString "Yellow + stop -> Red" ("Red", FSM.current t3)
      val tWrong = FSM.send t0 "stop"
      val () = Harness.checkString "wrong event keeps state" ("Red", FSM.current tWrong)
      val () = Harness.checkBool "inState Red true" (true, FSM.inState t0 "Red")
      val () = Harness.checkBool "inState Green false" (false, FSM.inState t0 "Green")

      (* Section 2: FSM door *)
      val () = Harness.section "FSM door"
      val dClosed = door "Closed"
      val dOpen = FSM.send dClosed "open"
      val () = Harness.checkString "Closed + open -> Open" ("Open", FSM.current dOpen)
      val dClosedAgain = FSM.send dOpen "close"
      val () = Harness.checkString "Open + close -> Closed" ("Closed", FSM.current dClosedAgain)
      val dLocked = door "Locked"
      val dStillLocked = FSM.send dLocked "open"
      val () = Harness.checkString "Locked + open stays Locked" ("Locked", FSM.current dStillLocked)

      (* Section 3: BT sequence *)
      val () = Harness.section "BT sequence"
      val succ = action (fn _ => Success)
      val fail = action (fn _ => Failure)
      val seqOk = sequence [succ, succ]
      val () = Harness.checkBool "seq [success,success] -> Success"
                 (true, tick seqOk () = Success)
      val seqFail = sequence [succ, fail]
      val () = Harness.checkBool "seq [success,failure] -> Failure"
                 (true, tick seqFail () = Failure)

      (* Section 4: BT selector *)
      val () = Harness.section "BT selector"
      val selOk = selector [fail, succ]
      val () = Harness.checkBool "sel [failure,success] -> Success"
                 (true, tick selOk () = Success)
      val selFail = selector [fail, fail]
      val () = Harness.checkBool "sel [failure,failure] -> Failure"
                 (true, tick selFail () = Failure)

      (* Section 5: BT invert and repeat *)
      val () = Harness.section "BT invert and repeat"
      val inv = invert succ
      val () = Harness.checkBool "invert Success -> Failure"
                 (true, tick inv () = Failure)
      val counter = ref 0
      val countAction = action (fn (r: int ref) => (r := !r + 1; Success))
      val rep = repeat 3 countAction
      val repResult = tick rep counter
      val () = Harness.checkInt "repeat 3 increments 3" (3, !counter)
      val () = Harness.checkBool "repeat 3 -> Success" (true, repResult = Success)

      (* Section 6: BT patrol/attack *)
      val () = Harness.section "BT patrol attack"
      fun enemyInRange (ctx: {inRange: bool, log: string ref}) = #inRange ctx
      val attack = action (fn (ctx: {inRange: bool, log: string ref}) =>
                     (#log ctx := "attack"; Success))
      val patrol = action (fn (ctx: {inRange: bool, log: string ref}) =>
                     (#log ctx := "patrol"; Success))
      val aiTree = selector [ sequence [condition enemyInRange, attack], patrol ]

      val logA = ref ""
      val rA = tick aiTree {inRange = true, log = logA}
      val () = Harness.checkBool "enemy in range -> Success" (true, rA = Success)
      val () = Harness.checkString "enemy in range -> attack" ("attack", !logA)

      val logB = ref ""
      val rB = tick aiTree {inRange = false, log = logB}
      val () = Harness.checkBool "enemy not in range -> Success" (true, rB = Success)
      val () = Harness.checkString "enemy not in range -> patrol" ("patrol", !logB)

      (* Section 7: FSM new API *)
      val () = Harness.section "FSM canSend / states / sendAll / history / toDot"
      val tc = traffic ()
      val () = Harness.checkBool "canSend go true" (true, FSM.canSend tc "go")
      val () = Harness.checkBool "canSend stop false" (false, FSM.canSend tc "stop")
      val () = Harness.checkStringList "states declared"
                 (["Red","Green","Yellow"], FSM.states tc)
      val tAll = FSM.sendAll tc ["go","slow","stop"]
      val () = Harness.checkString "sendAll cycles back to Red" ("Red", FSM.current tAll)
      val () = Harness.checkStringList "history records path"
                 (["Red","Green","Yellow","Red"], FSM.history tAll)
      val tBad = FSM.sendAll tc ["stop","stop"]
      val () = Harness.checkStringList "history ignores no-op events"
                 (["Red"], FSM.history tBad)
      val dot = FSM.toDot (fn s => s) tc
      val () = Harness.checkBool "dot contains Red" (true, String.isSubstring "Red" dot)
      val () = Harness.checkBool "dot marks current"
                 (true, String.isSubstring "peripheries=2" dot)
      val () = Harness.checkBool "dot is digraph" (true, String.isPrefix "digraph" dot)

      (* Section 8: BT parallel / succeeder / failer / repeatUntilSuccess *)
      val () = Harness.section "BT parallel and decorators"
      val () = Harness.checkBool "parallel 2 of [s,s,f] -> Success"
                 (true, tick (parallel 2 [succ, succ, fail]) () = Success)
      val () = Harness.checkBool "parallel 3 of [s,s,f] -> Failure"
                 (true, tick (parallel 3 [succ, succ, fail]) () = Failure)
      val () = Harness.checkBool "parallel 0 -> Success"
                 (true, tick (parallel 0 [fail, fail]) () = Success)
      val () = Harness.checkBool "succeeder fail -> Success"
                 (true, tick (succeeder fail) () = Success)
      val () = Harness.checkBool "failer succ -> Failure"
                 (true, tick (failer succ) () = Failure)
      val running = action (fn _ => Running)
      val () = Harness.checkBool "succeeder running -> Running"
                 (true, tick (succeeder running) () = Running)
      (* repeatUntilSuccess: action that fails twice then succeeds *)
      val attempts = ref 0
      val failTwice = action (fn (r: int ref) =>
                        (r := !r + 1; if !r >= 3 then Success else Failure))
      val () = Harness.checkBool "repeatUntilSuccess 5 eventually Success"
                 (true, tick (repeatUntilSuccess 5 failTwice) attempts = Success)
      val attempts2 = ref 0
      val alwaysFail = action (fn (r: int ref) => (r := !r + 1; Failure))
      val () = Harness.checkBool "repeatUntilSuccess 2 of alwaysFail -> Failure"
                 (true, tick (repeatUntilSuccess 2 alwaysFail) attempts2 = Failure)

      (* Section 9: FSM makeTable + introspection *)
      val () = Harness.section "FSM makeTable / toDotFull / reachableStates / validate"
      val tbl = FSM.makeTable ["Red","Green","Yellow"] "Red"
                  [("Red","go","Green"), ("Green","slow","Yellow"), ("Yellow","stop","Red")]
      val () = Harness.checkString "table initial" ("Red", FSM.current tbl)
      val () = Harness.checkString "table Red+go" ("Green", FSM.current (FSM.send tbl "go"))
      val () = Harness.checkString "table cycle"
                 ("Red", FSM.current (FSM.sendAll tbl ["go","slow","stop"]))
      val fullDot = FSM.toDotFull (fn s => s) (fn e => e) tbl
      val () = Harness.checkBool "toDotFull has edge label" (true, String.isSubstring "label=\"go\"" fullDot)
      val () = Harness.checkBool "toDotFull has arrow" (true, String.isSubstring "->" fullDot)
      val () = Harness.checkStringList "reachableStates from Red"
                 (["Red","Green","Yellow"], FSM.reachableStates tbl)
      val () = Harness.checkBool "validate clean table" (true, FSM.validate tbl = [])
      val badTbl = FSM.makeTable ["A"] "A" [("A","x","B")]  (* B undeclared *)
      val () = Harness.checkBool "validate flags undeclared" (true, FSM.validate badTbl <> [])
      val () = Harness.checkBool "reachableStates function machine = [current]"
                 (true, FSM.reachableStates (FSM.makeTable ["A"] "A" []) = ["A"])

      (* Section 10: FSM reset / rewind / history limit *)
      val () = Harness.section "FSM reset / rewind / setHistoryLimit"
      val walked = FSM.sendAll (traffic ()) ["go","slow"]   (* Red,Green,Yellow *)
      val () = Harness.checkString "walked current" ("Yellow", FSM.current walked)
      val resetM = FSM.reset walked
      val () = Harness.checkString "reset back to initial" ("Red", FSM.current resetM)
      val () = Harness.checkStringList "reset history singleton" (["Red"], FSM.history resetM)
      val rw = valOf (FSM.rewind walked)
      val () = Harness.checkString "rewind to Green" ("Green", FSM.current rw)
      val () = Harness.checkStringList "rewind history" (["Red","Green"], FSM.history rw)
      val () = Harness.checkBool "rewind at initial -> NONE"
                 (true, not (Option.isSome (FSM.rewind (traffic ()))))
      val limited = FSM.sendAll (FSM.setHistoryLimit (traffic ()) 2) ["go","slow"]
      val () = Harness.checkStringList "history limited to 2" (["Green","Yellow"], FSM.history limited)

      (* Section 11: FSM accepts / run *)
      val () = Harness.section "FSM accepts / run"
      val () = Harness.checkBool "accepts current Yellow"
                 (true, FSM.accepts walked ["Yellow"])
      val () = Harness.checkBool "accepts rejects"
                 (false, FSM.accepts walked ["Red"])
      val () = Harness.checkBool "run accepting word"
                 (true, FSM.run (traffic ()) ["go","slow","stop"] ["Red"])
      val () = Harness.checkBool "run non-accepting word"
                 (false, FSM.run (traffic ()) ["go"] ["Red"])

      (* Section 12: MealyFSM *)
      val () = Harness.section "MealyFSM"
      (* a vending toggle: each "coin" flips state and emits a message *)
      fun mtrans st ev =
        case (st, ev) of
            ("Idle", "coin") => SOME ("Paid", "thanks")
          | ("Paid", "dispense") => SOME ("Idle", "drink")
          | _ => NONE
      val mealy = MealyFSM.make ["Idle","Paid"] "Idle" mtrans
      val (m1, o1) = MealyFSM.step mealy "coin"
      val () = Harness.checkString "mealy step state" ("Paid", MealyFSM.current m1)
      val () = Harness.checkBool "mealy step output"
                 (true, o1 = SOME "thanks")
      val (_, o2) = MealyFSM.step mealy "dispense"  (* no transition from Idle *)
      val () = Harness.checkBool "mealy no transition -> NONE output"
                 (true, not (Option.isSome o2))
      val () = Harness.checkStringList "mealy run outputs"
                 (["thanks","drink"], MealyFSM.outputs mealy ["coin","dispense"])
      val () = Harness.checkStringList "mealy states" (["Idle","Paid"], MealyFSM.states mealy)

      (* Section 13: BT cooldown / timeout *)
      val () = Harness.section "BT cooldown / timeout"
      val getT = fn (ctx: {now: real}) => #now ctx
      val cd = cooldown getT 0.0 5.0 (action (fn _ => Success))
      val () = Harness.checkBool "cooldown elapsed -> child ticks"
                 (true, tick cd {now = 10.0} = Success)
      val () = Harness.checkBool "cooldown too soon -> Failure"
                 (true, tick cd {now = 3.0} = Failure)
      val to = timeout getT 0.0 5.0 (action (fn _ => Success))
      val () = Harness.checkBool "timeout within limit -> child ticks"
                 (true, tick to {now = 3.0} = Success)
      val () = Harness.checkBool "timeout exceeded -> Failure"
                 (true, tick to {now = 6.0} = Failure)
    in
      Harness.run ()
    end
end
