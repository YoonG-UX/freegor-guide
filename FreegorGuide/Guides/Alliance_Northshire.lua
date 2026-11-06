-- Example guide: Human starting area (Northshire Valley).
-- Quest IDs and coordinates come from public game data. They match the
-- original 1.x quests and must be checked on the target server before release.

Freegor:RegisterGuide([[
guide Northshire Valley (1-6)
author Freegor community
faction Alliance
levels 1-6
next Elwynn Forest (6-10)
zone 1429, Elwynn Forest, Forêt d'Elwynn

step
  goto 48.2,42.0
  talk Deputy Willem
  accept 783 A Threat Within
step
  goto 48.9,41.6
  talk Marshal McBride
  turnin 783 A Threat Within
  accept 7 Kobold Camp Cleanup
step
  goto 48.2,42.0
  talk Deputy Willem
  accept 5261 Eagan Peltskinner
  accept 18 Brotherhood of Thieves
step
  goto 48.9,40.2
  talk Eagan Peltskinner
  turnin 5261 Eagan Peltskinner
  accept 33 Wolves Across the Border
step
  goto 47.5,35.5
  kill 10 Kobold Vermin |q 7/1
  collect 8 Tough Wolf Meat |q 33/1
  note Wolves roam all around the kobold camp.
step
  goto 48.9,40.2
  talk Eagan Peltskinner
  turnin 33 Wolves Across the Border
step
  goto 48.9,41.6
  talk Marshal McBride
  turnin 7 Kobold Camp Cleanup
  accept 15 Investigate Echo Ridge
step
  goto 54.6,45.0
  collect 12 Red Burlap Bandana |q 18/1
  note Defias Thugs are in the vineyard east of the abbey.
step
  goto 48.0,31.0
  kill 10 Kobold Worker |q 15/1
  note Kobold Workers are inside Echo Ridge Mine.
step
  goto 48.9,41.6
  talk Marshal McBride
  turnin 15 Investigate Echo Ridge
  accept 21 Skirmish at Echo Ridge
step
  goto 48.2,42.0
  talk Deputy Willem
  turnin 18 Brotherhood of Thieves
  accept 6 Bounty on Garrick Padfoot
step
  goto 48.0,31.0
  kill 12 Kobold Laborer |q 21/1
step
  goto 57.6,48.3
  collect Garrick's Head |q 6/1
  note Garrick Padfoot stands next to the shack, with two Thugs nearby.
step
  goto 48.2,42.0
  talk Deputy Willem
  turnin 6 Bounty on Garrick Padfoot
step
  goto 48.9,41.6
  talk Marshal McBride
  turnin 21 Skirmish at Echo Ridge
  accept 54 Report to Goldshire
step
  level 5
  note Kill wolves and kobolds around the valley if you are not level 5 yet.
step
  goto 42.1,65.9
  talk Marshal Dughan
  turnin 54 Report to Goldshire
]])
