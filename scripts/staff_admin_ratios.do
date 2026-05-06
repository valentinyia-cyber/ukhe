version 16.0
clear all
set more off

* ---------------------------------------------------------------
*  staff administration ratios by university-year
*
* Inputs:
* - HESA T11 staff FTE converted file
* - HESA T01 students converted file
* - REF2021 THE-style overall table from ref2021_the_replication.do
*
* Output:
* - One observation per year per university
* - Restricted to REF2021 institutions with more than one submitted UoA
* ---------------------------------------------------------------

local hesa_dir "/Users/user/Dropbox/Akos/ukhe_data/hesa"
local dta_dir "`hesa_dir'/dta"
local ref_dir "/Users/user/Dropbox/Akos/ukhe_data/ref2021"
local out_dir "`hesa_dir'/outputs"
capture mkdir "`out_dir'"

local staff_dta "`dta_dir'/T11_staff_fte.dta"
local students_dta "`dta_dir'/T01_students.dta"
local ref_dta "`ref_dir'/ref2021_the_overall_table.dta"

foreach f in "`staff_dta'" "`students_dta'" "`ref_dta'" {
    capture confirm file "`f'"
    if _rc {
        di as error "Missing required input file: `f'"
        exit 601
    }
}

tempfile staff_wide students_wide ref2021

* ---------------------------------------------------------------
* Staff FTE measures from HESA Table 11.
* Use provider-total rows only: country/region rollups otherwise repeat
* the same institution-year values.
* ---------------------------------------------------------------
use "`staff_dta'", clear
keep if countryofheprovider == "All" & regionofheprovider == "All"

keep ukprn ref2021_institution_name n_ref2021_uoas heprovider ///
     russellgroup year academicyear contractmarker categorymarker category value

gen str20 staff_measure = ""
replace staff_measure = "acad_staff" ///
    if contractmarker == "Academic (including atypical)" ///
    & categorymarker == "Cost centre" ///
    & category == "Total all cost centres"
replace staff_measure = "admin_staff" ///
    if contractmarker == "Non-academic" ///
    & categorymarker == "Cost centre" ///
    & category == "Total all cost centres"
replace staff_measure = "central_admin_staff" ///
    if contractmarker == "Non-academic" ///
    & categorymarker == "Cost centre" ///
    & category == "Central administration & services"

keep if staff_measure != ""
collapse (max) value, ///
    by(ukprn ref2021_institution_name n_ref2021_uoas heprovider ///
       russellgroup year academicyear staff_measure)
reshape wide value, ///
    i(ukprn ref2021_institution_name n_ref2021_uoas heprovider ///
      russellgroup year academicyear) ///
    j(staff_measure) string

rename valuecentral_admin_staff central_admin_services_staff
rename valueacad_staff total_academic_staff
rename valueadmin_staff total_administrative_staff

gen double admin_academic_staff_ratio = ///
    total_administrative_staff / total_academic_staff if total_academic_staff > 0
gen double central_admin_staff_ratio = ///
    central_admin_services_staff / total_academic_staff if total_academic_staff > 0

label variable total_academic_staff "Total academic staff FTE, including atypical"
label variable total_administrative_staff "Total administrative/non-academic staff FTE"
label variable central_admin_services_staff "Non-academic staff FTE in central administration & services"
label variable admin_academic_staff_ratio "Administrative/non-academic staff to academic staff ratio"
label variable central_admin_staff_ratio "Central administration & services staff to academic staff ratio"

save "`staff_wide'", replace

* ---------------------------------------------------------------
* Student totals from HESA Table 1.
* ---------------------------------------------------------------
use "`students_dta'", clear
keep if countryofheprovider == "All" & regionofheprovider == "All"
keep if entrantmarker == "All"
keep if modeofstudy == "All" & categorymarker == "Total" & category == "Total"
keep if inlist(levelofstudy, "All", "All undergraduate")

gen str24 student_measure = ""
replace student_measure = "total_students" if levelofstudy == "All"
replace student_measure = "total_ug_students" if levelofstudy == "All undergraduate"

keep ukprn year student_measure value
collapse (max) value, by(ukprn year student_measure)
reshape wide value, i(ukprn year) j(student_measure) string

rename valuetotal_students total_students
rename valuetotal_ug_students total_ug_students
label variable total_students "Total student number"
label variable total_ug_students "Total undergraduate student number"

save "`students_wide'", replace

* ---------------------------------------------------------------
* REF2021 average GPA and >1 UoA restriction.
* ---------------------------------------------------------------
use "`ref_dta'", clear
keep ukprn institution_name n_uoas gpa
keep if n_uoas > 1
rename institution_name ref2021_name_from_gpa
rename n_uoas ref2021_n_uoas
rename gpa average_gpa
label variable average_gpa "Average GPA from REF2021 THE-style replication"
label variable ref2021_n_uoas "Number of REF2021 UoAs submitted"
save "`ref2021'", replace

* ---------------------------------------------------------------
* Final university-year panel.
* ---------------------------------------------------------------
use "`staff_wide'", clear
merge 1:1 ukprn year using "`students_wide'", keep(match) nogen
merge m:1 ukprn using "`ref2021'", keep(match) nogen

rename heprovider university_name
replace university_name = ref2021_institution_name if missing(university_name)

drop ref2021_name_from_gpa ref2021_institution_name n_ref2021_uoas
order ukprn university_name year academicyear russellgroup ref2021_n_uoas ///
      average_gpa total_ug_students total_students ///
      total_administrative_staff total_academic_staff ///
      admin_academic_staff_ratio central_admin_services_staff ///
      central_admin_staff_ratio

keep ukprn university_name year academicyear russellgroup ref2021_n_uoas ///
     average_gpa total_ug_students total_students ///
     total_administrative_staff total_academic_staff ///
     admin_academic_staff_ratio central_admin_services_staff ///
     central_admin_staff_ratio

sort ukprn year
isid ukprn year

label variable university_name "University name"
label variable russellgroup "Russell Group member"
label variable year "Academic year start year"
label variable academicyear "Academic year"

compress
save "`out_dir'/staff_admin_ratios.dta", replace
export delimited using "`out_dir'/staff_admin_ratios.csv", replace

count
di as result "Created `r(N)' university-year rows:"
di as result " - `out_dir'/staff_admin_ratios.dta"
di as result " - `out_dir'/staff_admin_ratios.csv"
