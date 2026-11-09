# Game Design — Idle Base Battle

The design reference for stats, scaling and upgrades. Every number here lives in a
resource (`Ressources/campaign.tres`, `Ressources/Heroes/`, `Ressources/Income/`,
`Ressources/Relics/`, `Ressources/Skills/`). Change the data, then update this page.

## 1. Core loop

1. Your base (left) and the enemy base (right) face each other at the two ends of
   a lane about three screens long (2,220 px). The camera follows the front of
   the fight on its own. Drag sideways or tap the lane map in the top bar to
   look somewhere else; 3 s after you let go, the camera glides back to the
   front. Heroes leave your base and fight on their own; the enemy base sends
   monsters. No tapping.
2. **Destroy the enemy base → one stage up. Lose your base → one stage down.**
3. Gold comes from **kills** and from **income sources** (timed workers).
4. Gold buys **hero levels** and **income levels**.
5. Destroyed enemy bases drop **hero shards** → **stars** (permanent). Every
   star unlocks one bonus: for the hero, the whole team or one race (3c).
   **Gems** (from achievements and daily rewards) buy shard packs for a chosen hero.
6. **Tap a monster** to inspect it. The battle pauses while you read its stats and
   what they mean for your squad. Tap a hero portrait for the same on heroes.
7. From stage 40, **rebirth**: stage, gold, hero levels and income reset; you earn
   **souls** for permanent **relics**. Stars and relics stay.

## 2. Damage

```
hit = attack × (crit ? crit_multiplier × target crit weakness : 1)
             × race wheel (attacker beats target ? 1.5 : loses to it ? 0.75 : 1)
             × (1 − min(target defense, 75%))
```

Skills hit for `attack × skill multiplier` and use the same rules.

**Who can hit whom**
- **Ground melee** units only hit ground targets. Flyers pass over them.
- **Ranged** units hit ground and flying targets.
- **Flying** units hit ground and flying targets.
- **Area skills** (Fireball) hit everything in the area.
- **Bases** can be hit by everyone.

## 3. Hero stats

| Stat | Meaning | How it grows |
|---|---|---|
| **Attack** | Damage per hit | `base × level`, ×2 every 25 levels, star bonuses, relic Warlord's Blade +50%/level |
| **Health** | Damage it can take before falling (respawns after 4 s) | Same as attack (star bonuses, relic Iron Heart) |
| **Attack speed** | Hits per second (`1 / attack interval`) | Fixed per hero, + synergy and star bonuses; Rapid Fire skill ×2.5 for 4 s |
| **Defense** | Share of every hit blocked (cap 75%) | Fixed per hero, + synergy and star bonuses (added as points) |
| **Crit chance / damage** | Chance for a hit to deal ×crit damage | Fixed per hero, + star bonuses (chance, added as points) |
| **Range** | Gap at which it stops and attacks (melee ≈ 40, ranged ≈ 250) | Fixed per hero |
| **Layer** | Ground or flying (flyers can only be hit by shooters and flyers) | Fixed per hero |
| **Move speed** | Walking speed in px/s | Fixed per hero, + star bonuses |
| **Race** | Team bonus when 2 / 3 recruited heroes share it (3b) and its place on the race wheel (3d) | Fixed per hero |
| **Stars** | Each star unlocks one bonus for the hero, the team or a race (3c) | Shards |
| **Skill** | Auto-cast ability with its own cooldown | Scales with attack |
| **DPS** | Expected damage per second (shown, not stored) | `attack × attack speed × (1 + crit chance × (crit damage − 1))` |

Fixed stats are the hero's identity. Race synergies (3b) and star bonuses (3c)
change some of them. Gear is the planned way to change the rest later.

### Hero roster (level 1 values)

| Hero | Rarity | Race | Style | Attack | Interval | Health | Defense | Crit | Range | Speed | Cost | Skill |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Squire | Common | Human | Ground melee | 5 | 1.0 s | 60 | 20% | 5% ×2 | 36 | 165 | starts owned | Shield Bash: ×4 hit + knockback (6 s) |
| Archer | Common | Elf | Ground ranged | 7 | 1.1 s | 35 | 0% | 12% ×2 | 230 | 150 | 50 | Arrow Volley: ×1.5 to all in reach (8 s) |
| Ember Mage | Rare | Human | Ground ranged | 30 | 1.6 s | 45 | 5% | 8% ×2.5 | 260 | 135 | 600 | Fireball: ×3 area (7 s) |
| Griffin Knight | Rare | Celestial | **Flying** melee | 45 | 1.0 s | 260 | 10% | 10% ×2 | 40 | 200 | 3K | Dive: ×3.5 hit + knockback (7 s) |
| Cleric | Rare | Dwarf | Ground melee | 70 | 1.2 s | 400 | 25% | 5% ×2 | 36 | 150 | 7K | Blessing: heal heroes 30% (10 s) |
| Druid | Rare | Elf | Ground ranged | 160 | 1.3 s | 900 | 5% | 8% ×2 | 250 | 150 | 25K | Entangle: root all in reach 2.5 s, ×0.5 hit (11 s) |
| Ranger | Epic | Elf | Ground ranged | 380 | 0.9 s | 600 | 5% | 15% ×2 | 240 | 172 | 90K | Rapid Fire: ×2.5 attack speed 4 s (12 s) |
| Cannoneer | Epic | Dwarf | Ground ranged | 2.6K | 2.2 s | 3.2K | 15% | 5% ×3 | 300 | 125 | 220K | Cannon Barrage: ×4 area, radius 150 (9 s) |
| Storm Fairy | Epic | Celestial | **Flying** ranged | 900 | 1.0 s | 1.5K | 5% | 12% ×2 | 220 | 190 | 400K | Chain Lightning: ×1.3 to all in reach (9 s) |
| Paladin | Legendary | Dwarf | Ground melee | 2.4K | 1.2 s | 12K | 35% | 5% ×2 | 40 | 142 | 1.5M | Holy Bastion: heal heroes 15%, base 10% (14 s) |
| Banner Knight | Legendary | Human | Ground melee | 9K | 1.1 s | 60K | 30% | 5% ×2 | 40 | 150 | 5M | War Cry: all heroes ×1.6 attack speed 5 s (15 s) |
| Seraph | Legendary | Celestial | **Flying** ranged | 26K | 1.0 s | 40K | 10% | 15% ×2.5 | 260 | 200 | 20M | Judgment: ×2 to all in reach 420 (10 s) |

Level cost: `base cost × 1.075^level` (the Cost column is the start of the curve).

### 3b. Hero races (team bonuses)

These count heroes in the collection. The highest tier reached applies to the whole squad.

| Race | Heroes | Bonus (2 / 3 heroes) |
|---|---|---|
| Human | Squire, Ember Mage, Banner Knight | +15% / +30% health |
| Elf | Archer, Druid, Ranger | +10% / +20% attack speed |
| Dwarf | Cleric, Cannoneer, Paladin | +10% / +20% defense |
| Celestial | Griffin Knight, Storm Fairy, Seraph | +15% / +30% attack |

### 3c. Star bonuses

Each hero has five star bonuses, unlocked one per star. A bonus goes to:
- **Self:** the hero itself (its portrait shows on the star).
- **Team:** every hero in the squad (the three helmets).
- **Race:** every hero of that race (the race emblem).

Team and race bonuses count while their hero is in the squad. Defense and crit
chance bonuses add points (+5% = +5 points); the others multiply.

| Hero | ★1 | ★2 | ★3 | ★4 | ★5 |
|---|---|---|---|---|---|
| Squire | +10% attack | Team +100% move speed | Humans +50% attack | +50% health | Team +25% attack |
| Banner Knight | +25% health | Team +15% attack | Humans +50% health | Team +5 defense | Team +25% attack speed |
| Ember Mage | +15% attack | Team +5 crit | Humans +25% attack speed | +15 crit | Team +25% attack |
| Archer | +10% attack speed | Team +10% attack | Elves +50% attack | +10 crit | Team +20% attack speed |
| Druid | +20% health | Team +20% health | Elves +50% health | Team +5 defense | Team +40% health |
| Ranger | +25% move speed | Team +5 crit | Elves +30% attack speed | +50% attack | Team +30% attack |
| Cannoneer | +15% attack | Team +10% attack | Dwarves +50% attack | +30% attack speed | Team +10 crit |
| Cleric | +5 defense | Team +15% health | Dwarves +10 defense | +50% health | Team +8 defense |
| Paladin | +25% health | Team +5 defense | Dwarves +50% health | +50% attack | Team +40% health |
| Griffin Knight | +20% move speed | Team +30% move speed | Celestials +50% attack | +30% attack speed | Team +20% attack |
| Seraph | +15% attack | Team +20% health | Celestials +50% health | Team +8 crit | Team +35% attack |
| Storm Fairy | +15% attack speed | Team +10% attack speed | Celestials +30% attack speed | +15 crit | Team +8 crit |

### 3d. Race wheel (rock, paper, scissors)

Hero races and monster races alternate around one wheel. Each race beats the
next one. A race deals **+50%** damage to the race it beats and **−25%** to
the race that beats it (`CampaignConfig.race_counter_bonus` / `race_counter_penalty`).

```
Human → Goblinoid → Elf → Beast → Dwarf → Elemental → Celestial → Demon → Human
                                                      Celestial → Undead
```

| Race | Beats | Loses to |
|---|---|---|
| Human | Goblinoid | Demon |
| Elf | Beast | Goblinoid |
| Dwarf | Elemental | Beast |
| Celestial | Demon, Undead | Elemental |

Undead sit outside the ring: only Celestials counter them, and their revive is
their edge. The hero and monster popups show the wheel as icons: a sword with
a green arrow next to the races it beats, and a red arrow next to the races
that beat it.

**Skill effects**
- **Strike:** one heavy hit plus knockback.
- **Volley:** hits everything in reach.
- **Blast:** area damage.
- **Heal:** heroes and/or your base.
- **Frenzy:** attack speed for the caster.
- **Snare:** roots monsters; bosses are rooted half as long.
- **Rally:** attack speed for the whole squad. A weaker boost never replaces a stronger one.

### What an upgrade brings

| Upgrade | Paid with | Effect | Survives rebirth |
|---|---|---|---|
| Shard pack (5 shards) | Gems: 20 / 30 / 45 / 70 / 100 by rarity | Toward that hero's next star | **Yes** |
| Hero level | Gold | +1× base attack and health (linear) | No |
| Milestone (every 25 levels) | — | Attack and health ×2 | No |
| Star (5 max: 10/25/50/100/200 shards) | Shards | Unlocks the hero's next star bonus (3c) | **Yes** |
| Warlord's Blade / Iron Heart | Souls | +50% attack / health per level, all heroes | **Yes** |
| Golden Idol | Souls | +25% all gold per level | **Yes** |
| Bastion Stone | Souls | +50% base health per level | **Yes** |
| Income level | Gold | +1× base payout (linear), ×2 every 25 levels | No |

## 4. Enemy stats

| Stat | Stage 1 | Per stage | Notes |
|---|---|---|---|
| Health | 12 | ×1.18 | × monster type |
| Attack | 6 | ×1.19 | × monster type |
| Attack speed | 1 / 1.2 s | — | |
| Move speed | 75 | — | × monster type |
| Range | 40 melee, 180–200 shooters | — | Shooters fire bolts and can hit flyers |
| Layer | ground or flying | — | Flyers ignore ground melee heroes |
| Defense | per type | — | 0–35% |
| Gold | 2 | ×1.15 | × monster type |

- **Boss** (every 10th stage, sent at the start): health ×12, attack ×4, gold ×15,
  at least 20% defense, 1.6× size, 30% slower.
- **Escalation**: monsters sent later in a stage are stronger, with health and
  attack ×1.012^seconds (about ×1.4 after 30 s, ×8.5 after 3 min). Because it
  compounds, a stalemate always ends: a squad that can't break the base in
  time gets overrun and drops a stage. Demons escalate 50% faster.
- **Spawning**: 1–2 monsters every 2.8 s, at most 8 alive.
- **Late game**: from stage 60, monster health and attack and enemy base health
  grow an extra ×1.04 per stage. Your base doesn't, so walls come back for a
  maxed-out squad.

### Monster races (traits)

| Race | Trait |
|---|---|
| Beast | Moves 30% faster |
| Goblinoid | Each one arrives with an extra copy |
| Undead | Gets up once at 30% health |
| Elemental | +15% defense, but crits deal 50% more |
| Demon | Escalates 50% faster during a stage |

### Monster roster

The values listed are health ×, gold × and defense.

| Zone | Ground | Shooter (ranged) | Flyer | Boss |
|---|---|---|---|---|
| Meadow | Slime (Elemental 1/1/0), Beetle (Beast 1.2/1.2/25%), Goblin Scout (Goblinoid 0.8/0.9/5%) | — | Hornet (Beast 0.6/1.1/0) | Slime King (Elemental) |
| Dark Forest | Cave Spider (Beast 0.85/0.9/0), Treant (Elemental 1.3/1.25/30%) | Goblin Slinger (Goblinoid, 200) | Bat (Beast 0.6/1.1/0) | Elder Treant (Elemental) |
| Sunscorch Desert | Mummy (Undead 1.15/1.1/15%), Sand Wyrm (Elemental 0.9/1/10%) | Scorpion (Beast, 180) | Bone Vulture (Undead 0.7/1.15/5%) | Sand Colossus (Elemental) |
| Frost Peaks | Yeti (Beast 1.3/1.3/20%), Frost Goblin (Goblinoid 1/1/10%) | Ice Imp (Demon, 200) | Frost Wisp (Elemental 0.85/1/0) | Frost Giant (Elemental) |
| Ember Volcano | Magma Golem (Elemental 1.35/1.3/35%), Salamander (Beast 1/1/10%) | Fire Imp (Demon, 200) | Ash Wraith (Undead 0.75/1.1/0) | **Inferno Drake (Demon, flying)** |

Zones change every 10 stages and loop after Ember Volcano. Stage 50's flying
boss can only be hurt by ranged and flying heroes.

## 5. Bases

| Base | Health at stage 1 | Per stage |
|---|---|---|
| Enemy base | 150 | ×1.19 |
| Your base | 150 | ×1.185 (+ Bastion Stone) |

Both are rebuilt at full health for every stage.

## 6. Gold

**Kills**: monster gold (section 4).

**Income sources**: each fills a timer and pays on its own, including while you're offline.

```
payout = base gold × level × 2^(level / 25) × 1.04^(stage − 1) × gold relic
```

| Source | Cycle | Base payout | Unlock cost |
|---|---|---|---|
| Lumber Camp | 3 s | 3 | starts owned |
| Fishing Dock | 8 s | 30 | 200 |
| Copper Mine | 20 s | 400 | 2K |
| Blacksmith | 45 s | 5K | 15K |
| Merchant Caravan | 90 s | 60K | 120K |
| Royal Mint | 180 s | 800K | 1M |

Level cost: `unlock cost × 1.07^level`. The small stage factor (+4%/stage) keeps
income worth upgrading all run without outgrowing the enemies.

**Offline**: income sources keep running at 100%, and kills count at 50%. The cap is 8 hours.

**Pacing target** (measured with an auto-play run on the long lane with all 12
heroes): stage 40 (rebirth) in ~12 minutes, stage ~65 at 24 minutes, then a
slower climb with occasional drops. These numbers are from before hero chests;
with chests, the time to get the whole squad depends on keys and luck.

## 7. Gems and achievements

Gems come from achievements and the 7-day login calendar (5 / 5 / 10 / 10 / 15 /
15 / 30 gems), and buy shard packs.

| Achievement | Goal | Gems |
|---|---|---|
| Monster Hunter | Defeat 100 monsters | 10 |
| Siege Breaker | Destroy 25 enemy bases | 5 |
| Explorer / Conqueror | Reach stage 25 / 100 | 10 / 50 |
| Boss Slayer | Defeat 25 bosses | 15 |
| Reborn | First rebirth | 25 |
| Air Defense | Defeat 50 flying monsters | 20 |
| Full Squad | Collect all 12 heroes | 50 |
| Tycoon | Own all 6 income sources in one run | 30 |
| Star Power | Earn 5 hero stars | 25 |

## 7b. Rebirth

- Unlocks at stage 40.
- Souls earned: `5 × (best stage / 40)^3`, rounded down.
- Resets: stage, gold, hero levels (back to 1) and income levels.
- Keeps: the hero collection, keys, relics, stars, shards and achievements.

## 7b2. Hero chest

- **Start:** the run starts with the Squire and one chest key.
- **Heroes:** every other hero comes from the hero chest and stays in the
  collection for good (level 1 at the start of every run; gold levels it up).
- **Price:** a chest costs one key, or 150 gems without keys.
- **Keys:** come from the first clear of every 5th stage in a run, with one
  extra on boss stages. That's about 12 keys by stage 40.
- **Odds:** each hero is weighted by rarity (Common 50, Rare 30, Epic 14,
  Legendary 5). The hero index shows the resulting chance per rarity.
- **Luck protection:**
  - the first chests always give a new hero until 4 heroes are collected;
  - a duplicate is rerolled once;
  - a duplicate that remains turns into shards (5 / 6 / 8 / 10 by rarity).
- **Hero index:** shows all 12 heroes as cards. Owned heroes show their level
  and stars; the others show as locked silhouettes.

## 7c. Art direction

- **Look:** a dark, painted look inspired by the genre of UnderGuild /
  UnderDark, with our own characters and art:
  - shaded volumes, thin inner lines and one ink outline per silhouette;
  - detailed gear and texture (planks, bricks, bark, rivets, feathers);
  - chibi heroes and monsters (big heads, expressive eyes);
  - muted dusk-colored zones, warm glows (torches, magic) and a vignette.
- **Icons over words:** the UI shows icons where a word would do.
  - Stat sheets are icon + value grids with no captions or explanations.
  - Numbers in the top bar and the rows carry icons (coin, heart, sword,
    hourglass, base towers), and the tabs show icons.
  - Skills pop their icon on the field instead of their name.
  - Only names and the rebirth info stay as text.
- **No tutorial:** there are no tutorial textboxes or first-time tips. The
  screens explain themselves.
- **UI:** a flat, muted, crafted interface:
  - the top bar and the bottom menu run edge to edge;
  - dark charcoal panels and card slots with thin ink lines;
  - copper accents for what you own;
  - stone buttons;
  - a bottom navigation bar (Heroes, Income, the hero chest medallion in the
    middle, Relics, Collection).

  Characters, props and icons share one dusty palette.
- **Collection:** the Collection tab is a grid of hero slots:
  - owned heroes are copper-lined, with their level and a shard bar that
    turns red when a star-up is ready;
  - the others are dark silhouettes with a lock.
- **Zones** get their own props: oaks and bushes, dark pines and glowing
  mushrooms, cacti and skull rocks, snowy pines and ice spikes, dead trees
  and lava rocks.

## 7d. Sound and music

- **Music:** a battle theme (D minor, 112 BPM, 68 s loop). Boss stages
  cross-fade to a faster boss theme (E minor, 140 BPM, 27 s loop) and back.
- **Combat** (positional, quieter when far from the view):
  - Each hero has its own attack sound: slash, blunt, arrow, cannon, fire,
    magic, holy or zap.
  - Each skill has its own cast sound.
  - Monsters bite or spit when they attack, and pop with a coin when they die.
  - Undead make a sound when they get back up. Bosses fall with a big boom.
- **Stage flow** (full volume):
  - A base collapsing, then a fanfare (won) or a falling phrase (lost).
  - A war horn when a boss stage starts.
  - A chime when shards drop.
- **Progress:** a recruit fanfare, a level-up blip, a star-up chime and a
  rebirth swell.
- **Mixing:** each sound has a minimum interval, so 12 heroes attacking at once
  stay readable. In a full late-game battle, about 7 sounds play at once on
  average.

## 8. Planned next

- **Ranged and flying archetypes per race**: for example Undead shooters and Demon flyers.
- **More hero races**, or a fourth member per race for a higher synergy tier.
- **Gear**: changes the fixed stats (attack speed, defense, crit, range).
