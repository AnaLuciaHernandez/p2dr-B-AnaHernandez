# z621_correr_todo_grupoB.R
#
# Corre, UNO DETRAS DE OTRO y sin que tengas que estar pendiente, todas las
# combinaciones  semilla x metodo  del notebook z621 (Grupo B, future = 202107).
#
# A cada corrida solo le cambia 3 lineas del notebook:
#   PARAM$semilla_primigenia, PARAM$experimento y PARAM$DR$metodo
#
# Orden: SEMILLA por SEMILLA (en cada semilla corre todos los metodos).
#   Asi, si te falta tiempo, los pares semilla-a-semilla ya estan completos
#   y el Wilcoxon se puede hacer con las semillas que alcanzaron.
#
# Si una carpeta WF<n> ya tiene ganancias.txt, la SALTA (podes relanzarlo sin miedo).
# Si una corrida falla, lo anota y SIGUE con la proxima.
#
# COMO LANZARLO (terminal de la VM, en la carpeta donde estan este script y el notebook):
#   nohup Rscript z621_correr_todo_grupoB.R > log_correr_todo.txt 2>&1 &
# Queda corriendo aunque cierres el navegador. Para ver como va:
#   tail -n 20 log_correr_todo.txt

if (!require("jsonlite")) install.packages("jsonlite")
require("jsonlite")

# ---------------------------------------------------------------- PARAMETROS ----

# carpeta donde estan este script y el notebook
args_cmd <- commandArgs(trailingOnly = FALSE)
arg_file <- sub("^--file=", "", args_cmd[grepl("^--file=", args_cmd)])
carpeta_script <- if (length(arg_file) > 0) dirname(normalizePath(arg_file[1])) else getwd()

notebook <- file.path(carpeta_script, "z621_WorkFlow_01_junior_grupoB_1.ipynb")

carpeta_exp  <- "/content/buckets/b1/exp"            # donde el notebook crea WF<n>
carpeta_logs <- file.path(carpeta_exp, "CORRER_TODO_B")

# las 10 semillas del Grupo B (las MISMAS para todos los metodos)
semillas <- c(100103, 100109, 100129, 100151, 100153,
              101009, 101021, 101027, 101051, 101063)

# metodo -> primer numero de experimento (semilla 1 = base, semilla 2 = base+1, ...)
metodos <- c(
  ninguno     = 9210,
  deflacion   = 9200,
  rank_simple = 9220
  # sin_monetarias = 9230   # se agrega cuando este programado en el notebook
)

# TRUE = apaga la VM al terminar todo (ahorra plata)
apagar_vm_al_terminar <- FALSE

# -------------------------------------------------------------------- FUNCIONES ----

dir.create(carpeta_logs, showWarnings = FALSE, recursive = TRUE)
ahora <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")
msg <- function(...) cat("[", ahora(), "] ", ..., "\n", sep = "")

codigo_notebook <- function(ruta) {
  stopifnot(file.exists(ruta))
  nb <- fromJSON(ruta, simplifyVector = FALSE)
  celdas <- Filter(function(c) c$cell_type == "code", nb$cells)
  paste(vapply(celdas, function(c) paste(unlist(c$source), collapse = ""), character(1)),
    collapse = "\n\n")
}

# reemplaza con regex y EXIGE una sola coincidencia (si el notebook cambio, mejor frenar)
reemplazar_uno <- function(texto, patron, nuevo) {
  n <- lengths(regmatches(texto, gregexpr(patron, texto, perl = TRUE)))
  if (n != 1) stop("se esperaba 1 coincidencia y hubo ", n, " para: ", patron)
  sub(patron, nuevo, texto, perl = TRUE)
}

p_semilla <- "PARAM\\$semilla_primigenia <- [0-9]+"
p_exp     <- "PARAM\\$experimento <- [0-9]+"
p_metodo  <- "PARAM\\$DR\\$metodo <- \"[A-Za-z_]+\""

completo <- function(carpeta) file.exists(file.path(carpeta, "ganancias.txt"))

# -------------------------------------------------------------------- CORRIDA ----

codigo_base <- codigo_notebook(notebook)
# chequeo previo: las 3 lineas tienen que estar una sola vez
for (p in c(p_semilla, p_exp, p_metodo)) invisible(reemplazar_uno(codigo_base, p, "x"))

resumen <- data.frame()
total <- length(semillas) * length(metodos)
msg("inicio | ", length(semillas), " semillas x ", length(metodos), " metodos = ", total, " corridas")

hechas <- 0
for (i in seq_along(semillas)) {
  for (metodo in names(metodos)) {
    exp_n   <- metodos[[metodo]] + i - 1
    carpeta <- file.path(carpeta_exp, paste0("WF", exp_n))
    hechas  <- hechas + 1

    if (completo(carpeta)) {
      msg("[", hechas, "/", total, "] ", metodo, " semilla ", semillas[i], " (WF", exp_n, ") ya completa -> se salta")
      resumen <- rbind(resumen, data.frame(metodo = metodo, semilla = semillas[i],
        carpeta = paste0("WF", exp_n), estado = "ya estaba", minutos = NA, fin = ahora()))
      write.csv(resumen, file.path(carpeta_logs, "resumen_correr_todo.csv"), row.names = FALSE)
      next
    }

    msg("[", hechas, "/", total, "] ", metodo, " semilla ", semillas[i], " (WF", exp_n, ") empieza")
    t0 <- Sys.time()

    estado <- tryCatch({
      codigo <- codigo_base
      codigo <- reemplazar_uno(codigo, p_semilla, paste0("PARAM$semilla_primigenia <- ", semillas[i]))
      codigo <- reemplazar_uno(codigo, p_exp,     paste0("PARAM$experimento <- ", exp_n))
      codigo <- reemplazar_uno(codigo, p_metodo,  paste0("PARAM$DR$metodo <- \"", metodo, "\""))

      nombre <- paste0("WF", exp_n)
      script <- file.path(carpeta_logs, paste0("script_", nombre, ".R"))
      log    <- file.path(carpeta_logs, paste0("log_", nombre, ".txt"))
      writeLines(codigo, script, useBytes = TRUE)
      system2(file.path(R.home("bin"), "Rscript"), args = shQuote(script), stdout = log, stderr = log)
      if (completo(carpeta)) "ok" else "FALLO (no genero ganancias.txt, mira el log)"
    }, error = function(e) paste("ERROR:", conditionMessage(e)))

    minutos <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
    msg(metodo, " semilla ", semillas[i], ": ", estado, " en ", round(minutos, 1), " min")
    resumen <- rbind(resumen, data.frame(metodo = metodo, semilla = semillas[i],
      carpeta = paste0("WF", exp_n), estado = estado, minutos = round(minutos, 1), fin = ahora()))
    write.csv(resumen, file.path(carpeta_logs, "resumen_correr_todo.csv"), row.names = FALSE)
  }
}

msg("FIN | corridas ok: ", sum(resumen$estado %in% c("ok", "ya estaba")), " de ", total)

if (apagar_vm_al_terminar) {
  msg("apagando la VM en 2 minutos")
  Sys.sleep(120)
  system("sudo shutdown -h now")
}
