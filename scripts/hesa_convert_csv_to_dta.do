version 16.0
clear all
set more off

* ---------------------------------------------------------------
* Convert local HESA CSV tables to Stata DTA files.
*
* - One DTA file is created per HESA table.
* - Year-split table folders are appended before saving.
* - Provider-level HESA rows are restricted to REF2021 institutions
*   with submissions in more than one Unit of Assessment.
* ---------------------------------------------------------------

local user = c(username)
local hesa_dir "/Users/`user'/Dropbox/Akos/ukhe_data/hesa"
local csv_dir "`hesa_dir'/csv"
local ref_dir "/Users/`user'/Dropbox/Akos/ukhe_data/ref2021"
local out_dir "`hesa_dir'/dta"
capture mkdir "`out_dir'"
global hesa_csv_dir "`csv_dir'"

tempfile ref2021_multi_uoa
global ref2021_multi_uoa_file "`ref2021_multi_uoa'"

tempfile russell_group_providers
global russell_group_file "`russell_group_providers'"

capture confirm file "`csv_dir'/russell_list.csv"
if !_rc {
    import delimited using "`csv_dir'/russell_list.csv", varnames(1) clear ///
        bindquote(strict) encoding("UTF-8")
    keep ukprn russell
    destring ukprn, replace ignore(",") force
    gen byte russellgroup = inlist(strlower(ustrtrim(itrim(russell))), "true", "1", "yes", "y")
    keep ukprn russellgroup
    duplicates drop ukprn, force
    label variable russellgroup "Russell Group member"
    compress
    save "`russell_group_providers'", replace
}
else {
    clear
    set obs 0
    gen long ukprn = .
    gen byte russellgroup = .
    label variable russellgroup "Russell Group member"
    save "`russell_group_providers'", replace
    di as error "Warning: missing Russell Group provider list: `csv_dir'/russell_list.csv"
}

* Prefer the already-created REF2021 institution x UoA file.
capture confirm file "`ref_dir'/ref2021_uoa_indicators.dta"
if !_rc {
    use "`ref_dir'/ref2021_uoa_indicators.dta", clear
    keep ukprn institution_name uoa_number
}
else {
    capture confirm file "`ref_dir'/ref2021_results_all.xlsx"
    if _rc {
        di as error "Missing REF2021 source file:"
        di as error "  `ref_dir'/ref2021_uoa_indicators.dta"
        di as error "  `ref_dir'/ref2021_results_all.xlsx"
        exit 601
    }

    import excel using "`ref_dir'/ref2021_results_all.xlsx", sheet("Sheet1") clear
    rename A ukprn
    rename B institution_name
    rename E uoa_number
    rename J profile

    drop if ukprn == "Institution code (UKPRN)"
    keep if profile == "Overall"
    destring ukprn uoa_number, replace ignore(",") force
    keep ukprn institution_name uoa_number
}

keep if !missing(ukprn) & !missing(uoa_number)
duplicates drop ukprn uoa_number, force
bysort ukprn: gen n_ref2021_uoas = _N
bysort ukprn (institution_name): keep if _n == 1
keep if n_ref2021_uoas > 1
rename institution_name ref2021_institution_name
keep ukprn ref2021_institution_name n_ref2021_uoas
compress
save "`ref2021_multi_uoa'", replace

capture program drop import_hesa_csv
program define import_hesa_csv
    syntax using/, TABLE(integer) SHORTNAME(string) [FILTER]

    local headerrow 0
    local lineno 0
    file open hesa_fh using "`using'", read text
    file read hesa_fh line
    while r(eof) == 0 {
        local lineno = `lineno' + 1
        if strpos(`"`line'"', "UKPRN,") == 1 | strpos(`"`line'"', "Category marker,") == 1 {
            local headerrow `lineno'
            continue, break
        }
        file read hesa_fh line
    }
    file close hesa_fh

    if `headerrow' == 0 {
        di as error "Could not find a HESA header row in `using'"
        exit 459
    }

    import delimited using "`using'", varnames(`headerrow') stringcols(_all) clear ///
        bindquote(strict) encoding("UTF-8")

    foreach v in number value value000s value_000s valueratio value_ratio numbervalue number_value {
        capture confirm string variable `v'
        if !_rc {
            quietly replace `v' = ustrtrim(itrim(`v'))
            quietly replace `v' = "" if `v' == "."
            quietly replace `v' = "-" + regexs(1) if regexm(`v', "^\(([0-9][0-9,]*\.?[0-9]*)\)$")
            capture destring `v', replace ignore(",")
        }
    }

    local academic_year_var ""
    foreach v in academicyear academiyear academic_year {
        capture confirm variable `v'
        if !_rc & "`academic_year_var'" == "" {
            local academic_year_var "`v'"
        }
    }
    if "`academic_year_var'" != "" {
        capture confirm string variable `academic_year_var'
        if !_rc {
            quietly replace `academic_year_var' = ustrtrim(itrim(`academic_year_var'))
        }
        gen int year = real(substr(`academic_year_var', 1, 4))
        label variable year "Academic year start year"
    }

    gen int hesa_table = `table'
    gen str40 hesa_short_name = "`shortname'"
    local source_file "`using'"
    local csv_prefix "$hesa_csv_dir/"
    local prefix_len = strlen("`csv_prefix'")
    if substr("`source_file'", 1, `prefix_len') == "`csv_prefix'" {
        local source_file = "csv/" + substr("`source_file'", `prefix_len' + 1, .)
    }
    gen strL hesa_source_file = "`source_file'"

    capture confirm variable ukprn
    if !_rc {
        capture confirm string variable ukprn
        if !_rc {
            quietly replace ukprn = ustrtrim(itrim(ukprn))
            destring ukprn, replace ignore(",") force
        }

        merge m:1 ukprn using "$ref2021_multi_uoa_file", keep(match) nogen
        merge m:1 ukprn using "$russell_group_file", keep(master match) nogen
        replace russellgroup = 0 if missing(russellgroup)
        gen byte ref2021_filter_applied = 1
        label variable ref2021_filter_applied "Rows restricted to REF2021 institutions with >1 UoA"
    }
    else {
        gen byte russellgroup = .
        label variable russellgroup "Russell Group member"
        gen byte ref2021_filter_applied = 0
        label variable ref2021_filter_applied "No UKPRN in source CSV; REF2021 filter not applied"
        di as error "Warning: no UKPRN column in `using'; saved without REF2021 provider filtering."
    }

    capture order ukprn ref2021_institution_name n_ref2021_uoas
    order hesa_table hesa_short_name hesa_source_file ref2021_filter_applied, last
    compress
end

local tables "1 6 7 8 11 12 13 14 28"
if `"`0'"' != "" {
    local tables `"`0'"'
}

local short_1  "students"
local short_6  "tuition_fees"
local short_7  "income"
local short_8  "expenditure"
local short_11 "staff_fte"
local short_12 "staff_costs"
local short_13 "severance"
local short_14 "kfi"
local short_28 "nonuk_country_students"

local sort_1  "ukprn levelofstudy modeofstudy categorymarker category year"
local sort_6  "ukprn tuitionfeesandeducationcontracts v9 year"
local sort_7  "ukprn categorymarker category year"
local sort_8  "ukprn hesacostcentre academicdepartments activity year"
local sort_11 "ukprn contractmarker categorymarker category year"
local sort_12 "ukprn staffcosts unit year"
local sort_13 "ukprn categorymarker category year"
local sort_14 "ukprn kfiratiotitle year"
local sort_28 "ukprn levelofstudy modeofstudy regionofpermanentaddress countryofpermanentaddress year"

local order_1  "modeofstudy categorymarker category year"
local order_6  "year"
local order_7  "year"
local order_8  "year"
local order_11 "year"
local order_12 "staffcosts unit year"
local order_13 "categorymarker category year"
local order_14 "kfiratiotitle year"
local order_28 "levelofstudy modeofstudy regionofpermanentaddress countryofpermanentaddress year"

local value_source_1  "number"
local value_source_6  "value000s"
local value_source_7  "value000s"
local value_source_8  "value000s"
local value_source_11 "number"
local value_source_12 "numbervalue"
local value_source_13 "value000s"
local value_source_14 "valueratio"
local value_source_28 "number"

foreach t of local tables {
    local short "`short_`t''"
    local table_id : display %02.0f `t'

    if inlist(`t', 1, 8, 11, 28) {
        local table_dir "`csv_dir'/table-`t'"
        local files : dir "`table_dir'" files "*.csv"
    }
    else {
        local table_dir "`csv_dir'"
        local files "table-`t'.csv"
    }

    local first 1
    tempfile combined

    foreach f of local files {
        local csv_path "`table_dir'/`f'"
        di as text "Importing HESA table `t': `csv_path'"
        quietly import_hesa_csv using "`csv_path'", table(`t') shortname("`short'") filter

        if `first' {
            save "`combined'", replace
            local first 0
        }
        else {
            append using "`combined'"
            save "`combined'", replace
        }
    }

    if `first' {
        di as error "No CSV files found for HESA table `t'"
        continue
    }

    use "`combined'", clear
    local value_source "`value_source_`t''"
    capture confirm variable `value_source'
    if !_rc {
        rename `value_source' value
    }
    else {
        unab allvars : _all
        local has_value : list posof "value" in allvars
        if !`has_value' {
            di as error "Expected value source variable `value_source' for HESA table `t'"
            exit 111
        }
    }
    label variable value "Value"

    foreach v of local sort_`t' {
        capture confirm variable `v'
        if _rc {
            di as error "Expected sort variable `v' for HESA table `t'"
            exit 111
        }
    }

    order `order_`t'', before(academicyear)
    sort `sort_`t''
    label data "HESA table `t' (`short'), converted from CSV"
    save "`out_dir'/T`table_id'_`short'.dta", replace

    count
    di as result "Saved `r(N)' rows: `out_dir'/T`table_id'_`short'.dta"
}

di as text "Done. HESA DTA files are in `out_dir'."
