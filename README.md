# Corrección del Data Drift en Variables Monetarias

**Grupo B · Problema #02 · Laboratorio de Implementación I (Universidad Austral, 2026) · Modalidad Junior**

Estudio del efecto de aplicar técnicas de corrección del data drift sobre variables monetarias y su impacto en el desempeño de un modelo LightGBM.

## Pregunta de investigación

¿Qué efecto tiene la aplicación de técnicas de corrección del data drifting sobre variables monetarias en el desempeño del modelo?

## Objetivo

Evaluar si corregir el desplazamiento de las distribuciones de las 25 variables monetarias mejora el desempeño predictivo frente a conservar sus valores originales, comparando dos correcciones (deflación por IPC y Rank Simple) contra un escenario sin corrección.

## Diseño experimental

- 4 condiciones × 10 semillas = **40 corridas**, todas sobre el mismo mes de evaluación (`future = 202107`; entrenamiento hasta 202103, validación 202105).
- Mismo workflow en todas las corridas; solo cambian 3 líneas (`semilla_primigenia`, `experimento`, `DR$metodo`). Los hiperparámetros de LightGBM se buscan desde cero en cada corrida con optimización bayesiana.
- Las semillas fijan solo la aleatoriedad del algoritmo; el mes evaluado es siempre el mismo (244 clientes BAJA+2).
- Ganancia real calculada en el propio notebook: BAJA+2 = +975.000, resto = −25.000.
- Métrica primaria: media de la ganancia suavizada entre 1500 y 2500 envíos.

| Carpeta | Tratamiento | Experimentos |
|---|---|---|
| ninguno | Sin corrección (control) | WF9210–9219 |
| deflacion | Valores × (IPC dic-2020 / IPC del mes) | WF9200–9209 |
| rank_simple | Posición relativa dentro del mes, en [0, 1] | WF9220–9229 |
| sin_monetarias | **Ablación**: se eliminan las 25 variables monetarias (y sus lags/deltas) | WF9230–9239 |

La ablación no es un cuarto tratamiento de corrección: mide cuánto aporta el bloque monetario.

## Evaluación

- Distancia de Kolmogorov–Smirnov (KS) entre distribuciones (entrenamiento vs. 202107).
- Ganancia del modelo (métrica primaria y métricas de robustez).
- Prueba de Wilcoxon pareada por semilla, con corrección de Holm (3 comparaciones).
- Intervalos de confianza del 95 % (bootstrap y t pareada).
- Importancia de variables (Gain) del bloque monetario.

## Resultados principales

![Ganancia por método](resultados/figuras/fig1_ganancia_por_metodo.png)

1. **La deflación redujo el drift en la mayoría de las variables.** La mediana del KS pasó de 0,127 (nominal) a 0,050. Bajó en 18 de 25 variables y subió en 7 (entre ellas, cuatro límites de compra/financiación Visa/Mastercard, de ~0,09 a ~0,18). Que sean nominalmente rígidos es solo una hipótesis.
2. **No se detectó mejora significativa de la ganancia.**
   - Deflación: +0,54 M frente al control, mejor en 4 de 10 semillas, Wilcoxon p = 1,00; IC 95 % de −1,4 a +2,5 M.
   - Rank Simple: −0,96 M, p = 0,23.
   - Los intervalos incluyen efectos positivos y negativos: no se puede afirmar ni que la deflación mejore ni que su efecto sea exactamente nulo.
3. **Las variables monetarias aportan información.** Representan 46,4 % del Gain sin corrección (47,7 % con deflación, 46,4 % con Rank Simple). Quitarlas (ablación) bajó la ganancia 9,11 M (≈10 %) en 10 de 10 semillas (p = 0,002; Holm p = 0,006).

![Efecto frente al control](resultados/figuras/fig2_efecto_vs_control.png)

## Conclusiones

En las condiciones evaluadas, la deflación por IPC redujo la distancia entre distribuciones en la mayoría de las variables monetarias, pero eso no se tradujo en una mejora estadísticamente significativa de la ganancia; Rank Simple tampoco mostró mejora significativa. La ablación indica que el bloque monetario contiene información predictiva relevante. Reducir el drift y conservar capacidad predictiva son objetivos relacionados, pero no equivalentes.

## Limitaciones

- Un solo mes de evaluación (202107) y un solo dataset: no se generaliza automáticamente a otros períodos.
- 10 repeticiones: con 10 pares el menor p posible de Wilcoxon bilateral es ≈ 0,002; la evidencia debe leerse con ese tamaño muestral.
- Las semillas varían el algoritmo, no los datos: la inferencia es sobre la variabilidad del entrenamiento.
- Menor KS no garantiza mayor ganancia.
- Las explicaciones de los resultados (p. ej., por qué los árboles no se benefician de la deflación) son hipótesis, no resultados demostrados.
- Rank Simple: los empates se resuelven al azar y N incluye valores faltantes (ver informe).
- La ablación usa otra rama del notebook (cambio deliberado y documentado).

## Reproducibilidad

1. Clonar este repositorio.
2. Obtener el dataset de la materia y ubicarlo según `data/README.md`.
3. Instalar en R: `data.table`, `lightgbm`, `rlist`, `jsonlite`, entre otros usados por el notebook, y Jupyter con kernel R.
4. Ajustar rutas (`RUTA_BASE`, `NOTEBOOK`) en `src/ejecucion/*.R`.
5. Ejecutar `src/ejecucion/z621_correr_todo_grupoB.R` (30 corridas) y luego `z621_correr_sinmonetarias_grupoB.R` (10 corridas). Cada corrida escribe sus resultados en `WF<id>/`; las ya terminadas se omiten.



## Estructura

```
src/workflow/    notebooks (base y rama sin_monetarias)
src/ejecucion/   scripts que corren las 40 corridas
resultados/      figuras
docs/            informe completo
data/            vacío (solo README)
```

## Tecnologías y métodos

- Lenguaje: R (data.table), Jupyter
- Modelo: LightGBM con optimización bayesiana
- Técnicas: deflación por IPC, Rank Simple, ablación
- Evaluación: KS, ganancia, Wilcoxon + Holm, IC 95 %, importancia por Gain
