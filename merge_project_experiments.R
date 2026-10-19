# Public entrypoint for the central experiment-DB merge.
#
# The implementation lives in modules/ so the housekeeping diagnostic and the
# actual merge share the same discovery and incremental-merge logic. Run this
# script from the template root as documented in EXPERIMENTS_DB.md.
source(file.path("modules", "merge_project_experiments.R"))
