# +---------------------------------------------------------------------------+
# | REFERENCE CODE -- ARCHIVAL. NOTHING IN THIS PACKAGE SOURCES THIS FILE.     |
# |                                                                           |
# | This is the pipeline that produced data-frozen/, preserved as it ran. It   |
# | is here to be READ, not executed: it expects the research tree, an AWS     |
# | fleet, and inputs this package does not ship. The exhibit layer rebuilds   |
# | every number from the frozen snapshot instead.                             |
# |                                                                           |
# | Only this banner was added. Every code line below is byte-identical to     |
# | the archival original; reference-code/README.md records the digests.       |
# +---------------------------------------------------------------------------+

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop(
    "Usage: Rscript run-phase17-task-v1.R <task_id>",
    call. = FALSE
  )
}
task_id <- args[1L]

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
v4_root <- file.path(
  project_root,
  "codebase", "research", "v4", "cluster-polytomous"
)
r_root <- file.path(v4_root, "R")
phase17_root <- file.path(
  v4_root, "empirical-swmdk", "phase17"
)
protocol_root <- file.path(phase17_root, "protocol")
raw_root <- file.path(phase17_root, "aws-raw")
protocol_path <- file.path(
  protocol_root, "v4-phase17-swmdk-empirical-protocol-v1.yml"
)
lock_path <- file.path(
  protocol_root, "v4-phase17-protocol-lock-receipt-v1.json"
)
design_path <- file.path(
  protocol_root, "v4-phase17-task-design-v1.csv"
)
authority_path <- file.path(
  v4_root, "governance",
  "v4-phase17-empirical-application-authority-v1.json"
)

source(file.path(r_root, "core", "ordinal-h.R"))
source(file.path(r_root, "weights", "cluster-weights.R"))
protocol <- yaml::read_yaml(protocol_path)
lock <- jsonlite::read_json(lock_path, simplifyVector = TRUE)
authority <- jsonlite::read_json(
  authority_path, simplifyVector = TRUE
)
design <- utils::read.csv(
  design_path, stringsAsFactors = FALSE
)
task_index <- match(task_id, design$task_id)
if (is.na(task_index)) {
  stop("Unknown Phase 17 task_id: ", task_id, call. = FALSE)
}
task <- design[task_index, , drop = FALSE]
stopifnot(
  identical(
    authority$status,
    "AUTHORIZED_PHASE17_TO_G17_ONLY"
  ),
  identical(
    protocol$status,
    "FROZEN_PRE_PHASE17_EMPIRICAL_OUTCOME"
  ),
  identical(
    lock$status,
    "PASS_FROZEN_PRE_PHASE17_EMPIRICAL_OUTCOME"
  ),
  identical(
    unname(tools::sha256sum(protocol_path)),
    lock$files$protocol$sha256
  ),
  identical(
    unname(tools::sha256sum(design_path)),
    lock$files$task_design$sha256
  ),
  identical(protocol$compute$heavy_provider, "AWS_ONLY"),
  isFALSE(protocol$compute$gcp_allowed),
  isFALSE(protocol$phase18$authorized)
)

data("SWMDK", package = "mokken", envir = environment())
dataset_hash <- digest::digest(SWMDK, algo = "sha256")
stopifnot(identical(
  dataset_hash, protocol$dataset$object_digest_sha256
))
scales <- list(
  teacher = unlist(protocol$scales$teacher$items),
  classmate = unlist(protocol$scales$classmate$items)
)
X <- as.matrix(SWMDK[, scales[[task$scale]]])
cluster <- SWMDK$classId
supports <- rep(list(1:5), ncol(X))
names(supports) <- colnames(X)

draws_total <- protocol$precision$draws_per_random_weight_task
batch_size <- protocol$precision$batch_size
batches <- protocol$precision$batches_per_task
seed_base <- protocol$precision$seed_base
checkpoint_root <- file.path(
  raw_root, "checkpoints", task_id
)
dir.create(checkpoint_root, recursive = TRUE, showWarnings = FALSE)
dir.create(raw_root, recursive = TRUE, showWarnings = FALSE)
draw_path <- file.path(
  raw_root, paste0(task_id, "-draws-v1.csv.gz")
)
batch_manifest_path <- file.path(
  raw_root, paste0(task_id, "-batch-manifest-v1.csv")
)
receipt_path <- file.path(
  raw_root, paste0(task_id, "-receipt-v1.json")
)
if (file.exists(draw_path) && file.exists(receipt_path)) {
  message("Completed output already exists: ", task_id)
  quit(status = 0L)
}

make_weights <- function(draws, seed, replication_id) {
  switch(
    task$method_key,
    hbb_respondent = v4_two_stage_hbb_weights(
      cluster, draws, seed, "respondent", replication_id
    ),
    hbb_cluster = v4_two_stage_hbb_weights(
      cluster, draws, seed, "cluster", replication_id
    ),
    iid = v4_iid_bb_weights(
      cluster, draws, seed, replication_id
    ),
    one_stage = v4_one_stage_cluster_bb_weights(
      cluster, draws, seed, "respondent", replication_id
    ),
    two_stage_frequentist =
      v4_two_stage_frequentist_weights(
        cluster, draws, seed, "respondent", replication_id
      ),
    within_stage = v4_within_stage_hbb_weights(
      cluster, draws, seed, "respondent", replication_id
    ),
    stop("Unsupported Phase 17 method_key.", call. = FALSE)
  )
}

started_at <- Sys.time()
batch_rows <- vector("list", batches)
remaining <- draws_total
first_draw <- 1L
for (batch_id in seq_len(batches)) {
  draws_batch <- min(batch_size, remaining)
  checkpoint_path <- file.path(
    checkpoint_root,
    sprintf("%s-B%03d-v1.rds", task_id, batch_id)
  )
  batch_seed <- seed_base + task$task_index * 10000L + batch_id
  if (file.exists(checkpoint_path)) {
    batch <- readRDS(checkpoint_path)
  } else {
    replication_id <- paste0(
      task_id, "-B", sprintf("%03d", batch_id)
    )
    weights <- make_weights(
      draws_batch, batch_seed, replication_id
    )
    h_draws <- v4_ordinal_h_draws(
      X, weights$weights, supports
    )$H
    batch <- data.frame(
      draw_id = first_draw:(first_draw + draws_batch - 1L),
      batch_id = batch_id,
      within_batch_draw = seq_len(draws_batch),
      seed = batch_seed,
      H = h_draws,
      stringsAsFactors = FALSE
    )
    saveRDS(batch, checkpoint_path)
  }
  stopifnot(
    nrow(batch) == draws_batch,
    identical(batch$draw_id[1L], first_draw),
    identical(batch$seed[1L], as.integer(batch_seed))
  )
  batch_rows[[batch_id]] <- data.frame(
    task_id = task_id,
    batch_id = batch_id,
    seed = batch_seed,
    first_draw_id = min(batch$draw_id),
    last_draw_id = max(batch$draw_id),
    draws = nrow(batch),
    defined_draws = sum(is.finite(batch$H)),
    invalid_fraction = mean(!is.finite(batch$H)),
    H_digest_sha256 = digest::digest(
      batch$H, algo = "sha256", serialize = TRUE
    ),
    stringsAsFactors = FALSE
  )
  remaining <- remaining - draws_batch
  first_draw <- first_draw + draws_batch
}
stopifnot(remaining == 0L, first_draw == draws_total + 1L)

checkpoint_files <- list.files(
  checkpoint_root, pattern = "\\.rds$",
  full.names = TRUE
)
all_draws <- do.call(rbind, lapply(checkpoint_files, readRDS))
all_draws <- all_draws[order(all_draws$draw_id), , drop = FALSE]
rownames(all_draws) <- NULL
stopifnot(
  nrow(all_draws) == draws_total,
  identical(all_draws$draw_id, seq_len(draws_total))
)
all_draws$task_id <- task_id
all_draws$scale <- task$scale
all_draws$method_key <- task$method_key
all_draws$method_id <- task$method_id
all_draws$target <- task$target
all_draws <- all_draws[, c(
  "task_id", "scale", "method_key", "method_id", "target",
  "draw_id", "batch_id", "within_batch_draw", "seed", "H"
)]
connection <- gzfile(draw_path, open = "wt")
utils::write.csv(
  all_draws, connection, row.names = FALSE, na = ""
)
close(connection)
batch_manifest <- do.call(rbind, batch_rows)
utils::write.csv(
  batch_manifest, batch_manifest_path, row.names = FALSE
)

runner_path <- file.path(phase17_root, "run-phase17-task-v1.R")
receipt <- list(
  schema_version = "paperA-v4-phase17-task-receipt-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = "PASS_TASK_COMPLETE",
  task_id = task_id,
  task_index = task$task_index,
  scale = task$scale,
  method_key = task$method_key,
  method_id = task$method_id,
  target = task$target,
  dataset_digest_sha256 = dataset_hash,
  draws = nrow(all_draws),
  batches = nrow(batch_manifest),
  defined_draws = sum(is.finite(all_draws$H)),
  invalid_fraction = mean(!is.finite(all_draws$H)),
  draw_output = list(
    path = sub(paste0("^", project_root, "/"), "", draw_path),
    size_bytes = as.numeric(file.info(draw_path)$size),
    sha256 = unname(tools::sha256sum(draw_path))
  ),
  batch_manifest = list(
    path = sub(
      paste0("^", project_root, "/"), "", batch_manifest_path
    ),
    size_bytes =
      as.numeric(file.info(batch_manifest_path)$size),
    sha256 = unname(tools::sha256sum(batch_manifest_path))
  ),
  code_hashes = list(
    task_runner_sha256 =
      unname(tools::sha256sum(runner_path)),
    ordinal_h_sha256 = unname(tools::sha256sum(
      file.path(r_root, "core", "ordinal-h.R")
    )),
    cluster_weights_sha256 = unname(tools::sha256sum(
      file.path(r_root, "weights", "cluster-weights.R")
    ))
  ),
  elapsed_seconds = as.numeric(
    difftime(Sys.time(), started_at, units = "secs")
  ),
  phase18_authorized = FALSE
)
jsonlite::write_json(
  receipt, receipt_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)
unlink(checkpoint_root, recursive = TRUE)
message(
  "PASS: ", task_id, " completed ", nrow(all_draws),
  " high-precision draws."
)
