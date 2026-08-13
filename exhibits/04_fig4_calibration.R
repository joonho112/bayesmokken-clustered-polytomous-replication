# ============================================================================
# Figure 4 --- Anatomy of the cluster-rate calibration.
# (a) The training gamma path: unconditional coverage and mean length of the
#     candidate interval as gamma_cluster moves from 0 (raw) to -1.5, for
#     both targets, with the frozen training eligibility bands. Only
#     gamma = -1.25 and -1.5 were eligible; -1.5 was selected (shortest).
# (b) Fresh-confirmation coverage of the selected method by number of
#     clusters G and by cluster-size mechanism (both targets), against the
#     frozen subgroup floor (.91).
# Data: phase-15 training decisions + phase-16 subgroup summary (locked).
# ============================================================================

source("00_common.R")

# ---- (a) gamma path ---------------------------------------------------------
ga <- p15_dec |>
  transmute(gamma = gamma_cluster,
            `Respondent-weighted_cov` = respondent_coverage,
            `Equal-cluster_cov` = equal_cluster_coverage,
            `Respondent-weighted_len` = respondent_mean_interval_length,
            `Equal-cluster_len` = equal_cluster_mean_interval_length,
            eligible = eligible %in% c(TRUE, "TRUE")) |>
  pivot_longer(-c(gamma, eligible),
               names_to = c("target_lab", ".value"), names_sep = "_")

assert_close(ga$len[ga$gamma == -1.5 & ga$target_lab == "Respondent-weighted"],
             kn("p15_sel_train_resp_len"), msg = "fig4 training length drifted")

TRAIN_BAND <- c(0.94, 0.98)   # frozen respondent training eligibility band

p_cov <- ggplot(ga, aes(gamma, cov, group = target_lab)) +
  annotate("rect", ymin = TRAIN_BAND[1], ymax = TRAIN_BAND[2],
           xmin = -Inf, xmax = Inf, fill = PAL$band, alpha = 0.9) +
  geom_hline(yintercept = NOMINAL, linetype = "22", linewidth = 0.35,
             color = PAL$ink2) +
  geom_line(linewidth = 0.5, color = PAL$ink3) +
  geom_point(aes(shape = target_lab, fill = eligible),
             size = 2.0, stroke = 0.5, color = PAL$ink) +
  annotate("segment", x = -1.5, xend = -1.5, y = 0.997, yend = 0.988,
           linewidth = 0.4, color = PAL$ink,
           arrow = arrow(length = unit(1.5, "mm"), type = "closed")) +
  annotate("text", x = -1.5, y = 1.001, label = "selected",
           family = BASE_FAMILY, size = 2.4, color = PAL$ink) +
  scale_shape_manual(values = c(`Respondent-weighted` = 21,
                                `Equal-cluster` = 24), name = "Target") +
  scale_fill_manual(values = c(`TRUE` = PAL$calibrated, `FALSE` = "grey78"),
                    name = "Training-eligible",
                    labels = c(`TRUE` = "yes", `FALSE` = "no")) +
  scale_x_continuous(breaks = c(0, -0.5, -0.75, -1, -1.25, -1.5),
                     labels = c("0", "−.5", "−.75", "−1",
                                "−1.25", "−1.5"),
                     trans = "reverse") +
  scale_y_continuous(limits = c(0.935, 1.002),
                     breaks = c(0.94, 0.96, 0.98, 1.0),
                     labels = c(".94", ".96", ".98", "1")) +
  labs(x = NULL, y = "Training coverage") +
  guides(shape = guide_legend(override.aes = list(fill = "grey55", size = 1.9)),
         fill = guide_legend(override.aes = list(shape = 21, size = 1.9))) +
  theme_pa() +
  theme(legend.position = "none")

p_len <- ggplot(ga, aes(gamma, len, group = target_lab)) +
  geom_line(linewidth = 0.5, color = PAL$ink3) +
  geom_point(aes(shape = target_lab, fill = eligible),
             size = 2.0, stroke = 0.5, color = PAL$ink) +
  scale_shape_manual(values = c(`Respondent-weighted` = 21,
                                `Equal-cluster` = 24), name = "Target") +
  scale_fill_manual(values = c(`TRUE` = PAL$calibrated, `FALSE` = "grey78"),
                    name = "Training-eligible",
                    labels = c(`TRUE` = "yes", `FALSE` = "no")) +
  scale_x_continuous(breaks = c(0, -0.5, -0.75, -1, -1.25, -1.5),
                     labels = c("0", "−.5", "−.75", "−1",
                                "−1.25", "−1.5"),
                     trans = "reverse") +
  scale_y_continuous(breaks = c(0.10, 0.12, 0.14),
                     labels = c(".10", ".12", ".14")) +
  labs(x = expression("Width-calibration constant"~gamma[cluster]~
                        "(multiplier"~1 + gamma[cluster]/sqrt(italic(G))*")"),
       y = "Training mean length") +
  guides(shape = guide_legend(override.aes = list(fill = "grey55", size = 1.9)),
         fill = guide_legend(override.aes = list(shape = 21, size = 1.9))) +
  theme_pa() +
  theme(legend.position = "bottom", legend.margin = margin(t = -2),
        legend.box = "horizontal")

# ---- (b) fresh-confirmation subgroups --------------------------------------
MECH_LABS <- c(balanced = "Balanced", swmdk_like = "SWMDK-like",
               informative_positive = "Informative (+)",
               informative_negative = "Informative (−)")
sb <- p16_sub |>
  filter(gamma_cluster == -1.5) |>
  mutate(
    target_lab = TARGETS$target_lab[match(target, TARGETS$target)],
    group_lab = ifelse(grouping_variable == "G",
                       paste0("G = ", grouping_value),
                       MECH_LABS[grouping_value]),
    panel = ifelse(grouping_variable == "G", "By number of clusters",
                   "By cluster-size mechanism")
  ) |>
  mutate(group_lab = factor(group_lab, levels = c(
    paste0("G = ", c(22, 35, 55, 80)), unname(MECH_LABS)
  )))

assert_close(min(sb$coverage[sb$grouping_variable == "G"]),
             kn("p16_min_G_group_cov"), msg = "fig4 G-subgroup min drifted")

p_b <- ggplot(sb, aes(x = group_lab, y = coverage)) +
  annotate("rect", ymin = 0.91, ymax = Inf, xmin = -Inf, xmax = Inf,
           fill = PAL$band, alpha = 0.9) +
  geom_hline(yintercept = NOMINAL, linetype = "22", linewidth = 0.35,
             color = PAL$ink2) +
  geom_hline(yintercept = 0.91, linetype = "dotted", linewidth = 0.35,
             color = PAL$ink3) +
  geom_errorbar(aes(ymin = coverage - coverage_mcse,
                    ymax = coverage + coverage_mcse, group = target_lab),
                width = 0, linewidth = 0.5, color = PAL$ink3,
                position = position_dodge(width = 0.5)) +
  geom_point(aes(shape = target_lab, group = target_lab),
             fill = PAL$calibrated, size = 2.0, stroke = 0.5,
             color = PAL$ink, position = position_dodge(width = 0.5)) +
  facet_grid(. ~ panel, scales = "free_x", space = "free_x") +
  annotate("text", x = 0.62, y = 0.9135, label = "frozen floor .91",
           family = BASE_FAMILY, size = 2.25, color = PAL$ink3, hjust = 0) +
  scale_shape_manual(values = c(`Respondent-weighted` = 21,
                                `Equal-cluster` = 24), name = "Target") +
  scale_y_continuous(limits = c(0.905, 1.0),
                     breaks = c(0.91, 0.95, 0.99),
                     labels = c(".91", ".95", ".99")) +
  labs(x = NULL, y = "Fresh-confirmation coverage") +
  guides(shape = guide_legend(override.aes = list(fill = "grey55", size = 1.9))) +
  theme_pa() +
  theme(legend.position = "none",
        axis.text.x = element_text(size = BASE_SIZE - 1.0))

fig4 <- (p_cov / p_len / p_b) +
  plot_layout(heights = c(1, 0.9, 1.05)) +
  plot_annotation(tag_levels = list(c("(a)", "", "(b)")))

save_fig(fig4, "fig4_calibration", MM_FULL, 132)
