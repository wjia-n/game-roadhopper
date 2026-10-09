# Road Hopper — RULES.md

_The authoritative source of truth for Road Hopper gameplay. If the implementation
conflicts with this document, fix the implementation._

## 1. Objective
Guide the hopper from the start bank (bottom row) to one of the 5 home slots on
the far bank (top row). Fill **all 5 home slots** to clear the level. Score as many
points as possible before the game ends.

## 2. Setup
- Board: 13 columns × 13 rows.
- Row 12: start bank (safe). Row 6: middle bank (safe). Row 0: home bank.
- Rows 7–11: **road** lanes with moving cars (kill on touch).
- Rows 1–5: **river** lanes with moving logs (safe platforms) and turtles
  (safe platforms, but some dive).
- Home slots on row 0 at columns 1, 3, 6, 9, 11 (5 slots — the classic 5-slot
  layout fits a 13-wide board).
- Classic / Endless modes: 3 lives. Score Attack: unlimited frogs, deaths cost points.
- Timer: Classic — per-attempt countdown (Stroll 75s / Street 60s / Rush 45s).
  Score Attack — 90s total. Endless — no timer.
- Difficulty tiers scale lane speed and item density:
  Stroll ×0.75 speed, Street ×1.0, Rush ×1.35 speed + extra cars + more divers.

## 3. Turn order
Real-time game — there are no turns. The player may hop at any time while the
hopper is alive and the game is not paused.

## 4. Legal moves
- Hop exactly one cell up, down, left, or right.
- Hops may be issued via swipe, tap-to-hop, or the on-screen D-pad.
- While riding a log/turtle the hopper drifts with it automatically.
- A hop that lands on the home row (row 0) on a home column claims that home.

## 5. Illegal moves
- Hopping beyond the board edge is rejected (bump feedback, no move, no penalty).
- Hops are ignored while the hopper is dying, celebrating, or the game is over
  or paused.
- Hops faster than the hop cooldown (0.12s) are ignored (prevents double-fire).

## 6. Captures
Not applicable — there are no captures. Contact with a car kills the hopper;
falling in the river without a platform kills the hopper.

## 7. Special rules
- **Riding:** standing on a log/turtle moves the hopper with the platform's
  speed and direction.
- **Swept away:** riding a platform off the left/right board edge kills the hopper.
- **Diving turtles:** turtle lanes marked as divers periodically submerge for
  ~1.4s. A hopper standing on a diving turtle when it submerges drowns.
- **Home claim:** landing on row 0 on an *empty* home column claims it (+200).
- **Blocked home:** landing on row 0 on a non-home column, or on an already
  filled home slot, kills the hopper ("No home there!").
- **Level clear (Classic):** filling all 5 homes clears the level: +1000,
  homes reset, lane speeds increase, new attempt starts from the bottom.
- **Endless:** each claimed home refills all slots after a short celebration and
  speeds lanes up; the run continues until lives run out.
- **Time bonus (Classic):** claiming a home adds +10 per remaining second.

## 8. Scoring
- +10 for every hop that moves to a higher row (forward progress only).
- +200 per home claimed.
- +10 × seconds remaining as a time bonus per home (Classic only).
- +1000 per level cleared (Classic only).
- Score Attack death: −25 points (floor 0), instant respawn.
- Best scores are stored per mode (Classic / Endless / Score Attack).

## 9. Winning conditions
- **Classic:** there is no final win — clear levels and chase the best score.
  The run ends when all 3 lives are lost.
- **Endless:** the run ends when all 3 lives are lost; highest score wins.
- **Score Attack:** the run ends when the 90s clock hits zero; highest score wins.

## 10. Draw conditions
Not applicable — single-player arcade game.

## 11. AI strategy
Not applicable — no opponents or bots. Difficulty tiers (Stroll / Street / Rush)
provide the progression curve via lane speed and density.

## 12. Edge cases
- Hopper rides a platform exactly to the board edge: dies ("Swept away!").
- Hopper stands on a turtle the moment it dives: dies ("The turtle dove!").
- Timer expires mid-hop: the hop completes, then the hopper dies ("Out of time!").
- Two homes claimed nearly simultaneously: impossible — only one hopper exists.
- Pause during death animation: the death timer freezes and resumes on unpause.
- App backgrounded mid-run: the engine auto-pauses; timers freeze; resume is exact.
- Score Attack clock hits 0 during a home celebration: celebration finishes,
  then the game ends and the home points count.
- All lives lost during celebration: celebration finishes, then game over.

## 13. Test cases
1. Hop onto a road lane with no car overlap → hopper survives.
2. Hop into a car's bounding box → death "Squashed!", lives −1, respawn at bottom.
3. Hop onto a log → hopper rides it at the lane's speed/direction.
4. Ride a log off the board edge → death "Swept away!".
5. Stand on a diving turtle through a dive → death "The turtle dove!".
6. Hop onto river water with no platform → death "Splash!".
7. Reach row 0 on an empty home column → home claimed, +200 (+ time bonus).
8. Reach row 0 on a non-home column → death "No home there!".
9. Reach row 0 on an already-filled home → death "No home there!".
10. Fill all 5 homes in Classic → +1000, level +1, lanes speed up, homes reset.
11. Timer expires → death "Out of time!", lives −1.
12. Lose all 3 lives → game over screen with final score and best.
13. Score Attack: clock reaches 0 → game over; deaths cost 25 points, no lives.
14. Pause freezes timers and lane motion; resume continues exactly.
15. Hop against the board edge → bump feedback, position unchanged.
16. Watchdog: killing the engine's timers externally is recovered within 2s.
17. Endless: claiming a home refills all slots, speeds lanes up, +200 only.
