*===============================================================
* 数据体检.do —— 政策评估助手 skill 的数据结构探针
* 用法（PowerShell）：
*   Start-Process -FilePath '<Stata路径>' -ArgumentList '/e','do','数据体检.do','"<数据文件路径>"' -WorkingDirectory '<本do文件所在目录>' -Wait
* 只读数据、不写回。结果输出到同目录"数据体检.log"。
*===============================================================

clear all
set more off
set varabbrev off

capture log close
log using "数据体检.log", replace text

*---------------------------------------------------------------
* 按扩展名装载数据
*---------------------------------------------------------------
local f "`1'"
display as text ">>> 数据文件: `f'"

if regexm("`f'", "\.dta$") {
    use "`f'", clear
}
else if regexm("`f'", "\.csv$") {
    import delimited using "`f'", clear varnames(1) encoding(utf8)
}
else if regexm("`f'", "\.(xlsx|xls)$") {
    import excel using "`f'", clear firstrow
}
else {
    display as error ">>> 不支持的格式（仅 dta/csv/xlsx/xls）"
    log close
    exit 601
}

*---------------------------------------------------------------
* 基本信息
*---------------------------------------------------------------
display as result "=== 观测数与变量数 ==="
quietly count
display "观测数 N = " r(N)
quietly ds
display "变量数 k = " r(k)

display as result "=== 变量清单 ==="
describe

display as result "=== 数值变量摘要 ==="
summarize

*---------------------------------------------------------------
* 取值个数较少的变量：完整分布（用于识别 处理/年份/组群 变量）
*---------------------------------------------------------------
display as result "=== 低基数变量取值分布（<=12 个取值） ==="
foreach v of varlist _all {
    capture confirm numeric variable `v'
    if !_rc {
        quietly inspect `v'
        if r(N_unique) <= 12 & r(N_unique) > 1 {
            display as text "--- `v' ---"
            tab `v', missing
        }
    }
}

display as result ">>> 数据体检完成"
log close
