# ============================================================================
# Figure 1 --- The calibrated hierarchical BB interval, end to end (SWMDK,
# teacher scale, respondent-weighted target).
#   1. Clustered data: 639 pupils in 30 classrooms (circle area = m_g).
#   2. Two-stage weights: one illustrative draw of cluster weights A_g and
#      within-classroom weights B_gi (display seed; illustrative only).
#   3. The hierarchical BB distribution of weighted polytomous H --- the
#      99,999 locked production draws (task P17-T01).
#   4. Width calibration: the raw interval SHRINKS about its midpoint by
#      k_G = 1 - 1.5/sqrt(30) = .726 (real teacher endpoints).
# ============================================================================

source("00_common.R")

sw <- read_swmdk()
sizes <- as.integer(table(sw[[1]]))
assert(length(sizes) == 30L && sum(sizes) == 639L, "SWMDK dimensions changed")

emp_sel <- p17_methods |>
  filter(scale == "teacher", target_role == "respondent",
         interval_role == "phase16_confirmed_selected")
emp_raw <- p17_methods |>
  filter(scale == "teacher", target_role == "respondent",
         grepl("^V4-PRI-TWO-STAGE-HBB", method_id))
assert_close(emp_sel$lower, kn("teacher_resp_lo"), msg = "teacher lower drifted")

# ---- (1) clustered data ------------------------------------------------------
set.seed(20260728)  # display-only jitter
cl <- data.frame(g = seq_len(30), m = sizes) |>
  mutate(x = (g - 1) %% 6, y = -((g - 1) %/% 6))
p1 <- ggplot(cl, aes(x, y, size = m)) +
  geom_point(shape = 21, fill = "#CBDEEC", color = "#3D82B4", stroke = 0.6) +
  geom_text(aes(label = m), family = BASE_FAMILY, size = 1.75,
            color = PAL$ink2) +
  annotate("text", x = 2.5, y = -5.25,
           label = "639 pupils in G = 30 classrooms\n(number = classroom size)",
           family = BASE_FAMILY, size = 2.15, color = PAL$ink2,
           lineheight = 1) +
  scale_size_area(max_size = 7.8, guide = "none") +
  coord_cartesian(xlim = c(-0.5, 5.5), ylim = c(-5.7, 0.55), clip = "off") +
  labs(subtitle = "1 · Clustered responses") +
  theme_schematic() +
  theme(plot.subtitle = element_text(size = BASE_SIZE + 0.1, face = "bold",
                                     color = PAL$ink, margin = margin(b = 2)),
        plot.margin = margin(2, 3, 8, 3))

# ---- (2) two-stage weights ---------------------------------------------------
set.seed(20260729)  # display-only draw
Ag <- rgamma(30, 1, 1); Ag <- Ag / sum(Ag)
show_g <- order(sizes)[c(4, 15, 27)]  # small, median, large classroom
wd <- do.call(rbind, lapply(show_g, function(g) {
  b <- rgamma(sizes[g], 1, 1); b <- b / sum(b)
  data.frame(g = g, i = seq_len(sizes[g]), w = sizes[g] * Ag[g] * b /
               sum(sizes * Ag))
}))
wd$panel <- factor(paste0("m = ", sizes[wd$g]),
                   levels = paste0("m = ", sizes[show_g]))
p2_top <- ggplot(data.frame(g = seq_len(30), A = Ag), aes(g, A)) +
  geom_col(fill = "#3D82B4", width = 0.75) +
  geom_hline(yintercept = 1/30, linetype = "dotted", linewidth = 0.3,
             color = PAL$ink3) +
  labs(subtitle = "2 · Two-stage weights", x = NULL, y = NULL) +
  scale_x_continuous(expand = expansion(mult = c(0.02, 0.02))) +
  theme_schematic() +
  theme(plot.subtitle = element_text(size = BASE_SIZE + 0.1, face = "bold",
                                     color = PAL$ink, margin = margin(b = 1)))
p2_bot <- ggplot(wd, aes(i, w)) +
  geom_col(fill = PAL$sky, width = 0.78) +
  facet_wrap(~panel, nrow = 1, scales = "free_x") +
  labs(x = NULL, y = NULL) +
  theme_schematic() +
  theme(strip.text = element_text(size = BASE_SIZE - 1.9, color = PAL$ink2,
                                  hjust = 0, face = "plain",
                                  margin = margin(b = 0.5)),
        panel.spacing.x = unit(1.6, "mm"))
p2 <- p2_top / p2_bot + plot_layout(heights = c(1, 0.85))

# ---- (3) HBB distribution (locked production draws) -------------------------
dr <- read_draws(task = 1)
assert(nrow(dr) == 99999L, "T01 draw count changed")
dens <- density(dr$H, adjust = 1.1)
dd <- data.frame(x = dens$x, y = dens$y) |> filter(x > 0.5, x < 0.75)
dmax <- max(dd$y)

p3 <- ggplot(dd, aes(x, y)) +
  geom_area(fill = PAL$sky, alpha = 0.30) +
  geom_line(color = PAL$blue, linewidth = 0.55) +
  geom_vline(xintercept = emp_sel$point_estimate, linewidth = 0.4,
             color = PAL$ink) +
  annotate("text", x = 0.505, y = 0.92 * dmax,
           label = "99,999 draws of",
           family = BASE_FAMILY, size = 2.05, color = PAL$ink2, hjust = 0) +
  annotate("text", x = 0.505, y = 0.80 * dmax,
           label = "italic(H)(italic(F)^{(italic(W))})",
           parse = TRUE, family = BASE_FAMILY, size = 2.3,
           color = PAL$ink2, hjust = 0) +
  scale_x_continuous(limits = c(0.5, 0.75),
                     breaks = c(0.55, 0.62, 0.69),
                     labels = c(".55", ".62", ".69")) +
  labs(subtitle = "3 · HBB distribution of H",
       x = expression("Scale"~italic(H)), y = NULL) +
  theme_pa() +
  theme(axis.text.y = element_blank(),
        panel.grid.major.y = element_blank(),
        plot.subtitle = element_text(size = BASE_SIZE + 0.1, face = "bold",
                                     color = PAL$ink, margin = margin(b = 2)),
        plot.margin = margin(2, 3, 4, 3))

# ---- (4) shrink calibration --------------------------------------------------
zoom <- data.frame(
  lab = c("raw equal-tail 95%", "calibrated 95% CI"),
  lower = c(emp_raw$lower, emp_sel$lower),
  upper = c(emp_raw$upper, emp_sel$upper),
  y = c(2, 1), col = c(PAL$raw, PAL$calibrated)
)
mid <- (emp_raw$lower + emp_raw$upper) / 2
p4 <- ggplot(zoom) +
  geom_vline(xintercept = mid, linetype = "dotted", linewidth = 0.35,
             color = PAL$ink3) +
  geom_segment(aes(x = lower, xend = upper, y = y, yend = y),
               linewidth = 2.1, color = zoom$col, lineend = "butt") +
  geom_segment(aes(x = lower, xend = lower, y = y - 0.16, yend = y + 0.16),
               linewidth = 0.6, color = zoom$col) +
  geom_segment(aes(x = upper, xend = upper, y = y - 0.16, yend = y + 0.16),
               linewidth = 0.6, color = zoom$col) +
  geom_text(aes(x = mid, y = y + 0.34, label = lab),
            family = BASE_FAMILY, size = 2.25, color = zoom$col) +
  annotate("segment", x = emp_raw$lower, xend = emp_sel$lower,
           y = 1.6, yend = 1.6, linewidth = 0.4, color = PAL$ink,
           arrow = arrow(length = unit(1.3, "mm"), type = "closed")) +
  annotate("segment", x = emp_raw$upper, xend = emp_sel$upper,
           y = 1.6, yend = 1.6, linewidth = 0.4, color = PAL$ink,
           arrow = arrow(length = unit(1.3, "mm"), type = "closed")) +
  annotate("text", x = mid, y = 0.52, label = "midpoint preserved",
           family = BASE_FAMILY, size = 2.05, color = PAL$ink2) +
  annotate("text", x = mid, y = 0.26,
           label = "'each half-width' %*% ~ italic(k)[italic(G)] == 1 - 1.5/sqrt(30) ~ '= .726'",
           parse = TRUE, family = BASE_FAMILY, size = 2.05, color = PAL$ink2) +
  scale_x_continuous(limits = c(0.53, 0.71),
                     breaks = c(0.55, 0.62, 0.69),
                     labels = c(".55", ".62", ".69")) +
  scale_y_continuous(limits = c(0.02, 2.65)) +
  labs(subtitle = "4 · Calibrated interval",
       x = expression("Scale"~italic(H)), y = NULL) +
  theme_pa() +
  theme(axis.text.y = element_blank(),
        panel.grid.major.y = element_blank(),
        plot.subtitle = element_text(size = BASE_SIZE + 0.1, face = "bold",
                                     color = PAL$ink, margin = margin(b = 2)),
        plot.margin = margin(2, 3, 4, 3))

fig1 <- p1 + p2 + p3 + p4 + plot_layout(nrow = 1, widths = c(1, 1.05, 1.1, 1.1))
save_fig(fig1, "fig1_concept", MM_FULL, 60)
