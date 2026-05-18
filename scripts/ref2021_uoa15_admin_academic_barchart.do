version 16.0
clear all
set more off

* ---------------------------------------------------------------
* Administrative/academic staff ratio bar chart for institutions
* with REF2021 submissions in at least 20 units of assessment.
*
* Inputs:
* - HESA/REF university-year panel created by ukhe_data_construction.do
* - REF2021 source folder used by the construction script:
*   ~/Dropbox/Akos/ukhe_data/ref2021/
*
* Output:
* - PDF horizontal bar chart of non-academic administrative staff FTE
*   divided by academic staff FTE.
* - By default the script uses the latest academic year in the data.
* ---------------------------------------------------------------

local user = c(username)
local data_root "/Users/`user'/Dropbox/Akos/ukhe_data"
local hesa_dir "`data_root'/hesa"
local ref_dir "`data_root'/ref2021"
local out_dir "`hesa_dir'/outputs"
local in_dta "`out_dir'/ukhe_data.dta"
local ref_dta "`ref_dir'/ref2021_the_overall_table.dta"

* Set this to a specific start year, e.g. 2023 for 2023/24.
* Leave missing to use the latest available year.
local chart_year .

capture mkdir "`out_dir'"

foreach f in "`in_dta'" "`ref_dta'" {
    capture confirm file "`f'"
    if _rc {
        di as error "Missing required input file: `f'"
        exit 601
    }
}

use "`in_dta'", clear

foreach v in university_name ref2021_n_uoas year academicyear ///
    total_administrative_staff total_academic_staff {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable: `v'"
        exit 111
    }
}

gen double admin_academic_staff_ratio = ///
    total_administrative_staff / total_academic_staff if total_academic_staff > 0
label variable admin_academic_staff_ratio ///
    "Administrative/non-academic staff per academic staff FTE"

keep if ref2021_n_uoas >= 20
drop if missing(admin_academic_staff_ratio)

if `chart_year' == . {
    quietly summarize year, meanonly
    local chart_year = r(max)
}

keep if year == `chart_year'
count
if r(N) == 0 {
    di as error "No institutions with at least 20 REF2021 UoA submissions found for year `chart_year'."
    exit 2000
}

quietly summarize admin_academic_staff_ratio, meanonly
local ref20_mean = r(mean)
local ref20_mean_label : display %4.2f `ref20_mean'

gsort -admin_academic_staff_ratio university_name
gen int sort_order = _n
gen str80 chart_university_name = university_name
replace chart_university_name = "Imperial College London" ///
    if university_name == "Imperial College of Science, Technology and Medicine"
replace chart_university_name = "London Shcool of Economics" ///
    if university_name == "London School of Economics and Political Science"

local ylabels ""
forvalues i = 1/`=_N' {
    local label = chart_university_name[`i']
    local ylabels `"`ylabels' `i' "`label'""'
}

twoway ///
    (bar admin_academic_staff_ratio sort_order ///
        if university_name != "The University of Manchester", ///
        horizontal color(navy%75) barwidth(0.72)) ///
    (bar admin_academic_staff_ratio sort_order ///
        if university_name == "The University of Manchester", ///
        horizontal color(cranberry) barwidth(0.72)) ///
    , ///
    xline(`ref20_mean', lcolor(maroon) lpattern(dash)) ///
    xtitle("Administrative/non-academic staff per academic staff FTE") ///
    ytitle("") ///
    ylabel(`ylabels', angle(horizontal) labsize(tiny) noticks) ///
    yscale(reverse) ///
    xlabel(, grid) ///
    title("Admin/academic staff ratio, REF2021 20+ UoAs, `=academicyear[1]'", ///
          size(medsmall)) ///
    note("Dashed line: 20+ UoA mean = `ref20_mean_label'. Source: HESA T11 and REF2021.", ///
         size(vsmall)) ///
    legend(off) ///
    xsize(13) ysize(11) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s2color) ///
    name(ref20_ratio, replace)

graph export "`out_dir'/ref2021_uoa20_admin_academic_staff_ratio_`chart_year'.pdf", replace

di as result "Created admin/academic staff ratio chart for REF2021 institutions with 20+ UoAs in `=academicyear[1]':"
di as result " - `out_dir'/ref2021_uoa20_admin_academic_staff_ratio_`chart_year'.pdf"
