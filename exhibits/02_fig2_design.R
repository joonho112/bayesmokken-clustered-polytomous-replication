# ============================================================================
# Figure 2 --- The evaluation design at a glance.
# (a) The clustered graded data-generating process (illustrative parameter
#     settings): theta = sqrt(ICC) u_g + sqrt(1-ICC) e_i drives cumulative-
#     logit category curves; setting all item discriminations EQUAL creates
#     the exact-knot lane (weighted marginals meet, the transport path can
#     switch); distinct discriminations keep cells regular.
# (b) The 24 fresh confirmation cells: G x latent ICC, fill = cluster-size
#     mechanism, symbol = regularity lane.
# (c) The frozen chronology (pilot -> training -> held-out -> lock ->
#     fresh confirmation -> SWMDK application).
# Quantitative claims never come from panel (a); it is a faithful schematic
# of the registered mechanism.
# ============================================================================

source("00_common.R")

logit_inv <- function(x) 1 / (1 + exp(-x))
THRESH <- c(-1.20, -0.35, 0.40, 1.25)   # frozen 'standard' profile

# ---- (a) graded curves + knot inset ----------------------------------------
th <- seq(-3, 3, length.out = 141)
cat_probs <- function(a, b = 0) {
  cum <- vapply(THRESH, function(t) logit_inv(a * (th - b - t)), numeric(length(th)))
  p <- cbind(1 - cum[, 1], cum[, 1] - cum[, 2], cum[, 2] - cum[, 3],
             cum[, 3] - cum[, 4], cum[, 4])
  data.frame(theta = rep(th, 5), cat = rep(0:4, each = length(th)),
             p = as.vector(p))
}
ga <- cat_probs(a = 1.2)
p_a1 <- ggplot(ga, aes(theta, p, group = cat,
                       color = factor(cat))) +
  geom_line(linewidth = 0.55, show.legend = FALSE) +
  scale_color_manual(values = colorRampPalette(c("#9CC2DC", "#084571"))(5)) +
  annotate("text", x = -2.9, y = 0.97,
           label = "italic(theta)[gi] == sqrt(ICC)*italic(u)[g] + sqrt(1 - ICC)*italic(e)[gi]",
           parse = TRUE, family = BASE_FAMILY, size = 2.4, color = PAL$ink2,
           hjust = 0) +
  scale_y_continuous(limits = c(0, 1.02), breaks = c(0, 0.5, 1),
                     labels = c("0", ".5", "1")) +
  scale_x_continuous(breaks = c(-2, 0, 2)) +
  labs(x = expression(italic(theta)),
       y = "Category probability",
       subtitle = "Graded clustered DGP (5 categories)") +
  theme_pa() +
  theme(plot.subtitle = element_text(size = BASE_SIZE + 0.1, face = "bold",
                                     color = PAL$ink))

# knot mechanism: two items' weighted marginal CDFs; equal discriminations
# force coincident score-CDF steps (exact knot), distinct ones separate them
knot <- data.frame(
  score = rep(0:4, 2),
  cdf_reg = c(0.10, 0.32, 0.62, 0.86, 1.00, 0.16, 0.40, 0.70, 0.90, 1.00),
  item = rep(c("Item j", "Item k"), each = 5)
)
knot_ex <- data.frame(
  score = rep(0:4, 2),
  cdf = c(0.12, 0.35, 0.65, 0.88, 1.00, 0.12, 0.35, 0.65, 0.88, 1.00),
  item = rep(c("Item j", "Item k"), each = 5)
)
p_a2 <- ggplot() +
  geom_step(data = knot, aes(score, cdf_reg, color = item),
            linewidth = 0.55, direction = "hv", show.legend = FALSE) +
  geom_step(data = knot_ex, aes(score, cdf + 0.0, group = item),
            linewidth = 0.5, direction = "hv", color = "#8C3B00",
            linetype = "22", alpha = 0.85, show.legend = FALSE) +
  annotate("text", x = 0.1, y = 0.97, label = "regular: CDFs separated",
           family = BASE_FAMILY, size = 2.15, color = "#3D82B4", hjust = 0) +
  annotate("text", x = 0.1, y = 0.885, label = "exact knot: CDFs coincide",
           family = BASE_FAMILY, size = 2.15, color = "#8C3B00", hjust = 0) +
  scale_color_manual(values = c("#3D82B4", "#084571")) +
  scale_y_continuous(limits = c(0, 1.02), breaks = c(0, 0.5, 1),
                     labels = c("0", ".5", "1")) +
  scale_x_continuous(breaks = 0:4) +
  labs(x = "Category score", y = "Weighted marginal CDF",
       subtitle = "Regularity lanes via discrimination ties") +
  theme_pa() +
  theme(plot.subtitle = element_text(size = BASE_SIZE + 0.1, face = "bold",
                                     color = PAL$ink))

# ---- (b) 24-cell map --------------------------------------------------------
MECH_LABS <- c(balanced = "Balanced", swmdk_like = "SWMDK-like",
               informative_positive = "Informative (+)",
               informative_negative = "Informative (−)")
db <- p16_design |>
  mutate(mech = factor(MECH_LABS[size_mechanism], levels = unname(MECH_LABS)),
         lane = factor(LANES$lane_lab[match(regularity, LANES$regularity)],
                       levels = levels(LANES$lane_lab)),
         G_f = factor(G), icc_f = factor(latent_icc))
assert(nrow(db) == 24L, "design changed")

p_b <- ggplot(db, aes(G_f, icc_f)) +
  geom_tile(aes(fill = mech), color = "white", linewidth = 1.0,
            width = 0.92, height = 0.92) +
  geom_point(aes(shape = lane), size = 1.9, stroke = 0.6,
             color = PAL$ink, fill = "white") +
  scale_fill_manual(values = c(Balanced = "#CBDEEC", `SWMDK-like` = "#9CC2DC",
                               `Informative (+)` = "#F5DEB8",
                               `Informative (−)` = "#F2C6A0"),
                    name = "Cluster-size mechanism") +
  scale_shape_manual(values = c(`Regular` = 21, `Near knot` = 23,
                                `Exact knot` = 24),
                     name = "Regularity lane") +
  labs(x = expression("Number of clusters"~italic(G)),
       y = "Latent ICC") +
  theme_pa() +
  theme(
    panel.grid.major = element_blank(),
    legend.position = "right",
    legend.key.height = unit(3.4, "mm"),
    legend.text = element_text(size = BASE_SIZE - 0.8),
    legend.title = element_text(size = BASE_SIZE - 0.4)
  )

# ---- (c) chronology ---------------------------------------------------------
chain <- tibble::tibble(
  x = 1:6,
  lab = c(
    "Pilot\nfeasibility;\novercoverage found",
    "Training\nγ grid {0…−1.5},\n24 cells",
    "Held-out validation\n18 disjoint cells,\ndisjoint seeds",
    "Method lock\nγ = −1.5,\ngates frozen",
    "Fresh confirmation\n24 new cells,\n9,600 reps/target",
    "Application\nSWMDK, G = 30,\nfrozen method"
  ),
  phase = c("Pilot", "Development", "Development", "Lock",
            "Confirmation", "Application")
)
p_c <- ggplot(chain, aes(x, 0)) +
  geom_segment(
    data = tibble::tibble(x = 1:5),
    aes(x = x + 0.38, xend = x + 0.62, y = 0, yend = 0),
    linewidth = 0.5, color = PAL$ink2,
    arrow = arrow(length = unit(1.8, "mm"), type = "closed")
  ) +
  geom_label(aes(label = lab, fill = phase),
             family = BASE_FAMILY, size = 1.95, lineheight = 1.0,
             label.padding = unit(1.3, "mm"), label.size = 0.25,
             color = PAL$ink, show.legend = FALSE) +
  scale_fill_manual(values = c(
    Pilot = "#F4F7FA", Development = "#EDF3F8", Lock = "#DCE8F2",
    Confirmation = "#CBDEEC", Application = "#B7D2E5"
  )) +
  scale_x_continuous(limits = c(0.44, 6.56), expand = c(0, 0)) +
  scale_y_continuous(limits = c(-0.45, 0.45)) +
  theme_schematic() +
  theme(plot.margin = margin(0, 2, 0, 2))

# ---- compose ----------------------------------------------------------------
row_a <- p_a1 + p_a2 + plot_layout(widths = c(1, 1))
fig2 <- (row_a / p_b / p_c) +
  plot_layout(heights = c(1, 1.12, 0.46)) +
  plot_annotation(tag_levels = list(c("(a)", "", "(b)", "(c)")))

save_fig(fig2, "fig2_design", MM_FULL, 122)
