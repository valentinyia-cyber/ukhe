version 16.0
clear all
set more off

* ---------------------------------------------------------------
* International student time-series charts, 2014/15-2024/25.
*
* Inputs:
* - HESA Table 1 students file converted by hesa_convert_csv_to_dta.do
* - HESA Table 28 non-UK country-level students file converted by
*   hesa_convert_csv_to_dta.do
*
* Outputs:
* 1. UK HE non-UK students: total, undergraduate, and PGT
* 2. Russell Group non-UK students: total, undergraduate, and PGT
* 3. UK HE undergraduate students by location of origin
* 4. UK HE PGT students by location of origin
* 5. Russell Group undergraduate students by location of origin
* 6. Russell Group PGT students by location of origin
* ---------------------------------------------------------------

local user = c(username)
local hesa_dir "/Users/`user'/Dropbox/Akos/ukhe_data/hesa"
local dta_dir "`hesa_dir'/dta"
local out_root "`hesa_dir'/outputs"
local out_dir "`out_root'/foreign_student_timeseries"
local students_dta "`dta_dir'/T01_students.dta"
local country_students_dta "`dta_dir'/T28_nonuk_country_students.dta"
global foreign_student_out_dir "`out_dir'"

capture mkdir "`out_root'"
capture mkdir "`out_dir'"

capture program drop decode_labelled_vars
program define decode_labelled_vars
    foreach v in `0' {
        capture confirm variable `v'
        if _rc {
            continue
        }
        capture confirm string variable `v'
        if !_rc {
            continue
        }
        local value_label : value label `v'
        if "`value_label'" == "" {
            continue
        }
        local var_label : variable label `v'
        tempvar decoded
        decode `v', gen(`decoded')
        order `decoded', after(`v')
        drop `v'
        rename `decoded' `v'
        label variable `v' "`var_label'"
    }
end

foreach f in "`students_dta'" "`country_students_dta'" {
    capture confirm file "`f'"
    if _rc {
        di as error "Missing required input file: `f'"
        di as error "Run scripts/hesa_convert_csv_to_dta.do first."
        exit 601
    }
}

* ---------------------------------------------------------------
* Figures 1 and 3: non-UK students by study level.
* ---------------------------------------------------------------
use "`students_dta'", clear
decode_labelled_vars countryofheprovider regionofheprovider entrantmarker ///
    levelofstudy modeofstudy categorymarker category academicyear

foreach v in countryofheprovider regionofheprovider entrantmarker ///
    levelofstudy modeofstudy categorymarker category russellgroup ///
    year academicyear value {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable in Table 1 DTA: `v'"
        exit 111
    }
}

keep if countryofheprovider == "All" & regionofheprovider == "All"
keep if entrantmarker == "All"
keep if modeofstudy == "All"
keep if categorymarker == "Permanent address" & category == "Total Non-UK"
keep if inrange(year, 2014, 2024)
keep if inlist(levelofstudy, "All", "All undergraduate", "Postgraduate (taught)")

gen str8 level_group = ""
replace level_group = "Total" if levelofstudy == "All"
replace level_group = "UG" if levelofstudy == "All undergraduate"
replace level_group = "PGT" if levelofstudy == "Postgraduate (taught)"

gen byte level_rank = .
replace level_rank = 1 if level_group == "Total"
replace level_rank = 2 if level_group == "UG"
replace level_rank = 3 if level_group == "PGT"

tempfile level_chart_base
save "`level_chart_base'", replace

capture program drop draw_level_chart
program define draw_level_chart
    syntax, Graphname(string) Title(string) Note(string)

    collapse (sum) value, by(year academicyear level_group level_rank)
    count
    if r(N) == 0 {
        di as error "No observations found for `graphname'."
        exit 2000
    }

    gen double student_number_thousands = value / 1000
    label variable student_number_thousands "Students, thousands"

    twoway ///
        (connected student_number_thousands year if level_rank == 1, ///
            lcolor(navy) mcolor(navy) msymbol(circle) lwidth(medthick)) ///
        (connected student_number_thousands year if level_rank == 2, ///
            lcolor(maroon) mcolor(maroon) msymbol(square) lwidth(medthick)) ///
        (connected student_number_thousands year if level_rank == 3, ///
            lcolor(forest_green) mcolor(forest_green) msymbol(triangle) lwidth(medthick)) ///
        , ///
        title("`title'") ///
        subtitle("Academic years 2014/15-2024/25") ///
        xtitle("Academic year start") ///
        ytitle("Students, thousands") ///
        xlabel(2014(1)2024, angle(45) labsize(small) grid) ///
        ylabel(, angle(horizontal) grid) ///
        legend(order(1 "Total" 2 "UG" 3 "PGT") rows(1) position(6)) ///
        note("`note'", size(vsmall)) ///
        graphregion(color(white)) ///
        plotregion(color(white)) ///
        scheme(s2color) ///
        name(`graphname', replace)

    graph export "$foreign_student_out_dir/`graphname'.pdf", replace
    graph export "$foreign_student_out_dir/`graphname'.png", replace width(2400)
end

use "`level_chart_base'", clear
draw_level_chart, ///
    graphname("fig01_uk_nonuk_by_level") ///
    title("International students in UK higher education by study level") ///
    note("Source: HESA Table 1, permanent-address Total Non-UK rows.")

use "`level_chart_base'", clear
keep if russellgroup == 1
draw_level_chart, ///
    graphname("fig03_rg_nonuk_by_level") ///
    title("International students at Russell Group universities by study level") ///
    note("Source: HESA Table 1, permanent-address Total Non-UK rows.")

* ---------------------------------------------------------------
* Figures 5-8: undergraduate and PGT students by location of origin.
* ---------------------------------------------------------------
use "`country_students_dta'", clear
decode_labelled_vars countryofheprovider regionofheprovider levelofstudy ///
    modeofstudy regionofpermanentaddress countryofpermanentaddress academicyear

foreach v in countryofheprovider regionofheprovider levelofstudy modeofstudy ///
    regionofpermanentaddress countryofpermanentaddress russellgroup ///
    year academicyear value {
    capture confirm variable `v'
    if _rc {
        di as error "Missing required variable in Table 28 DTA: `v'"
        exit 111
    }
}

keep if countryofheprovider == "All" & regionofheprovider == "All"
keep if modeofstudy == "All"
keep if inrange(year, 2014, 2024)
keep if inlist(levelofstudy, "All undergraduate", "Postgraduate (taught)")
drop if countryofpermanentaddress == "Total"
drop if strpos(countryofpermanentaddress, "Total ") == 1

gen str8 student_scope = ""
replace student_scope = "UG" if levelofstudy == "All undergraduate"
replace student_scope = "PGT" if levelofstudy == "Postgraduate (taught)"

gen str24 origin_group = ""
replace origin_group = "China" if countryofpermanentaddress == "China"
replace origin_group = "India" if countryofpermanentaddress == "India"
replace origin_group = "Nigeria" if countryofpermanentaddress == "Nigeria"
replace origin_group = "Western Offshoots" ///
    if inlist(countryofpermanentaddress, "Canada", "United States", "Australia", "New Zealand")
replace origin_group = "Europe" ///
    if origin_group == "" ///
    & inlist(regionofpermanentaddress, "Geographic region - European Union", "Geographic region - Other Europe")
replace origin_group = "Middle East" ///
    if origin_group == "" ///
    & regionofpermanentaddress == "Geographic region - Middle East"
replace origin_group = "Other Africa" ///
    if origin_group == "" ///
    & regionofpermanentaddress == "Geographic region - Africa"
replace origin_group = "Other Asia" ///
    if origin_group == "" ///
    & regionofpermanentaddress == "Geographic region - Asia"
keep if origin_group != ""

gen byte origin_rank = .
replace origin_rank = 1 if origin_group == "China"
replace origin_rank = 2 if origin_group == "India"
replace origin_rank = 3 if origin_group == "Europe"
replace origin_rank = 4 if origin_group == "Nigeria"
replace origin_rank = 5 if origin_group == "Other Africa"
replace origin_rank = 6 if origin_group == "Other Asia"
replace origin_rank = 7 if origin_group == "Middle East"
replace origin_rank = 8 if origin_group == "Western Offshoots"

tempfile origin_chart_base
save "`origin_chart_base'", replace

capture program drop draw_origin_chart
program define draw_origin_chart
    syntax, Scope(string) Graphname(string) Title(string) Note(string)

    keep if student_scope == "`scope'"
    collapse (sum) value, by(year academicyear origin_group origin_rank)
    count
    if r(N) == 0 {
        di as error "No observations found for `graphname'."
        exit 2000
    }

    gen double student_number_thousands = value / 1000
    label variable student_number_thousands "Students, thousands"

    local colors "navy maroon forest_green dkorange cranberry teal purple gs8"
    local symbols "circle square triangle diamond circle square triangle diamond"
    local plots ""
    local legend_order ""
    forvalues i = 1/8 {
        local color : word `i' of `colors'
        local symbol : word `i' of `symbols'
        quietly levelsof origin_group if origin_rank == `i', local(origin_label) clean
        local plots `"`plots' (connected student_number_thousands year if origin_rank == `i', lcolor(`color') mcolor(`color') msymbol(`symbol') lwidth(medthick))"'
        local legend_order `"`legend_order' `i' "`origin_label'""'
    }

    twoway ///
        `plots' ///
        , ///
        title("`title'") ///
        subtitle("Academic years 2014/15-2024/25") ///
        xtitle("Academic year start") ///
        ytitle("Students, thousands") ///
        xlabel(2014(1)2024, angle(45) labsize(small) grid) ///
        ylabel(, angle(horizontal) grid) ///
        legend(order(`legend_order') rows(2) position(6) size(small)) ///
        note("`note'", size(vsmall)) ///
        graphregion(color(white)) ///
        plotregion(color(white)) ///
        scheme(s2color) ///
        name(`graphname', replace)

    graph export "$foreign_student_out_dir/`graphname'.pdf", replace
    graph export "$foreign_student_out_dir/`graphname'.png", replace width(2400)
end

use "`origin_chart_base'", clear
draw_origin_chart, ///
    scope("UG") ///
    graphname("fig05_uk_ug_by_origin") ///
    title("International UG students by location of origin") ///
    note("Source: HESA Table 28, provider-level rows; aggregate country total rows excluded.")

use "`origin_chart_base'", clear
draw_origin_chart, ///
    scope("PGT") ///
    graphname("fig06_uk_pgt_by_origin") ///
    title("International PGT students by location of origin") ///
    note("Source: HESA Table 28, provider-level rows; aggregate country total rows excluded.")

use "`origin_chart_base'", clear
keep if russellgroup == 1
draw_origin_chart, ///
    scope("UG") ///
    graphname("fig07_rg_ug_by_origin") ///
    title("International UG students by location of origin, Russell Group") ///
    note("Source: HESA Table 28, Russell Group provider-level rows; aggregate country total rows excluded.")

use "`origin_chart_base'", clear
keep if russellgroup == 1
draw_origin_chart, ///
    scope("PGT") ///
    graphname("fig08_rg_pgt_by_origin") ///
    title("International PGT students by location of origin, Russell Group") ///
    note("Source: HESA Table 28, Russell Group provider-level rows; aggregate country total rows excluded.")

di as result "Created foreign-student time-series charts in:"
di as result " - `out_dir'"
