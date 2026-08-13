# ============================================================================
# 08_osm_figures.R --- online-supplement figures for Paper B.
#   FigF1_cells: selected calibrated HBB coverage in every confirmation
#                cell (both targets), ordered by G, with MCSE bars and the
#                regularity lane marked.
#   FigG1_splithalf: SWMDK split-half endpoint stability for the four
#                selected intervals against the frozen .005 threshold.
# ============================================================================

source("00_common.R")

# ---- F1: all cells ----------------------------------------------------------
# Source: the derived all-lane summary (24 cells x 2 targets) built by
# 01_build_key_numbers.R from the raw phase-16 replication rows; the locked
# cell-summary artifact holds the 16 regular decision cells only.
fc <- readr::read_csv(file.path(PATHS$out_root, "derived_p16_allcell_summary.csv"),
                      show_col_types = FALSE) |>
  select(-regularity) |>
  left_join(p16_design, by = "cell_id") |>
  left_join(TARGETS, by = "target") |>
  mutate(
    lane = factor(LANES$lane_lab[match(regularity, LANES$regularity)],
                  levels = levels(LANES$lane_lab)),
    cell_lab = paste0("C", sprintf("%02d", as.integer(sub("P16-C", "", cell_id))),
                      " · G", G)
  ) |>
  arrange(G, latent_icc)
fc$cell_lab <- factor(fc$cell_lab, levels = unique(fc$cell_lab))
stopifnot(nrow(fc) == 48L, dplyr::n_distinct(fc$cell_id) == 24L)

f1 <- ggplot(fc, aes(cell_lab, coverage)) +
  annotate("rect", ymin = RESP_BAND[1], ymax = RESP_BAND[2],
           xmin = -Inf, xmax = Inf, fill = PAL$band, alpha = 0.9) +
  geom_hline(yintercept = NOMINAL, linetype = "22", linewidth = 0.35,
             color = PAL$ink2) +
  geom_hline(yintercept = 0.88, linetype = "dotted", linewidth = 0.35,
             color = PAL$ink3) +
  geom_errorbar(aes(ymin = coverage - coverage_mcse,
                    ymax = coverage + coverage_mcse, group = target_lab),
                width = 0, linewidth = 0.45, color = PAL$ink3,
                position = position_dodge(width = 0.55)) +
  geom_point(aes(shape = target_lab, fill = lane, group = target_lab),
             size = 1.8, stroke = 0.45, color = PAL$ink,
             position = position_dodge(width = 0.55)) +
  annotate("text", x = 0.7, y = 0.8835, label = "frozen regular-cell floor .88",
           family = BASE_FAMILY, size = 2.2, color = PAL$ink3, hjust = 0) +
  scale_shape_manual(values = c(`Respondent-weighted` = 21,
                                `Equal-cluster` = 24), name = "Target") +
  scale_fill_manual(values = c(`Regular` = PAL$calibrated,
                               `Near knot` = "#9CC2DC",
                               `Exact knot` = "#F2C6A0"),
                    name = "Regularity lane") +
  scale_y_continuous(limits = c(0.875, 1.005),
                     breaks = c(0.88, 0.91, 0.95, 0.99),
                     labels = c(".88", ".91", ".95", ".99")) +
  labs(x = "Confirmation cell (ordered by G, then latent ICC)",
       y = "Unconditional coverage") +
  guides(shape = guide_legend(override.aes = list(fill = "grey55", size = 1.9)),
         fill = guide_legend(override.aes = list(shape = 21, size = 1.9))) +
  theme_pa() +
  theme(axis.text.x = element_text(size = BASE_SIZE - 1.8, angle = 90,
                                   vjust = 0.5, hjust = 1),
        legend.position = "bottom",
        legend.margin = margin(t = -2))
save_fig(f1, "FigF1_cells", MM_FULL, 84, dir = FIG_OSM)

# ---- G1: SWMDK split-half stability ----------------------------------------
q <- p17_quant |>
  filter(grepl("GN150", method_id)) |>
  left_join(TARGETS, by = "target") |>
  mutate(
    row = paste0(ifelse(scale == "teacher", "Teachers", "Classmates"),
                 " · ", target_lab),
    lower_absolute_difference = as.numeric(lower_absolute_difference),
    upper_absolute_difference = as.numeric(upper_absolute_difference)
  ) |>
  pivot_longer(c(lower_absolute_difference, upper_absolute_difference),
               names_to = "endpoint", values_to = "absdiff") |>
  mutate(endpoint = ifelse(grepl("lower", endpoint), "Lower endpoint",
                           "Upper endpoint"))
assert(all(q$absdiff < 0.005), "split-half threshold violated?")

g1 <- ggplot(q, aes(absdiff, row, fill = endpoint)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.62,
           color = PAL$ink, linewidth = 0.25) +
  geom_vline(xintercept = 0.005, linetype = "22", linewidth = 0.4,
             color = PAL$vermillion) +
  annotate("text", x = 0.00505, y = 4.45, label = "frozen threshold .005",
           family = BASE_FAMILY, size = 2.3, color = PAL$vermillion, hjust = 1,
           vjust = 0) +
  scale_fill_manual(values = c(`Lower endpoint` = PAL$sky,
                               `Upper endpoint` = PAL$calibrated), name = NULL) +
  scale_x_continuous(limits = c(0, 0.0053),
                     breaks = c(0, 0.002, 0.004),
                     labels = c("0", ".002", ".004")) +
  labs(x = "Absolute split-half endpoint difference", y = NULL) +
  theme_pa() +
  theme(legend.position = "bottom", legend.margin = margin(t = -2))
save_fig(g1, "FigG1_splithalf", MM_MID, 62, dir = FIG_OSM)
