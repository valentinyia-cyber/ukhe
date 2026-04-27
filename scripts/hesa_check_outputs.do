version 16.0
clear all
set more off

* ---------------------------------------------------------------
* Quick checks for HESA DTA files created by hesa_convert_csv_to_dta.do
* ---------------------------------------------------------------

local hesa_dir "/Users/user/Dropbox/Akos/ukhe_data/hesa"
local out_dir "`hesa_dir'/dta"

local files "T01_students.dta T06_tuition_fees.dta T07_income.dta T08_expenditure.dta T11_staff_fte.dta T12_staff_costs.dta T13_severance.dta T14_kfi.dta"

local sort_1  "ukprn levelofstudy modeofstudy categorymarker category year"
local sort_6  "ukprn tuitionfeesandeducationcontracts v9 year"
local sort_7  "ukprn categorymarker category year"
local sort_8  "ukprn hesacostcentre academicdepartments activity year"
local sort_11 "ukprn contractmarker categorymarker category year"
local sort_12 "ukprn staffcosts unit year"
local sort_13 "ukprn categorymarker category year"
local sort_14 "ukprn kfiratiotitle year"

foreach f of local files {
    capture confirm file "`out_dir'/`f'"
    if _rc {
        di as error "`f'"
        di as error "  missing from `out_dir'"
        continue
    }

    use "`out_dir'/`f'", clear
    quietly count
    local nrows = r(N)
    local t = real(substr("`f'", 2, 2))
    local sorted_by : sortedby
    if "`sorted_by'" == "`sort_`t''" {
        local sort_status "`sorted_by'"
    }
    else {
        local sort_status "expected `sort_`t''; saved sort is `sorted_by'"
    }

    local year_status "missing"
    capture confirm numeric variable year
    if !_rc {
        quietly summarize year, meanonly
        local year_status "numeric, range `r(min)'-`r(max)'"
    }

    unab allvars : _all
    local has_value : list posof "value" in allvars
    local value_status "missing"
    if `has_value' {
        capture confirm numeric variable value
        if !_rc {
            local value_status "numeric"
        }
        else {
            local value_status "present but not numeric"
        }
    }

    local year_order_status "not checked"
    capture confirm variable year
    if !_rc {
        capture confirm variable academicyear
        if !_rc {
            local i 0
            local year_pos 0
            local academicyear_pos 0
            foreach v of varlist _all {
                local i = `i' + 1
                if "`v'" == "year" local year_pos `i'
                if "`v'" == "academicyear" local academicyear_pos `i'
            }
            if `year_pos' + 1 == `academicyear_pos' {
                local year_order_status "immediately before academicyear"
            }
            else {
                local year_order_status "year position `year_pos', academicyear position `academicyear_pos'"
            }
        }
    }

    capture confirm variable ukprn
    if !_rc {
        quietly levelsof ukprn, local(providers)
        local nproviders : word count `providers'
        capture assert ref2021_filter_applied == 1
        if _rc {
            local filter_status "mixed/unverified"
        }
        else {
            local filter_status "REF2021 >1 UoA filter applied"
        }
    }
    else {
        local nproviders 0
        local filter_status "no UKPRN in source; not provider-filtered"
    }

    di as text "`f'"
    di as text "  rows: `nrows'"
    di as text "  providers: `nproviders'"
    di as text "  year: `year_status'"
    di as text "  year order: `year_order_status'"
    di as text "  value: `value_status'"
    di as text "  sorted by: `sort_status'"
    di as text "  status: `filter_status'"
}
