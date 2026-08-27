# =====================================================================
# provenance.R -- P1.3 (ChatGPTs korrigierter Plan): Experiment-/
# Daten-Provenienz.
# =====================================================================
# Ziel-Frage laut Plan: "Was hat sich zwischen zwei Runs geaendert?"
# Empfohlene Felder (wenn praktikabel): SHA256 Trainings-/Testdaten, Git
# Commit, R-Version, Config-Hash, Resampling-Hash, Feature-Set-Bezeichnung
# oder Hash, Modellartefakt-Checksumme, Environment-/Paketreferenz.
#
# Baut bewusst auf der BESTEHENDEN `run_config`-EAV-Tabelle auf
# (`db_log_run_config()` in db_logging.R) statt eines neuen Schemas -
# Provenienzwerte sind konzeptionell zusaetzliche Konfigurationswerte
# EINES Runs (im Gegensatz zur P1.2-Evidence-Registry, die bewusst KEINEN
# Run-Bezug hat). Git Commit ist bereits ueber `run_git_commit`
# (`get_git_commit()`, db_logging.R) abgedeckt - hier nicht dupliziert.
#
# "Wenn praktikabel" wird woertlich genommen: jeder Parameter ist
# optional, `NULL` heisst "hier nicht anwendbar", kein Fehler. Config wird
# bewusst GEHASHT statt im Klartext geloggt (kann sensible lokale Pfade
# enthalten) - der Hash beantwortet trotzdem "hat sich die Config zwischen
# zwei Runs geaendert?", ohne den Inhalt preiszugeben.

#' SHA256-Hash einer Datei, oder NA, wenn `path` NULL/nicht vorhanden ist.
sha256_file <- function(path) {
  if (is.null(path) || !file.exists(path)) return(NA_character_)
  digest::digest(file = path, algo = "sha256")
}

#' SHA256-Hash eines beliebigen R-Objekts (ueber dessen Serialisierung),
#' oder NA, wenn `x` NULL ist.
hash_value <- function(x) {
  if (is.null(x)) return(NA_character_)
  digest::digest(x, algo = "sha256")
}

#' Baut eine benannte Liste mit Provenienz-Werten fuer einen Lauf, direkt
#' an `db_log_run_config()` uebergebbar (Schluesselpraefix `provenance.`
#' vermeidet Kollisionen mit regulaeren `000_config.R`-Config-Keys in
#' derselben `run_config`-Tabelle).
#'
#' @param train_data_path,test_data_path Pfad zu den fuer diesen Lauf
#'   verwendeten Trainings-/Testdaten-Dateien (SHA256 wird berechnet).
#' @param config_env Environment ODER benannte Liste mit den relevanten
#'   `000_config.R`-Werten (z.B. `mget(config_keys, envir = .GlobalEnv)`) -
#'   wird GEHASHT, nicht im Klartext gespeichert.
#' @param resampling Ein instanziiertes mlr3-`Resampling`-Objekt (dessen
#'   tatsaechliche Fold-Zuweisungen gehasht werden, nicht das R6-Objekt
#'   selbst - das waere wegen interner Env-Referenzen nicht reproduzierbar
#'   hashbar) ODER ein beliebiges anderes Objekt, das direkt gehasht wird.
#' @param feature_set Entweder die Bezeichnung des Feature-Sets (einzelner
#'   String, z.B. "raw") - wird als Klartext geloggt - ODER ein Vektor
#'   tatsaechlicher Spaltennamen, der stattdessen gehasht wird.
#' @param model_artifact_path Pfad zu einer gespeicherten Modell-Datei
#'   (z.B. `.rds`) - SHA256 wird berechnet.
#' @param packages Paketnamen, deren installierte Version mitgeloggt wird
#'   (Environment-/Paketreferenz-Feld des Plans).
#' @return Benannte Liste (Praefix `provenance.*`), geeignet fuer
#'   `db_log_run_config(con, run_id, provenance)`.
capture_run_provenance <- function(train_data_path = NULL, test_data_path = NULL,
                                    config_env = NULL, resampling = NULL,
                                    feature_set = NULL, model_artifact_path = NULL,
                                    packages = c(
                                      "mlr3", "mlr3learners", "mlr3extralearners",
                                      "mlr3pipelines", "ranger", "lightgbm"
                                    )) {
  provenance <- list()

  if (!is.null(train_data_path)) {
    provenance[["provenance.train_data_sha256"]] <- sha256_file(train_data_path)
  }
  if (!is.null(test_data_path)) {
    provenance[["provenance.test_data_sha256"]] <- sha256_file(test_data_path)
  }
  if (!is.null(config_env)) {
    as_list <- if (is.environment(config_env)) as.list(config_env) else config_env
    as_list <- as_list[order(names(as_list))] # Environments haben keine garantierte Reihenfolge - sortieren fuer einen von der Eingabeform (Env vs. Liste) unabhaengigen Hash
    provenance[["provenance.config_hash"]] <- hash_value(as_list)
  }
  if (!is.null(resampling)) {
    if (inherits(resampling, "Resampling")) {
      folds <- lapply(seq_len(resampling$iters), function(i) {
        list(train = resampling$train_set(i), test = resampling$test_set(i))
      })
      provenance[["provenance.resampling_hash"]] <- hash_value(folds)
    } else {
      provenance[["provenance.resampling_hash"]] <- hash_value(resampling)
    }
  }
  if (!is.null(feature_set)) {
    if (is.character(feature_set) && length(feature_set) == 1) {
      provenance[["provenance.feature_set"]] <- feature_set
    } else {
      provenance[["provenance.feature_set_hash"]] <- hash_value(feature_set)
    }
  }
  if (!is.null(model_artifact_path)) {
    provenance[["provenance.model_artifact_sha256"]] <- sha256_file(model_artifact_path)
  }

  provenance[["provenance.r_version"]] <- R.version.string
  pkg_versions <- vapply(packages, function(p) {
    v <- tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_)
    if (is.na(v)) NA_character_ else paste0(p, "=", v)
  }, character(1))
  provenance[["provenance.packages"]] <- paste(pkg_versions[!is.na(pkg_versions)], collapse = ", ")

  provenance
}
