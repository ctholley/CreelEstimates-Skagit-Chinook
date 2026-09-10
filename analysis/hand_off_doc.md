# Skagit fall Chinook encounter analysis — handoff

Status as of 2026-09-10.

Repo: `CreelEstimates-Skagit-Chinook`
Script: `skagit_chinook_reach_analysis.R`
Input: `input_files/DailyEstimates.csv`
Outputs: `analysis/`

---
  
  ## 1. The decision
  
  Additional sections upstream of the Dalles Bridge are scheduled to open **Wednesday Sep 16, 2026**. The 2026 unmarked Chinook encounter quota is **1,450**. If the quota is exhausted the Skagit closes to all fishing, so opening the upper river early risks the October fishery on a run forecast to be large.

Three questions:
  
  1. What proportion of Chinook encounters would occur in the additional sections if they open as scheduled?
  2. How do the resulting savings relate to what the lower river has produced so far, using the historical split between mouth-to-Dalles and Dalles-to-Marblemount plus Cascade?
  3. Would delaying the Dalles-upstream opening be enough to get through the peak, or does currently-open water also need to close?
  
  ---
  
  ## 2. Scope and currency — read this before changing anything
  
  **Fish included: `Mark == "UM"`, adult and jack.** That combination reconciles to the in-season ledger:
  
  | Definition | 2026 through Sep 6 | % of 1,450 |
  |---|---|---|
  | **UM, adult + jack** | **606** | **41.8%** |
  | UM+UNK, adult + jack | 754 | 52.0% |
  | UM, adult only | 223 | 15.4% |
  
  "Nearly half used" matches UM adult+jack. **Confirm this against the official ledger before anything goes to co-managers** — if the quota actually counts UNK as well, the fishery is at 52% and every projection below shifts up.

**Units.**
  
  ```
mortality  = kept × 1 + released × 0.10
encounters = mortality / 0.10
```

Kept fish only appear in 2025 and 2026 (and they are UM, not AD — this is not a mark-selective retention fishery). Under this conversion a kept fish counts as 10 encounters, which inflates 2025–26 relative to earlier years. That is deliberate and matches the ledger, but it means raw cross-year comparisons of encounter totals are not apples-to-apples with 2021–2024.

**Reach split: boundary at the Dalles Bridge (Concrete).**
  
  - Lower: `Skagit.1.0`, `2.0`, `2.1`, `2.2`, `3.0`
- Upper: `Skagit.4.0`, `4.1`, `4.3`, `5.0`, `Cascade.1.0`

The Cascade enters at Marblemount, upstream of the Dalles, so it sits in Upper. If you want it broken out separately that is a one-line change, and it is arguably worth doing — it is a tributary with later timing than Section 5.0.

---
  
  ## 3. Data gotchas
  
  These will bite you if you aggregate naively.

- **`mean_catch_daily` is the only usable field across the whole series.** `mean_catch_period` is `NA` for every BSS year (2024–2026). Sum daily values over dates for any period, week, or season total.
- **`estimate_type` changes mid-series.** PE for 2021–2023, BSS for 2024–2026, with no overlap inside a year — so summing across it cannot double count, but the estimator itself changed.
- **`section_num` is not stable between years. Use `Proposed Section #`.** Section definitions moved: 2021 has `2.0` (later split into `2.1`/`2.2`) and `4.1`/`4.3` (later merged into `4.0`). The reach rollup exists to make years comparable.
- **`angler_type` has mixed case** (`Bank`/`bank`). Normalize before grouping on it.
- **`period` is a Monday-start week index, but its offset from the ISO week number varies by year.** Do not compute it from a calendar function. The script derives the period containing Sep 16 from each year's own Monday→period mapping and steps forward for 2026, which has no samples that week yet. It lands on period 37 in 2021, 2022, 2023, 2025, 2026 and period 38 in 2024 (Sep 16 was a Monday that year).
- **Partial periods.** 2026 period 32 is a single day (Aug 16); 2025 period 32 is two days; 2024 period 35 is one day. These read artificially low in period totals. The projection anchor deliberately uses periods 33–35 to avoid this.
- **No AD records at all in 2023, 2024, or 2026.** AD Chinook were not enumerated separately in those creel years. This is why UNK apportionment by year ratio was abandoned — it would silently assign 100% of UNK to UM in half the record.
- **2024 is excluded throughout.** Upper-river estimates that year are unusable per the original data caveat, and Cascade and Section 5.0 are absent entirely.
- **2021's lower river records zero encounters after period 35.** Almost certainly a coverage gap, not a true zero. It makes 2021 unusable for any reach proportion — it produces a meaningless 100% upper share. Verify this against the 2021 survey records if anyone wants to use that year.

---
  
  ## 4. Current answers
  
  ### Q1 — proportion in the additional sections
  
  Two views. The period-resolved one is the more defensible.

**Aggregate, Sep 16 to season end** (`analysis/reach_share_by_period.csv`, and the earlier `Q1_reach_shares.csv`):
  
  | Year | Upper share |
  |---|---|
  | 2022 | 67% |
  | 2023 | 36% |
  | 2025 | 49% |
  | *2021* | *100% (artifact — see gotchas)* |
  
  **By period, restricted to periods where both reaches were actually open:**
  
  | Period | 2022 | 2023 | 2025 |
  |---|---|---|---|
  | 35 | 68.9 | — | — |
  | 37 | — | 6.3 | 39.6 |
  | 38 | 26.8 | 68.7 | 42.0 |
  | 39–41 | — | — | 50.7 / 50.4 / 52.9 |
  | 42–44 | — | — | 60.0 / 68.0 / 64.4 |
  | 45–46 | — | — | 44.4 / 71.9 |
  
  **2025 is the only year that supports a period-resolved proportion.** It shows the upper share near 40% in the week of Sep 16, rising through 50% by period 39 and 60–68% into mid-October. 2022 and 2023 contribute two usable periods each and disagree sharply at period 38.

Working answer: **roughly 40% in the first week or two after opening, rising toward 50–65% through October** — resting on one year.

### Q2 — relation to lower-river experience

Upper:lower encounter ratio from period 37 onward: 0.57 (2023), 2.06 (2022), 0.95 (2025). Median **0.95**.

Opening the upper river has historically **roughly doubled the fishery-wide burn rate** — multiplier 1.6× to 3.1×.

### Q3 — is delay enough?

**No.** Three independent lines point the same way.

**Burn rate (the figure to lean on — no modelling assumptions).** 2026 is running **210 encounters/period** in the lower river alone (periods 34–35 mean; period 35 was the highest yet at 259). With 844 encounters left, **the lower river alone exhausts the quota in about four weeks — early October.** Apply the Q2 multiplier and it goes in roughly two, around Sep 20–27.

**Delay savings** (`analysis/delay_savings.csv`), as % of post-Sep-16 encounters avoided:
  
  | Delay | 2021 | 2022 | 2023 | 2025 | median |
  |---|---|---|---|---|---|
  | 1 wk | 10.0 | 0.0 | 1.2 | 7.5 | 4.4 |
  | 2 wk | 53.6 | 11.0 | 28.1 | 16.3 | 22.2 |
  | 3 wk | 82.5 | 53.9 | 36.4 | 24.0 | 45.2 |
  | 4 wk | 82.5 | 53.9 | 36.4 | 31.2 | 45.2 |
  | 5 wk | 91.0 | 67.4 | 36.4 | 36.8 | 52.1 |
  | stay closed | 100.0 | 67.4 | 36.4 | 48.7 | 58.1 |
  
  **Projected season totals.** Opening as scheduled: median 2,121 encounters (146% of quota, range 1,283–4,424). Upper closed all season: median 1,329 (92% of quota, range 606–3,102). Three of four analogs blow through the quota even with the upper river shut for the entire season.

Conclusion: delay buys real time but not enough. **Currently-open water has to be part of the conversation.**
  
  ---
  
  ## 5. How the extrapolation works, and why to be careful with it
  
  Figure 3's bands come from four single-year analogs, built in three steps.

1. **Anchor.** Lower-reach encounters over periods 33–35 — the window 2026 has complete. Period 32 is excluded (single day in 2026).
2. **Scale.** `f_y = anchor_2026 / anchor_y`:

   | Analog | Lower p33–35 | f |
   |---|---|---|
   | 2021 | 92 | 6.2 |
   | 2022 | 52 | 11.0 |
   | 2023 | 34 | 16.9 |
   | 2025 | 91 | 6.2 |

3. **Project.** For each period from 36 on, `lower = f × lower_y[p]`, and `upper = f × upper_y[p]` once past the reopen period. Accumulate on top of the observed 606.

The band is the **min–max across those four lines** and the middle line is their **median**. It is a spread of four analogs, **not a confidence interval** — do not let it be read as one.

**The load-bearing assumption is that 2026's elevation above the analog year persists for the rest of the season.** If the early surge is run timing shifted earlier rather than a larger run, these projections overshoot, possibly badly. The wide f range (6× to 17×) reflects how far outside the historical envelope 2026 is: lower-river encounters through Sep 6 already exceed every prior year's full season.

**Effort displacement is not modelled.** Closing the upper river moves anglers downstream rather than removing them, so every savings figure above is an upper bound and the lower-river burn rate would likely rise under a closure.

If you are uncomfortable with the extrapolation — reasonable — Q1 and Q2 stand on observed proportions alone, and Q3 can be argued from the burn rate without it.

---

## 6. Open items

- [ ] **Confirm the quota basis** — UM only or UM+UNK, adults or adults+jacks. Changes 41.8% to 52.0% and shifts every projection.
- [ ] **Verify the 2021 lower-river gap** after period 35 against survey records. Decide whether to drop 2021 from reach proportions entirely.
- [ ] **Jack retention is driving 2026.** Lower-reach UM mortality is 60.6 total against 22.3 adults; the difference is retained jacks, and jacks exceed adults in three of four open sections. If jacks can be managed separately from the adult budget that materially changes the picture.
- [ ] Consider breaking the Cascade out from Upper — different timing than Section 5.0.
- [ ] Sensitivity on the release mortality rate (0.10 assumed throughout, hard-coded as `RELEASE_MORT`).
- [ ] Section 5.0 dominates the upper reach in 2021–22 (12.1 and 16.3 UM mortalities) but collapsed to 1.1 in 2023 and 5.7 in 2025. It is the single largest driver of scenario spread and worth understanding before relying on any upper-river projection.

---

## 7. Output files

| File | Contents |
|---|---|
| `fig1_um_mortality_reach.png` | UM mortality by period, reach × year, split by life stage |
| `fig2_um_encounters_reach.png` | Same on an encounter axis |
| `fig3_quota_and_savings.png` | Cumulative encounters vs quota; delay savings |
| `um_by_reach_period.csv` | Mortality and encounters by year, reach, period, life stage |
| `reach_share_by_period.csv` | Upper/lower split by period with a `both_open` flag |
| `quota_projection.csv` | Projection bands behind figure 3 |
| `delay_savings.csv` | Delay scenario table |

The `both_open` flag in `reach_share_by_period.csv` matters — without it you will read a 100% upper share off periods where only one reach was fishing.