# =====================================================================
# agridatasets_pilot.R -- reproduzierbarer Domain-Quelle-Pilot
#
# Der Pilot nutzt idn_rice_farms als Classification-Fixture. Er prueft
# bewusst nur Verfuegbarkeit, Schema und Zielvariable; er behauptet keinen
# generischen Nutzen fuer Wetteranreicherung ohne raumzeitlichen Schluessel.
# =====================================================================

source(file.path("modules", "agridatasets_adapter.R"))

if (!agridatasets_available("0.1.1")) {
  stop("Pilot benoetigt optional agridatasets >= 0.1.1.", call. = FALSE)
}

rice_farms <- load_agridatasets_dataset("idn_rice_farms")
validate_external_join_key(rice_farms, "status", "idn_rice_farms")

cat("agridatasets pilot: idn_rice_farms\n")
cat("Beobachtungen:", nrow(rice_farms), "\n")
cat("Variablen:", ncol(rice_farms), "\n")
cat("Zielvariable: status\n")
cat("Klassen:", paste(sort(unique(rice_farms$status)), collapse = ", "), "\n")
cat("Aussage: geeignet als optionale Agrar-Fixture; keine Wetteranreicherung ohne expliziten Orts-/Zeit-Schluessel.\n")
