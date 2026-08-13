# ============================================================================
# Figure 5 --- The prespecified SWMDK application.
# (a) Interval forest for both fixed scales: the selected calibrated HBB
#     under both targets, the raw HBB, and all frozen comparators
#     (respondent target). No threshold reference lines are drawn (frozen
#     protocol: threshold decisions excluded).
# (b) Observed cluster-size distribution (30 classrooms).
# (c) Category mass profile across the 11 fixed items.
# Data: phase-17 locked results; cluster sizes read directly from
# mokken::SWMDK (read-only, display only) and checked against the locked
# data profile.
# ============================================================================

source("00_common.R")

# ---- (a) forest -------------------------------------------------------------
ord <- c("Calibrated HBB · respondent", "Calibrated HBB · equal-cluster",
         "Raw HBB", "Two-level delta", "Two-stage NPB",
         "One-stage BB", "iid BB (naive)", "Within-stage")

fa <- p17_methods |>
  mutate(
    method_key = method_key_of(method_id),
    row_lab = case_when(
      interval_role == "phase16_confirmed_selected" &
        target_role == "respondent" ~ "Calibrated HBB · respondent",
      interval_role == "phase16_confirmed_selected" &
        target_role == "equal_cluster" ~ "Calibrated HBB · equal-cluster",
      method_key == "raw_hbb" & target_role == "respondent" ~ "Raw HBB",
      method_key == "raw_hbb" & target_role == "equal_cluster" ~ NA_character_,
      method_key == "twolevel_delta" ~ "Two-level delta",
      method_key == "freq_boot" ~ "Two-stage NPB",
      method_key == "one_stage" ~ "One-stage BB",
      method_key == "iid_bb" ~ "iid BB (naive)",
      method_key == "within_stage" ~ "Within-stage",
      TRUE ~ NA_character_
    )
  ) |>
  filter(!is.na(row_lab)) |>
  mutate(
    row_lab = factor(row_lab, levels = rev(ord)),
    scale_lab = factor(ifelse(scale == "teacher",
                              "With teachers (6 items)",
                              "With classmates (5 items)"),
                       levels = c("With teachers (6 items)",
                                  "With classmates (5 items)")),
    hero = grepl("^Calibrated", row_lab)
  ) |>
  left_join(METHODS |> select(method_key, color), by = "method_key")

assert(nrow(fa) == 16L, "forest rows changed (expect 8 x 2 scales)")
assert_close(fa$point_estimate[fa$scale == "teacher" &
                                 fa$row_lab == "Calibrated HBB · respondent"],
             kn("teacher_resp_H"), msg = "teacher H drifted")
assert_close(fa$lower[fa$scale == "classmate" &
                        fa$row_lab == "Calibrated HBB · respondent"],
             kn("classmate_resp_lo"), msg = "classmate lower drifted")

p_a <- ggplot(fa, aes(y = row_lab)) +
  geom_segment(aes(x = lower, xend = upper, yend = row_lab,
                   color = I(color), linewidth = hero, alpha = hero),
               lineend = "butt") +
  geom_point(aes(x = point_estimate, fill = I(color), size = hero),
             shape = 21, stroke = 0.45, color = PAL$ink) +
  facet_wrap(~scale_lab, nrow = 1) +
  scale_linewidth_manual(values = c(`TRUE` = 2.3, `FALSE` = 1.35),
                         guide = "none") +
  scale_alpha_manual(values = c(`TRUE` = 1, `FALSE` = 0.85), guide = "none") +
  scale_size_manual(values = c(`TRUE` = 2.0, `FALSE` = 1.55), guide = "none") +
  scale_x_continuous(limits = c(0.50, 0.70),
                     breaks = c(0.52, 0.58, 0.64, 0.70),
                     labels = c(".52", ".58", ".64", ".70")) +
  labs(x = expression("Scale"~italic(H)~"(weighted polytomous)"), y = NULL) +
  theme_pa() +
  theme(axis.text.y = element_text(size = BASE_SIZE - 0.6, color = PAL$ink),
        panel.spacing.x = unit(4, "mm"))

# ---- (b) cluster sizes ------------------------------------------------------
sw <- read_swmdk()
sizes <- as.integer(table(sw[[1]]))
assert(length(sizes) == kn("swmdk_G"), "cluster count mismatch vs locked profile")
assert(sum(sizes) == kn("swmdk_n"), "respondent count mismatch vs locked profile")
assert(min(sizes) == kn("swmdk_size_min") && max(sizes) == kn("swmdk_size_max"),
       "cluster size range mismatch")

p_b <- ggplot(data.frame(m = sizes), aes(m)) +
  geom_histogram(binwidth = 2, boundary = 0.5, fill = PAL$sky,
                 color = "white", linewidth = 0.4) +
  geom_vline(xintercept = median(sizes), linetype = "22", linewidth = 0.35,
             color = PAL$ink2) +
  annotate("text", x = median(sizes) - 0.8, y = 8.1,
           label = paste0("median ", median(sizes)),
           family = BASE_FAMILY, size = 2.3, color = PAL$ink2, hjust = 1) +
  scale_x_continuous(breaks = c(5, 15, 25)) +
  scale_y_continuous(breaks = c(0, 4, 8), expand = expansion(mult = c(0, .08))) +
  labs(x = expression("Classroom size"~italic(m)[g]),
       y = "Classrooms") +
  theme_pa()

# ---- (c) category masses ----------------------------------------------------
cats <- p17_cats |>
  mutate(item = factor(item, levels = unique(p17_cats$item)),
         scale_lab = factor(ifelse(scale == "teacher", "Teachers", "Classmates"),
                            levels = c("Teachers", "Classmates")))
assert_close(min(cats$mass), kn("swmdk_min_cat_mass"),
             msg = "minimum category mass drifted")

p_c <- ggplot(cats, aes(x = item, y = factor(score), fill = mass)) +
  geom_tile(color = "white", linewidth = 0.4) +
  facet_grid(. ~ scale_lab, scales = "free_x", space = "free_x") +
  scale_fill_gradientn(
    colours = c("#F3F7FA", "#9CC2DC", "#3D82B4", "#084571"),
    name = "Mass", breaks = c(0.1, 0.3, 0.5), labels = c(".1", ".3", ".5")
  ) +
  labs(x = NULL, y = "Category score") +
  theme_pa() +
  theme(
    panel.grid.major = element_blank(),
    axis.text.x = element_text(size = BASE_SIZE - 1.6, angle = 90,
                               vjust = 0.5, hjust = 1),
    legend.position = "right",
    legend.key.height = unit(4.4, "mm"),
    legend.key.width = unit(2.4, "mm")
  )

# ---- compose ----------------------------------------------------------------
fig5 <- p_a / (p_b + p_c + plot_layout(widths = c(0.55, 1.45))) +
  plot_layout(heights = c(1.15, 0.85)) +
  plot_annotation(tag_levels = list(c("(a)", "(b)", "(c)")))

save_fig(fig5, "fig5_swmdk", MM_FULL, 118)
