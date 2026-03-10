*------------------------------------------------------------------
* Proyecto: Análisis de Indicadores MINEDU
* Autor: Renzo Cortez
*------------------------------------------------------------------

clear all
set more off

*--------------------------------------------------
* 1. Definir rutas del proyecto
*--------------------------------------------------

global raw    "../data/raw"
global proc   "../data/processed"
global out    "../outputs"

*--------------------------------------------------
* 2. Instalar paquetes necesarios
*--------------------------------------------------

capture ssc install mdesc

*--------------------------------------------------
* 3. Cargar base principal
*--------------------------------------------------

use "$raw/cumplimiento.dta", clear

*--------------------------------------------------
* 4. Revisión de calidad de datos
*--------------------------------------------------

* Missing values
mdesc

* Duplicados
duplicates report unidad_ejec
duplicates report id

* Revisar variables de cumplimiento
ds tram*_c*_cump

foreach var of varlist tram*_c*_cump {
    tab `var'
}

*--------------------------------------------------
* 5. Construcción del indicador de cumplimiento
*--------------------------------------------------

gen total_met = tram1_CdD_cump + tram2_CdD_cump + tram3_CdD_cump
gen total_num = tram1_CdD_num + tram2_CdD_num + tram3_CdD_num

gen indicador_total = (total_met / total_num) * 100 if total_num>0

summ indicador_total

*--------------------------------------------------
* 6. Segmentación del indicador
*--------------------------------------------------

gen nivel_cumplimiento = 1 if indicador_total <= 75
replace nivel_cumplimiento = 2 if indicador_total > 75 & indicador_total <= 90
replace nivel_cumplimiento = 3 if indicador_total > 90

label define niv 1 "Bajo" 2 "Medio" 3 "Alto"
label values nivel_cumplimiento niv

tab nivel_cumplimiento

keep unidad_ejec REGION estrato indicador_total nivel_cumplimiento

save "$proc/ue_nivel.dta", replace

*--------------------------------------------------
* 7. Pasar nivel de UE a UGEL
*--------------------------------------------------

use "$raw/cod_ugel.dta", clear

drop if missing(CODUGEL)

merge m:1 unidad_ejec using "$proc/ue_nivel.dta"

tab _merge
keep if _merge==3
drop _merge

save "$proc/ugel_con_nivel_ue.dta", replace

*--------------------------------------------------
* 8. Agregar características UGEL
*--------------------------------------------------

use "$proc/ugel_con_nivel_ue.dta", clear

merge m:1 CODUGEL using "$raw/base_ugel.dta"

tab _merge
keep if _merge==3
drop _merge

save "$proc/ugel_con_caracteristicas.dta", replace

*--------------------------------------------------
* 9. Renombrar variables
*--------------------------------------------------

rename Q_UGEL_PERS personal_ugel
rename Q_UGEL_COMP_FUNC computadoras_func
rename Q_UGEL_COMP_FUNC_I computadoras_internet
rename Q_UGEL_RED_FUNC red_funcionarios
rename Q_UGEL_VTM_FUNC vehiculos_func
rename Q_UGEL_MOB_FUNC motos_func

rename Q_MATRÍCULA_EBR matricula_ebr
rename Q_DOCENTES_EBR docentes_ebr
rename P_MATRÍCULA_EBR_URB matricula_urbana
rename P_DOCENTES_EBR_URB docentes_urbanos
rename P_IIEE_EBR_URB escuelas_urbanas

rename P_IIEE_3_SERVICIOS escuelas_servicios
rename P_IIEE_COMP_INTRNT escuelas_internet
rename P_IIEE_BIBLIOTECA escuelas_biblioteca
rename P_IIEE_RP_LUZ escuelas_luz
rename P_IIEE_RP_AGUA escuelas_agua
rename P_IIEE_RP_DESAGÜE escuelas_desague

*--------------------------------------------------
* 10. Análisis descriptivo
*--------------------------------------------------

tabstat personal_ugel computadoras_func computadoras_internet ///
red_funcionarios vehiculos_func motos_func, ///
by(nivel_cumplimiento) stat(mean sd p50 min max n)

tabstat matricula_ebr docentes_ebr matricula_urbana ///
docentes_urbanos escuelas_urbanas, ///
by(nivel_cumplimiento) stat(mean sd p50 n)

tabstat escuelas_servicios escuelas_internet ///
escuelas_biblioteca escuelas_luz escuelas_agua ///
escuelas_desague, ///
by(nivel_cumplimiento) stat(mean sd p50 n)

*--------------------------------------------------
* 11. Análisis por región
*--------------------------------------------------

tab REGION nivel_cumplimiento

tabstat indicador_total, by(REGION) stat(mean sd n)

*--------------------------------------------------
* 12. Gráficos
*--------------------------------------------------

graph hbar (mean) indicador_total, over(REGION) ///
title("Cumplimiento promedio por región")

graph export "$out/graphs/cumplimiento_region.png", replace