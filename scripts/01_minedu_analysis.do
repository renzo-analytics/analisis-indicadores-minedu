*------------------------------------------------------------------
* Proyecto: Análisis de Indicadores MINEDU
* Autor: Renzo Cortez
* Objetivo: construir un indicador de cumplimiento y analizar
* diferencias entre UGEL según nivel de desempeño
*------------------------------------------------------------------

* Limpia todo lo que está cargado en memoria
clear all

* Evita que Stata pause la ejecución mostrando "more"
set more off


*--------------------------------------------------
* 1. Definir carpeta de trabajo
*--------------------------------------------------

* Aquí le dices a Stata en qué carpeta están tus archivos .dta
* Debes cambiar esta ruta por la ubicación real en tu computadora
cd "C:\Users\USER\Downloads"

* Crea una carpeta llamada "processed" si todavía no existe
* Aquí se guardarán bases intermedias
capture mkdir "processed"

* Crea una carpeta llamada "graphs" si todavía no existe
* Aquí se guardarán los gráficos exportados
capture mkdir "graphs"


*--------------------------------------------------
* 2. Instalar paquete necesario
*--------------------------------------------------

* Intenta instalar el paquete mdesc
* Sirve para revisar valores perdidos (missing values)
* "capture" evita que el script se detenga si ya está instalado
capture ssc install mdesc


*--------------------------------------------------
* 3. Cargar base principal
*--------------------------------------------------

* Abre la base principal donde están los datos de cumplimiento
use "cumplimiento.dta", clear


*--------------------------------------------------
* 4. Revisión inicial de calidad de datos
*--------------------------------------------------

* Muestra cuántos valores perdidos hay por variable
mdesc

* Revisa si hay unidades ejecutoras duplicadas
duplicates report unidad_ejec

* Revisa si hay ids duplicados
duplicates report id

* Busca todas las variables cuyo nombre siga el patrón tram*_c*_cump
* Es decir, variables de cumplimiento por tramo
ds tram*_c*_cump

* Recorre cada variable encontrada y muestra su distribución
* Esto sirve para detectar valores raros o inconsistencias
foreach var of varlist tram*_c*_cump {
    tab `var'
}


*--------------------------------------------------
* 5. Construcción del indicador de cumplimiento
*--------------------------------------------------

* Suma las metas cumplidas en los tres tramos
gen total_met = tram1_CdD_cump + tram2_CdD_cump + tram3_CdD_cump

* Suma el número total de metas evaluadas en los tres tramos
gen total_num = tram1_CdD_num + tram2_CdD_num + tram3_CdD_num

* Calcula el indicador total en porcentaje
* Solo se calcula si el denominador es mayor que cero
gen indicador_total = (total_met / total_num) * 100 if total_num > 0

* Muestra estadísticas descriptivas del indicador
* Por ejemplo: promedio, desviación estándar, mínimo y máximo
summ indicador_total


*--------------------------------------------------
* 6. Clasificación del nivel de cumplimiento
*--------------------------------------------------

* Crea una variable de categoría:
* 1 = bajo cumplimiento
gen nivel_cumplimiento = 1 if indicador_total <= 75

* 2 = cumplimiento medio
replace nivel_cumplimiento = 2 if indicador_total > 75 & indicador_total <= 90

* 3 = alto cumplimiento
replace nivel_cumplimiento = 3 if indicador_total > 90

* Define etiquetas legibles para esas categorías
label define niv 1 "Bajo" 2 "Medio" 3 "Alto"

* Asigna esas etiquetas a la variable
label values nivel_cumplimiento niv

* Muestra cuántas observaciones hay en cada nivel
tab nivel_cumplimiento


*--------------------------------------------------
* 7. Guardar una base resumida de unidades ejecutoras
*--------------------------------------------------

* Conserva solo las variables clave para el siguiente paso
keep unidad_ejec REGION estrato indicador_total nivel_cumplimiento

* Guarda esta base intermedia
* Luego se usará para enlazar la información con UGEL
save "processed/ue_nivel.dta", replace


*--------------------------------------------------
* 8. Relacionar Unidades Ejecutoras con UGEL
*--------------------------------------------------

* Abre la base que contiene el código de UGEL asociado
use "cod_ugel.dta", clear

* Elimina registros donde falta el código de UGEL
drop if missing(CODUGEL)

* Une esta base con la base resumida creada antes
* m:1 significa muchas filas de esta base se unen con una fila de la base using
* La llave de unión es unidad_ejec
merge m:1 unidad_ejec using "processed/ue_nivel.dta"

* Revisa el resultado del merge
tab _merge

* Conserva solo los casos emparejados en ambas bases
keep if _merge==3

* Elimina la variable técnica del merge
drop _merge

* Guarda esta nueva base intermedia
save "processed/ugel_con_nivel_ue.dta", replace


*--------------------------------------------------
* 9. Añadir características de las UGEL
*--------------------------------------------------

* Manteniendo la base anterior cargada, se une con la base de características UGEL
* La llave ahora es CODUGEL
merge m:1 CODUGEL using "base_ugel.dta"

* Revisa el resultado del merge
tab _merge

* Conserva solo coincidencias válidas
keep if _merge==3

* Elimina la variable técnica del merge
drop _merge

* Guarda la base final analítica
save "processed/ugel_con_caracteristicas.dta", replace


*--------------------------------------------------
* 10. Renombrar variables para hacerlas más entendibles
*--------------------------------------------------

* Variables de recursos administrativos
rename Q_UGEL_PERS personal_ugel
rename Q_UGEL_COMP_FUNC computadoras_func
rename Q_UGEL_COMP_FUNC_I computadoras_internet
rename Q_UGEL_RED_FUNC red_funcionarios
rename Q_UGEL_VTM_FUNC vehiculos_func
rename Q_UGEL_MOB_FUNC motos_func

* Variables de matrícula y docentes
rename Q_MATRÍCULA_EBR matricula_ebr
rename Q_DOCENTES_EBR docentes_ebr
rename P_MATRÍCULA_EBR_URB matricula_urbana
rename P_DOCENTES_EBR_URB docentes_urbanos
rename P_IIEE_EBR_URB escuelas_urbanas

* Variables de infraestructura y servicios
rename P_IIEE_3_SERVICIOS escuelas_servicios
rename P_IIEE_COMP_INTRNT escuelas_internet
rename P_IIEE_BIBLIOTECA escuelas_biblioteca
rename P_IIEE_RP_LUZ escuelas_luz
rename P_IIEE_RP_AGUA escuelas_agua
rename P_IIEE_RP_DESAGÜE escuelas_desague


*--------------------------------------------------
* 11. Análisis descriptivo por nivel de cumplimiento
*--------------------------------------------------

* Compara recursos administrativos entre UGEL de bajo, medio y alto cumplimiento
* Muestra promedio, desviación estándar, mediana, mínimo, máximo y número de casos
tabstat personal_ugel computadoras_func computadoras_internet ///
red_funcionarios vehiculos_func motos_func, ///
by(nivel_cumplimiento) stat(mean sd p50 min max n)

* Compara variables educativas entre niveles de cumplimiento
tabstat matricula_ebr docentes_ebr matricula_urbana ///
docentes_urbanos escuelas_urbanas, ///
by(nivel_cumplimiento) stat(mean sd p50 n)

* Compara variables de infraestructura escolar entre niveles
tabstat escuelas_servicios escuelas_internet ///
escuelas_biblioteca escuelas_luz escuelas_agua ///
escuelas_desague, ///
by(nivel_cumplimiento) stat(mean sd p50 n)


*--------------------------------------------------
* 12. Análisis regional
*--------------------------------------------------

* Muestra cuántas UGEL de cada nivel hay por región
tab REGION nivel_cumplimiento

* Calcula promedio y dispersión del indicador por región
tabstat indicador_total, by(REGION) stat(mean sd n)


*--------------------------------------------------
* 13. Gráficos
*--------------------------------------------------

* Gráfico de barras horizontales:
* muestra el cumplimiento promedio por región
graph hbar (mean) indicador_total, over(REGION) ///
title("Cumplimiento promedio por region")

* Exporta el gráfico como imagen PNG a la carpeta graphs
graph export "graphs/cumplimiento_region.png", replace

* Histograma:
* muestra la distribución del indicador de cumplimiento
histogram indicador_total, width(5) percent ///
title("Distribucion del indicador de cumplimiento")

* Exporta el histograma como imagen PNG
graph export "graphs/distribucion_indicador.png", replace

