# ==============================================================================
# Skagit fall Chinook -- unmarked encounter accounting by reach
#
# Repo:   CreelEstimates-Skagit-Chinook
# Input:  input_files/DailyEstimates.csv
# Output: analysis/
#
# Produces:
#   fig1_um_mortality_reach.png   UM mortality by period, reach x year
#   fig2_um_encounters_reach.png  same on an encounter axis
#   fig3_quota_and_savings.png    cumulative encounters vs quota + delay savings
#   plus the summary tables behind each figure
#
# Currency:
#   mortality  = kept x 1 + released x RELEASE_MORT
#   encounters = mortality / RELEASE_MORT
#
# Scope: Mark == "UM", adult + jack. That combination reconciles to the
# in-season ledger (606 of 1450 encounters used through Sep 6, 41.8%).
# 2024 is excluded throughout -- upper-river estimates that year are unusable.
# ==============================================================================

library(tidyverse)
library(here)
library(lubridate)
library(patchwork)

# ---- parameters --------------------------------------------------------------

RELEASE_MORT  <- 0.10
QUOTA         <- 1450                                   # 2026 UM encounter quota
CURRENT_YEAR  <- 2026
ANALOG_YEARS  <- c(2021, 2022, 2023, 2025)              # 2024 dropped
ANCHOR_PERIODS <- 33:35                                 # see "extrapolation" below
DECISION_DATE <- ymd("2026-09-16")

LOWER_SECTIONS <- c("Skagit.1.0", "Skagit.2.0", "Skagit.2.1", "Skagit.2.2", "Skagit.3.0")

out_dir <- here("analysis")
dir.create(out_dir, showWarnings = FALSE)

# ---- read --------------------------------------------------------------------

req <- c("Proposed Section #", "event_date", "period", "year", "Species",
         "LifeStage", "Mark", "Fate", "mean_catch_daily")

raw <- readxl::read_xlsx(here("input_files", "DailyEstimates_drop.xlsx"))

if (length(setdiff(req, names(raw))) > 0) stop("Missing expected columns: ", paste(setdiff(req, names(raw)), collapse = ", "))

# mean_catch_period is NA for every BSS year (2024-2026), so mean_catch_daily is
# the only field populated across the whole series. Sum it over dates for any
# period, week or season total. estimate_type is PE for 2021-2023 and BSS for
# 2024-2026 with no overlap inside a year, so summing across it cannot double
# count. section_num is not stable between years; `Proposed Section #` is.

dat <- raw |>
  rename(prop_section = `Proposed Section #`) |>
  filter(str_to_lower(Species) == "chinook", Mark == "UM") |>
  mutate(
    event_date = as_date(event_date),
    reach      = if_else(prop_section %in% LOWER_SECTIONS,
                         "Lower (below Dalles)", "Upper (above Dalles)"),
    mortality  = if_else(Fate == "Kept", mean_catch_daily,
                         RELEASE_MORT * mean_catch_daily),
    encounters = mortality / RELEASE_MORT
  )

# The Cascade enters at Marblemount, upstream of the Dalles Bridge, so
# Cascade.1.0 falls in the upper reach.

# ---- period containing the decision date -------------------------------------
# `period` is a Monday-start week index, but its offset from the ISO week number
# is not constant between years, so derive it from each year's own
# Monday -> period mapping rather than from a calendar function. 2026 has no
# samples that week yet, so step forward from the nearest observed week.

period_for_date <- function(d, target_date) {
  ref    <- d |>
    mutate(monday = floor_date(event_date, "week", week_start = 1)) |>
    distinct(monday, period)
  target <- floor_date(target_date, "week", week_start = 1)
  i      <- which.min(abs(as.numeric(ref$monday - target)))
  ref$period[i] + as.integer(round(as.numeric(target - ref$monday[i]) / 7))
}

decision_period <- dat |>
  group_by(year) |>
  group_modify(~ tibble(
    period = period_for_date(.x, update(DECISION_DATE, year = .y$year))
  )) |>
  ungroup()

OPEN_PERIOD <- decision_period$period[decision_period$year == CURRENT_YEAR]

# ---- figures 1 and 2: reach x year -------------------------------------------

reach_period <- dat |>
  summarise(mortality  = sum(mortality),
            encounters = sum(encounters),
            .by = c(year, reach, period, LifeStage)) |>
  filter(year != 2024)

write_csv(reach_period, file.path(out_dir, "um_by_reach_period.csv"))

reach_plot <- function(yvar, ylab, subtitle) {
  ggplot(reach_period, aes(period, {{ yvar }}, colour = LifeStage)) +
    geom_vline(data = filter(decision_period, year != 2024),
               aes(xintercept = period),
               colour = "firebrick", linetype = 2, linewidth = 0.4) +
    geom_line(linewidth = 1) +
    geom_point(size = 1.1) +
    facet_grid(reach ~ year) +
    scale_colour_manual(values = c(adult = "black", jack = "darkgray")) +
    labs(x = "Period", y = ylab, colour = NULL, subtitle = subtitle) +
    scale_x_continuous(breaks = seq(32, 52, by = 2),
                       minor_breaks = seq(32, 52, by = 1)) +
    theme_bw(base_size = 14) +
    theme(panel.grid.minor = element_blank(),
          strip.text       = element_text(face = "bold"),
          legend.position  = "bottom")
}

fig1 <- reach_plot(mortality,  "Unmarked Chinook mortalities",
                   "Dashed line on September 16")
fig2 <- reach_plot(encounters, "Unmarked Chinook encounters",
                   "Dashed line on September 16")

fig1
fig2




# ----------------------------
  
  catch_period <- dat |>
  summarise(catch = sum(mean_catch_daily),
            .by = c(year, reach, period, LifeStage, Fate)) |>
  filter(year != 2024)

fig3 <- ggplot(catch_period,
                    aes(period, catch,
                        colour   = Fate,
                        linetype = LifeStage,
                        group    = interaction(LifeStage, Fate))) +
  geom_vline(data = filter(decision_period, year != 2024),
             aes(xintercept = period),
             colour = "firebrick", linetype = 2, linewidth = 0.4) +
  geom_line(linewidth = 0.6) +
  geom_point(size = 1.1) +
  facet_grid(reach ~ year) +
  scale_x_continuous(breaks = seq(min(catch_period$period),
                                  max(catch_period$period), by = 1),
                     expand = expansion(mult = 0.02)) +
  scale_colour_manual(values = c(Released = "#1f4e79", Kept = "#c0392b")) +
  scale_linetype_manual(values = c(adult = "solid", jack = "22")) +
  labs(x = "Period", y = "Estimated catch (fish)",
       colour = NULL, linetype = NULL,
       subtitle = "Dashed vertical line marks the period containing September 16") +
  theme_bw(base_size = 14) +
  theme(panel.grid.minor = element_blank(),
        strip.text       = element_text(face = "bold"),
        axis.text.x      = element_text(size = 10, angle = 90,
                                        vjust = 0.5, hjust = 1),
        # strip.background = element_blank(),
        legend.position  = "bottom")

fig3

# ---- write -------------------------------------------------------------------
fig1
fig2
fig3
ggsave(file.path(out_dir, "fig1_um_mortality_reach.png"),  fig1, width = 11, height = 7, dpi = 300, scale = 1)
ggsave(file.path(out_dir, "fig2_um_encounters_reach.png"), fig2, width = 11, height = 7, dpi = 300,scale = 1)
ggsave(file.path(out_dir, "fig3_um_estimated_catch_reach.png"),   fig3, width = 13, height = 5.5, dpi = 300, scale = 1)

# # ggsave(file.path(out_dir, "fig4_um_catch_reach.png"), fig_catch,
#        # width = 11, height = 5, dpi = 300)
# 
# # ---- extrapolation to the rest of the 2026 season ----------------------------
# #
# # The 2026 season is only four periods old, so the remaining burn has to come
# # from somewhere. Each analog year supplies one projection, built in three steps:
# #
# #   1. ANCHOR. Take lower-reach encounters over periods 33-35 -- the window
# #      2026 has complete. Period 32 is dropped because it is a single day
# #      (Aug 16) in 2026 and would bias the anchor low.
# #
# #   2. SCALE. f_y = anchor_2026 / anchor_y. This is how many times larger 2026
# #      is running than that analog year over the same weeks. The factors are
# #      large and spread widely (roughly 6x to 17x) because 2026's lower-river
# #      encounters through Sep 6 already exceed every prior year's full season.
# #
# #   3. PROJECT. For each period p from 36 on:
# #        lower_p = f_y * lower_y[p]
# #        upper_p = f_y * upper_y[p]   if p >= reopen period, else 0
# #      Accumulate on top of the 2026 observed total through period 35.
# #
# # The band on figure 3 is the min-max across analog years and the line is the
# # median. It is a spread of four single-year analogs, not a fitted interval.
# #
# # Two assumptions carry the result. First, that 2026's remaining seasonal shape
# # resembles the analog year's. Second, that 2026's elevation above the analog
# # holds for the rest of the season rather than regressing. The second is the
# # weaker one: if the early-season surge is a run-timing shift rather than a
# # larger run, these projections overshoot. The independent burn-rate figure
# # printed at the end does not depend on either assumption.
# #
# # Effort displacement is not modelled. Closing the upper river moves anglers
# # downstream rather than removing them, so the savings are an upper bound.
# 
# period_enc <- dat |>
#   summarise(encounters = sum(encounters), .by = c(year, reach, period))
# 
# observed_2026 <- period_enc |>
#   filter(year == CURRENT_YEAR) |>
#   summarise(encounters = sum(encounters), .by = period) |>
#   arrange(period) |>
#   mutate(cumulative = cumsum(encounters))
# 
# used_to_date <- sum(observed_2026$encounters)
# last_period  <- max(observed_2026$period)
# 
# anchor <- period_enc |>
#   filter(reach == "Lower (below Dalles)", period %in% ANCHOR_PERIODS) |>
#   summarise(anchor = sum(encounters), .by = year)
# 
# scale_factors <- anchor |>
#   filter(year %in% ANALOG_YEARS) |>
#   mutate(f = anchor$anchor[anchor$year == CURRENT_YEAR] / anchor)
# 
# project <- function(analog_year, reopen_period) {
#   f <- scale_factors$f[scale_factors$year == analog_year]
#   period_enc |>
#     filter(year == analog_year, period > last_period) |>
#     mutate(encounters = if_else(reach == "Upper (above Dalles)" &
#                                   period < reopen_period, 0, encounters * f)) |>
#     summarise(encounters = sum(encounters), .by = period) |>
#     complete(period = (last_period + 1):48, fill = list(encounters = 0)) |>
#     arrange(period) |>
#     transmute(analog = analog_year, period,
#               cumulative = used_to_date + cumsum(encounters))
# }
# 
# scenarios <- tribble(
#   ~scenario,                        ~reopen_period,
#   "Upper opens Sep 16 (scheduled)", OPEN_PERIOD,
#   "Upper stays closed",             Inf
# )
# 
# projection <- scenarios |>
#   reframe(map2_dfr(ANALOG_YEARS, list(reopen_period), project),
#           .by = scenario) |>
#   summarise(lo  = min(cumulative), hi = max(cumulative),
#             mid = median(cumulative), .by = c(scenario, period))
# 
# write_csv(projection, file.path(out_dir, "quota_projection.csv"))
# 
# # ---- delay savings -----------------------------------------------------------
# 
# delays <- tibble(
#   label  = factor(c("1 wk\nSep 23", "2 wk\nSep 30", "3 wk\nOct 7",
#                     "4 wk\nOct 14", "5 wk\nOct 21", "stay\nclosed"),
#                   levels = c("1 wk\nSep 23", "2 wk\nSep 30", "3 wk\nOct 7",
#                              "4 wk\nOct 14", "5 wk\nOct 21", "stay\nclosed")),
#   reopen = c(1, 2, 3, 4, 5, Inf)
# )
# 
# savings <- period_enc |>
#   filter(year %in% ANALOG_YEARS) |>
#   left_join(decision_period, by = "year", suffix = c("", "_sep16")) |>
#   filter(period >= period_sep16) |>
#   cross_join(delays) |>
#   summarise(
#     avoided = sum(encounters[reach == "Upper (above Dalles)" &
#                                period < period_sep16 + reopen]),
#     total   = sum(encounters[!duplicated(paste(period, reach))]),
#     .by = c(year, label)
#   ) |>
#   mutate(pct_avoided = 100 * avoided / total)
# 
# write_csv(savings, file.path(out_dir, "delay_savings.csv"))
# 
# # ---- figure 3 ----------------------------------------------------------------
# 
# pal <- c("Upper opens Sep 16 (scheduled)" = "#c0392b",
#          "Upper stays closed"             = "#2471a3")
# 
# p_quota <- ggplot(projection, aes(period)) +
#   geom_ribbon(aes(ymin = lo, ymax = hi, fill = scenario), alpha = 0.15) +
#   geom_line(aes(y = mid, colour = scenario), linewidth = 1) +
#   geom_line(data = observed_2026, aes(period, cumulative),
#             colour = "black", linewidth = 1.2) +
#   geom_point(data = observed_2026, aes(period, cumulative),
#              colour = "black", size = 1.6) +
#   geom_hline(yintercept = QUOTA, linetype = 2) +
#   geom_vline(xintercept = OPEN_PERIOD, colour = "firebrick",
#              linetype = 3, linewidth = 0.5) +
#   annotate("text", x = 32.2, y = QUOTA * 1.05, hjust = 0, size = 3,
#            label = paste0("quota = ", format(QUOTA, big.mark = ","))) +
#   scale_colour_manual(values = pal) +
#   scale_fill_manual(values = pal) +
#   coord_cartesian(xlim = c(32, 48), ylim = c(0, 3200)) +
#   labs(x = "Period", y = "Cumulative unmarked Chinook encounters",
#        colour = NULL, fill = NULL,
#        subtitle = "Black line is observed 2026. Bands span the four analog years.") +
#   theme_minimal(base_size = 10) +
#   theme(panel.grid.minor = element_blank(),
#         legend.position = c(0.03, 0.93), legend.justification = c(0, 1),
#         legend.background = element_blank())
# 
# p_savings <- savings |>
#   ggplot(aes(label, pct_avoided, group = year, colour = factor(year))) +
#   geom_line(linewidth = 0.7) +
#   geom_point(size = 2) +
#   stat_summary(aes(group = 1), fun = median, geom = "line",
#                colour = "black", linewidth = 1.2) +
#   stat_summary(aes(group = 1), fun = median, geom = "point",
#                colour = "black", size = 2.6, shape = 15) +
#   scale_colour_brewer(palette = "Dark2") +
#   coord_cartesian(ylim = c(0, 100)) +
#   labs(x = "Delay to upper-river opening", y = "% of post-Sep-16 encounters avoided",
#        colour = NULL, subtitle = "Black line is the median across analog years.") +
#   theme_minimal(base_size = 10) +
#   theme(panel.grid.minor = element_blank())
# 
# fig3 <- p_quota + p_savings



# ---- console summary ---------------------------------------------------------

# burn_rate <- observed_2026 |>
#   filter(period >= last_period - 1) |>
#   summarise(rate = mean(encounters)) |>
#   pull(rate)
# 
# cat("\n2026 through period ", last_period, ": ", round(used_to_date),
#     " encounters (", round(100 * used_to_date / QUOTA, 1), "% of quota)\n", sep = "")
# cat("recent burn rate: ", round(burn_rate), " encounters/period\n", sep = "")
# cat("weeks to quota, lower reach only: ",
#     round((QUOTA - used_to_date) / burn_rate, 1), "\n\n", sep = "")
# 
# print(scale_factors |> mutate(f = round(f, 2)))
# 
# cat("\nprojected season totals:\n")
# projection |>
#   filter(period == max(period)) |>
#   mutate(across(c(lo, hi, mid), round),
#          pct_of_quota = round(100 * mid / QUOTA)) |>
#   print()

sessionInfo()