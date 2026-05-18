version 16.0
clear all
set more off

* ---------------------------------------------------------------
* Russell Group administrative/academic staff ratio bar chart
*
* Input:
* - HESA/REF university-year panel created by ukhe_data_construction.do
*
* Output:
* - PDF horizontal bar chart of non-academic administrative staff FTE
*   divided by academic staff FTE for Russell Group universities.
* - By default the script uses the latest academic year in the data.
* ---------------------------------------------------------------

local user = c(username)
local data_root "/Users/`user'/Dropbox/Akos/ukhe_data"
local hesa_dir "`data_root'/hesa"
local out_dir "`hesa_dir'/outputs"
local in_dta "`out_dir'/ukhe_data.dta"

* Set this to a specific start year, e.g. 2023 for 2023/24.
* Leave missing to use the latest available year.
local chart_year .

capture mkdir "`out_dir'"

capture confirm file "`in_dta'"
if _rc {
    di as error "Missing input file: `in_dta'"
    di as error "Run scripts/ukhe_data_construction.do first."
    exit 601
}

use "`in_dta'", clear

foreach v in university_name russellgroup year academicyear ///
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

* Keep Russell Group universities. This handles either string or numeric flags.
capture confirm string variable russellgroup
if !_rc {
    replace russellgroup = strtrim(russellgroup)
    keep if inlist(strlower(russellgroup), "yes", "y", "1", "true", "russell group")
}
else {
    keep if russellgroup == 1
}

drop if missing(admin_academic_staff_ratio)

if `chart_year' == . {
    quietly summarize year, meanonly
    local chart_year = r(max)
}

keep if year == `chart_year'
count
if r(N) == 0 {
    di as error "No Russell Group observations found for year `chart_year'."
    exit 2000
}

quietly summarize admin_academic_staff_ratio, meanonly
local rg_mean = r(mean)
local rg_mean_label : display %4.2f `rg_mean'

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
    xline(`rg_mean', lcolor(maroon) lpattern(dash)) ///
    xtitle("Administrative/non-academic staff per academic staff FTE") ///
    ytitle("") ///
    ylabel(`ylabels', angle(horizontal) labsize(vsmall) noticks) ///
    yscale(reverse) ///
    xlabel(, grid) ///
    title("Russell Group admin/academic staff ratio, `=academicyear[1]'") ///
    note("Dashed line shows Russell Group mean: `rg_mean_label'. Source: HESA Table 11 staff FTE via ukhe_data.dta.", ///
         size(vsmall)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s2color) ///
    name(rg_admin_academic_staff_ratio, replace)

graph export "`out_dir'/russell_group_admin_academic_staff_ratio_`chart_year'.pdf", replace

di as result "Created Russell Group admin/academic staff ratio chart for `=academicyear[1]':"
di as result " - `out_dir'/russell_group_admin_academic_staff_ratio_`chart_year'.pdf"
