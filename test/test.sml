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
    in
      Harness.run ()
    end
end
