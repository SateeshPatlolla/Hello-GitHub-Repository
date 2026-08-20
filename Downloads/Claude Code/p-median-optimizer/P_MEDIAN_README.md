# P-Median Facility Location Optimization for Iowa Medical Cannabis Dispensaries

## Problem Statement

Iowa has 5 licensed medical cannabis dispensaries serving ~2,391 Census block groups across 99 counties. The goal is to identify **2 optimal locations** for new dispensaries that **minimize the population-weighted average commute time** for all Iowans.

This document explains how the p-median model works and how three real datasets — block group centroids, historical visit data, and population — fit into it.

---

## What the P-Median Is Actually Doing

Imagine you could pick up every Iowan who needs a dispensary, measure how far they'd have to drive, and sum up all that driving. The p-median picks the 2 new locations that make that total sum as small as possible. "Median" here is a misnomer from operations research history — it's really minimizing the weighted average distance.

The model has three ingredients, and each dataset maps to exactly one of them.

---

## The Three Ingredients

### Ingredient 1: Demand Points (2,391 Block Group Centroids)

Each block group centroid is a "demand point" — a place where people live and potentially need to visit a dispensary. The model doesn't care about individual people; it treats each block group as a single point representing everyone who lives there.

The model assigns every block group to exactly one dispensary (the nearest open one). That's the `xᵢⱼ` variable: block group *i* is assigned to facility *j*. Every block group gets assigned to exactly one facility, and it can only be assigned to a facility that's open.

### Ingredient 2: Travel Times (Drive-Time Matrix)

This is the `tᵢⱼ` in the formula — the drive time from block group *i* to candidate site *j*, computed offline using the Iowa OSM road network via the `drive-time` library. It's a **2,391 × m** matrix, where *m* is the number of candidate facility sites (5 existing + potential new locations).

The model uses these times as the "cost" of assigning a block group to a facility. A block group that's 90 minutes from its nearest dispensary contributes much more to the objective than one that's 10 minutes away — and that's exactly the signal the optimizer uses to decide where to place new facilities.

### Ingredient 3: Weights (Population and Visit Data)

The `wᵢ` in the formula is a weight on each block group, and it controls **whose commute the model cares about more**. This is the most important modeling decision — not the solver, not the algorithm — because the same formulation with different weights produces completely different facility placements.

---

## Three Weighting Strategies

### Option A — Weight by Population

```
wᵢ = total_population of block group i
```

A block group with 3,000 people counts 3× more than one with 1,000. The model minimizes total **person-minutes** of driving across Iowa. This is the **equity framing** — every resident's time matters equally regardless of whether they currently use a dispensary.

**Example:**

| Block Group | Population | Drive Time | Contribution to Objective |
|-------------|-----------|------------|--------------------------|
| 1042        | 2,800     | 45 min     | 2,800 × 45 = 126,000    |
| 0917        | 600       | 80 min     | 600 × 80 = 48,000       |

The optimizer would prioritize reducing block group 1042's drive time because more people are affected, even though 0917 has a longer commute. This sometimes means rural areas with small populations get underserved.

**Best for:** baseline analysis, equity-oriented policy arguments.

### Option B — Weight by Historical Visits

```
wᵢ = average monthly visits from block group i
```

Now the model cares about **revealed demand** — block groups that actually send patients to dispensaries. A rural block group with 2,000 residents but zero visits gets weight zero; a suburban block group with 500 residents and 40 visits per month gets weight 40.

**The problem:** this is circular. People who live far from a dispensary visit less *because* it's far. If you weight by current visits, the model optimizes for people who already have decent access and ignores the underserved areas where a new facility would unlock **latent demand**.

**Best for:** short-term operational optimization (serve current users better).

### Option C — Weight by Predicted Demand (Recommended)

```
wᵢ = predicted visits if a dispensary were nearby
```

This is where historical visit data earns its place. Instead of using raw visit counts, train a demand model that answers: **"how many visits per month would this block group generate IF a dispensary were nearby?"**

**Training approach:**

1. Identify block groups with good current access (within 30 min of a dispensary) — these have "unconstrained" demand where distance isn't suppressing visits.
2. Train a model on those block groups only:

| Feature | Source |
|---------|--------|
| `total_population` | ACS 5-Year |
| `pop_65_plus` | ACS (chronic pain correlates with age) |
| `median_hh_income` | ACS |
| `registered_patient_count` | Program data (if available) |
| `current_visit_rate` | Historical visits ÷ population |

3. Predict for **all** 2,391 block groups. The prediction for a remote block group answers: "if this block group had a dispensary nearby, how much demand would it generate based on its demographics?"
4. That predicted demand becomes `wᵢ`.

**Best for:** strategic facility placement that accounts for unmet need.

### Why the Weight Choice Matters

To make this concrete, imagine two candidate pairs for the 2 new dispensaries:

| | Pair A | Pair B |
|---|---|---|
| Locations | Fort Dodge + Ottumwa | Mason City + Burlington |
| Character | Medium towns, central/southern | Northern + southeastern Iowa |

- **Population weights** might pick **Pair A** because those areas have denser population currently far from any dispensary.
- **Historical-visit weights** might pick a location **near Des Moines suburbs** because that's where current visits are concentrated — even though those people already have Windsor Heights nearby.
- **Predicted-demand weights** might pick **Pair B** because the model identifies high latent demand among underserved elderly populations in those areas.

Same algorithm, same travel times, completely different answers — all driven by which `wᵢ` you use.

---

## Full Mathematical Formulation

### Inputs

| Symbol | Dimensions | Description |
|--------|-----------|-------------|
| *i* | 1..2,391 | Block group centroids (demand points) |
| *j* | 1..*m* | Candidate facility sites (5 existing + new candidates) |
| *tᵢⱼ* | 2,391 × *m* | Drive time from block group *i* to candidate site *j* |
| *wᵢ* | 2,391 × 1 | Weight per block group (population, visits, or predicted demand) |

### Decision Variables

| Variable | Domain | Meaning |
|----------|--------|---------|
| *yⱼ* | {0, 1} | 1 if facility *j* is open, 0 otherwise |
| *xᵢⱼ* | {0, 1} | 1 if block group *i* is assigned to facility *j* |

### Objective

```
Minimize  Σᵢ Σⱼ  wᵢ · tᵢⱼ · xᵢⱼ
```

In words: minimize the total weighted drive time across all block groups, where each block group's contribution is **(its weight) × (drive time to its assigned facility)**.

### Constraints

```
1. Every block group assigned to exactly one facility:
     Σⱼ xᵢⱼ = 1                           for each block group i

2. Can only assign to an open facility:
     xᵢⱼ ≤ yⱼ                              for each (i, j) pair

3. Exactly 7 facilities open (5 existing + 2 new):
     Σⱼ yⱼ = 7

4. Existing 5 dispensaries stay open:
     yⱼ = 1                                for j ∈ {Sioux City, Windsor Heights,
                                                     Waterloo, Council Bluffs,
                                                     Iowa City}
```

### What the Solver Does

The solver finds which 2 of the *m* candidate sites to set `yⱼ = 1` for, then optimally assigns all 2,391 block groups to their best facility given those choices. It uses branch-and-bound to prune the search space and returns the pair that minimizes the total weighted commute.

---

## Candidate Site Generation

The solver doesn't search every square meter of Iowa. You generate a realistic candidate set:

1. Start with block group centroids in **towns above 2,500 population**
2. Filter to those **more than 20 minutes** from any existing dispensary (no point placing a new facility next to an existing one)
3. Optionally filter by OSM **commercial/retail land use** zoning

This typically yields **300–500 candidates**. Combined with the 5 existing sites, the decision matrix is 2,391 × ~505. That's well within what CBC or Gurobi solves in seconds.

---

## Data Pipeline

```
┌─────────────────────────┐
│ Census TIGER/Line 2024  │──▶ data/iowa_block_groups.csv
│ (block group polygons)  │    (2,391 centroids with lat/lon)
└─────────────────────────┘
                                          │
┌─────────────────────────┐               ▼
│ Census ACS 5-Year API   │──▶ data/iowa_bg_demographics.csv
│ (population, income,    │    (population weights wᵢ)
│  age distribution)      │               │
└─────────────────────────┘               │
                                          │
┌─────────────────────────┐               │
│ Historical Visit Data   │──▶ Demand Model (XGBoost)
│ (dispensary visits per   │    ──▶ predicted demand weights wᵢ
│  block group per month) │               │
└─────────────────────────┘               │
                                          ▼
┌─────────────────────────┐    ┌─────────────────────────────┐
│ Iowa OSM Road Network   │──▶ │ Drive-Time Matrix tᵢⱼ       │
│ (iowa-latest.osm.pbf)   │    │ 2,391 × m (via drive-time)  │
└─────────────────────────┘    └──────────────┬──────────────┘
                                              │
                                              ▼
                               ┌──────────────────────────────┐
                               │ P-Median Solver               │
                               │ (PuLP + CBC or Gurobi)        │
                               │                               │
                               │ Inputs: tᵢⱼ, wᵢ, existing    │
                               │ Output: 2 optimal new sites   │
                               └──────────────┬───────────────┘
                                              │
                                              ▼
                               ┌──────────────────────────────┐
                               │ Results                       │
                               │ - Optimal facility locations   │
                               │ - Coverage % at 30/45/60 min  │
                               │ - Pop-weighted avg commute     │
                               │ - Before/after comparison      │
                               └──────────────────────────────┘
```

---

## Practical Constraints

Real-world facility siting requires constraints beyond the pure math:

| Constraint | How to Implement |
|------------|-----------------|
| Minimum distance between facilities | Filter candidate pairs where `tⱼₖ < 30 min` |
| Must be in a city above 10K population | Pre-filter candidate set |
| Zoning / commercial land use | Filter using OSM `landuse=commercial/retail` tags |
| Capacity constraints per facility | Add max-assignment constraints per facility |
| One per HHS region | Partition candidates by region, allocate p=1 per region |
| Equity: reduce racial/income disparities | Weight `wᵢ` by Social Vulnerability Index (SVI) |

---

## Validation

**Leave-one-out backtesting:** Remove one existing dispensary, run the optimization with p=1 (find 1 site), and check whether the model recovers its actual location. If it does for most existing sites, the model's spatial logic aligns with historical siting decisions. Where it diverges, investigate why — the model may be identifying better placements than what was historically chosen.

---

## Key Takeaway

The p-median is mechanically simple — minimize a weighted sum. The modeling craft is entirely in three choices:

1. **Which weights** (population vs. visits vs. predicted demand) — this changes the answer more than anything else
2. **Which candidate sites** (how you constrain the search space) — this keeps results realistic
3. **Which additional constraints** (distance floors, zoning, regional balance) — this makes results implementable

The solver is a commodity. The weights are the model.
