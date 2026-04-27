version 16.0
clear all
set more off

* ---------------------------------------------------------------
* REF 2021: download data, compute GPA and Research Power
* Output 1: institution x UoA indicators
* Output 2: institution overall indicators
* ---------------------------------------------------------------

local url "https://results2021.ref.ac.uk/profiles/export-all"
local data_dir "/Users/user/Dropbox/Akos/ukhe_data/ref2021"
capture mkdir "`data_dir'"
local xlsx "`data_dir'/ref2021_results_all.xlsx"
local out_uoa "`data_dir'/ref2021_uoa_indicators.csv"
local out_inst "`data_dir'/ref2021_institution_overall_indicators.csv"
local out_uoa_dta "`data_dir'/ref2021_uoa_indicators.dta"
local out_inst_dta "`data_dir'/ref2021_institution_overall_indicators.dta"

* Download the REF 2021 workbook
copy "`url'" "`xlsx'", replace

* Import full used range; header row is inside the data block and handled below
import excel using "`xlsx'", sheet("Sheet1") clear

* Rename columns from Excel letters to usable variable names
rename A ukprn
rename B institution_name
rename C institution_sort_order
rename D main_panel
rename E uoa_number
rename F uoa_name
rename G multiple_submission_letter
rename H multiple_submission_name
rename I joint_submission
rename J profile
rename K fte_submitted
rename L total_fte_joint_submission
rename M pct_eligible_staff_submitted
rename N pct_4star
rename O pct_3star
rename P pct_2star
rename Q pct_1star
rename R pct_unclassified

* Drop header row and keep only valid rows
drop if ukprn == "Institution code (UKPRN)"
drop if missing(profile)

* Convert numeric variables
foreach v in ukprn institution_sort_order uoa_number fte_submitted total_fte_joint_submission {
    destring `v', replace ignore(",") force
}

* Percentage columns can contain symbols/text in a few rows; force to numeric
foreach v in pct_eligible_staff_submitted pct_4star pct_3star pct_2star pct_1star pct_unclassified {
    destring `v', replace ignore(",%") force
}

* Keep overall quality profile rows only
keep if profile == "Overall"
keep if !missing(uoa_number) & !missing(fte_submitted)

* GPA and Research Power at submission level
* GPA = (4*%4* + 3*%3* + 2*%2* + 1*%1*) / 100
gen gpa_submission = (4*pct_4star + 3*pct_3star + 2*pct_2star + 1*pct_1star) / 100
gen research_power_submission = gpa_submission * fte_submitted

* ---------------------------------------------------------------
* 1) Institution x UoA indicators
* If an institution has multiple submissions in a UoA, aggregate by FTE
* ---------------------------------------------------------------
preserve
collapse (sum) research_power_submission fte_submitted, ///
    by(ukprn institution_name main_panel uoa_number uoa_name)

gen gpa = research_power_submission / fte_submitted
rename research_power_submission research_power

order ukprn institution_name main_panel uoa_number uoa_name fte_submitted gpa research_power
sort ukprn uoa_number

export delimited using "`out_uoa'", replace
save "`out_uoa_dta'", replace
restore

* ---------------------------------------------------------------
* 2) Institution overall indicators (across all UoAs)
* ---------------------------------------------------------------
collapse (sum) research_power_submission fte_submitted, by(ukprn institution_name)

gen gpa = research_power_submission / fte_submitted
rename research_power_submission research_power
rename fte_submitted total_fte_submitted

order ukprn institution_name total_fte_submitted gpa research_power
gsort -research_power

export delimited using "`out_inst'", replace
save "`out_inst_dta'", replace

di as text "Completed. Files created:"
di as text " - `out_uoa'"
di as text " - `out_uoa_dta'"
di as text " - `out_inst'"
di as text " - `out_inst_dta'"
