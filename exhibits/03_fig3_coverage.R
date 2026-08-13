# ============================================================================
# Figure 3 --- Fresh confirmatory evidence (money figure).
# (a) Coverage by regularity lane for all seven procedures. Selected
#     calibrated HBB shown for both targets; raw HBB evaluated on the
#     regular decision lane; comparators on all three lanes (respondent
#     target; the iid BB is the working-independence negative control).
# (b) Regular-lane length-versus-coverage frontier.
# Data: phase-16 lane/overall/comparator summaries (locked).
# ============================================================================

source("00_common.R")

# ---- assemble (a) -----------------------------------------------------------
sel_lane <- p16_lane |>
  transmute(regularity, target, method_key = "calibrated_hbb",
            coverage, mcse = coverage_mcse, len = mean_interval_length)
raw_reg <- p16_overall |>
  filter(gamma_cluster == 0) |>
  transmute(regularity = "regular", target, method_key = "raw_hbb",
            coverage, mcse = coverage_mcse, len = mean_interval_length)
cmp <- p16_comp |>
  transmute(regularity,
            target = ifelse(grepl("INDEPENDENCE", target_id),
                            "respondent", "respondent"),
            method_key = method_key_of(method_id),
            coverage, mcse = coverage_mcse, len = mean_interval_length)

d_a <- bind_rows(sel_lane, raw_reg, cmp) |>
  left_join(METHODS, by = "method_key") |>
  left_join(LANES, by = "regularity") |>
  left_join(TARGETS, by = "target") |>
  mutate(method = factor(as.character(short_lab),
                         levels = rev(levels(METHODS$short_lab))))

assert_close(d_a$coverage[d_a$method_key == "calibrated_hbb" &
                            d_a$regularity == "regular" &
                            d_a$target == "respondent"],
             kn("p16_resp_cov"), msg = "fig3 selected respondent cov drifted")
assert_close(min(d_a$coverage), kn("p16_cmp_within_exact_knot_cov"),
             msg = "fig3 min coverage drifted")

p_a <- ggplot(d_a, aes(x = coverage, y = method)) +
  annotate("rect", xmin = RESP_BAND[1], xmax = RESP_BAND[2],
           ymin = -Inf, ymax = Inf, fill = PAL$band, alpha = 0.9) +
  geom_vline(xintercept = NOMINAL, linetype = "22", linewidth = 0.35,
             color = PAL$ink2) +
  geom_vline(xintercept = RESP_BAND, linetype = "dotted",
             linewidth = 0.3, color = PAL$ink3) +
  geom_errorbar(aes(xmin = coverage - mcse, xmax = coverage + mcse,
                    group = target),
                orientation = "y", width = 0, linewidth = 0.5,
                position = position_dodge(width = 0.55),
                color = PAL$ink3, na.rm = TRUE) +
  geom_point(aes(fill = method, shape = target_lab, group = target,
                 size = method_key == "calibrated_hbb"),
             position = position_dodge(width = 0.55),
             stroke = 0.5, color = PAL$ink) +
  facet_wrap(~lane_lab, nrow = 1) +
  scale_shape_manual(values = c(`Respondent-weighted` = 21,
                                `Equal-cluster` = 24),
                     name = "Target") +
  scale_size_manual(values = c(`TRUE` = 2.25, `FALSE` = 1.6), guide = "none") +
  scale_fill_manual(values = PAL_SHORT, guide = "none") +
  scale_x_continuous(limits = c(0.855, 1.0),
                     breaks = c(0.90, 0.95, 1.00),
                     labels = c(".90", ".95", "1")) +
  labs(x = "Unconditional coverage", y = NULL) +
  guides(shape = guide_legend(override.aes = list(size = 1.9, fill = "grey55"))) +
  theme_pa() +
  theme(
    axis.text.y = element_text(size = BASE_SIZE - 0.6, color = PAL$ink),
    panel.spacing.x = unit(3.5, "mm"),
    legend.position = "bottom",
    legend.margin = margin(t = -2)
  )

# ---- (b) regular-lane frontier ---------------------------------------------
d_b <- d_a |> filter(regularity == "regular") |>
  mutate(method = factor(as.character(short_lab),
                         levels = levels(METHODS$short_lab)))

p_b <- ggplot(d_b, aes(x = len, y = coverage)) +
  annotate("rect", ymin = RESP_BAND[1], ymax = RESP_BAND[2],
           xmin = -Inf, xmax = Inf, fill = PAL$band, alpha = 0.9) +
  geom_hline(yintercept = NOMINAL, linetype = "22", linewidth = 0.35,
             color = PAL$ink2) +
  geom_point(aes(fill = method, shape = target_lab,
                 size = method_key == "calibrated_hbb"),
             stroke = 0.5, color = PAL$ink) +
  scale_shape_manual(values = c(`Respondent-weighted` = 21,
                                `Equal-cluster` = 24), guide = "none") +
  scale_size_manual(values = c(`TRUE` = 2.25, `FALSE` = 1.7), guide = "none") +
  scale_fill_manual(
    values = PAL_SHORT, name = NULL,
    breaks = as.character(METHODS$short_lab),
    guide = guide_legend(override.aes = list(shape = 21, size = 1.9,
                                             stroke = 0.5), ncol = 1)
  ) +
  scale_x_continuous(breaks = seq(0.06, 0.12, 0.02),
                     labels = c(".06", ".08", ".10", ".12"),
                     expand = expansion(mult = c(0.05, 0.07))) +
  scale_y_continuous(limits = c(0.855, 1.0),
                     breaks = c(0.88, 0.92, 0.95, 0.98),
                     labels = c(".88", ".92", ".95", ".98")) +
  labs(x = "Mean interval length (regular lane)",
       y = "Unconditional coverage") +
  theme_pa() +
  theme(legend.position = "right",
        legend.text = element_text(size = BASE_SIZE - 0.4))

fig3 <- p_a / p_b +
  plot_layout(heights = c(1.02, 1)) +
  plot_annotation(tag_levels = "a", tag_prefix = "(", tag_suffix = ")")

save_fig(fig3, "fig3_coverage", MM_FULL, 122)
