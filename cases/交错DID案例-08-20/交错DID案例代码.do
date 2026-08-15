*===============================================================
* 交错DID稳健估计量完整案例（新手一键运行版）
* 用法：Ctrl+A 全选 -> Ctrl+D 一次运行
* 故事：与 Day 7 相同的渐进处理结构（2015/2018 两批试点 +
*       从未试点），效应逐年累积。演示：TWFE 偏误 vs
*       Callaway-Sant'Anna / Sun-Abraham / Borusyak 三大
*       稳健估计量如何回到真实值
*===============================================================

clear all
set more off
set varabbrev off

*---------------------------------------------------------------
* 0. 设定工作目录（输出文件都在这里找）
*---------------------------------------------------------------
capture log close
log using "交错DID案例.log", replace text

*---------------------------------------------------------------
* 自动检查并安装所需命令（首次联网安装一次即可）
*---------------------------------------------------------------
capture which csdid
if _rc ssc install csdid, replace
capture which drdid
if _rc ssc install drdid, replace
capture which eventstudyinteract
if _rc ssc install eventstudyinteract, replace
capture which did_imputation
if _rc ssc install did_imputation, replace
capture which reghdfe
if _rc ssc install reghdfe, replace
capture which avar
if _rc ssc install avar, replace
capture which coefplot
if _rc ssc install coefplot, replace

*---------------------------------------------------------------
* 1. 模拟面板数据（结构同 Day 7）：1500家企业 × 11年（2010-2020）
*    真实效应：试点后第k年 = 0.10 × k；真实平均ATT ≈ 0.30
*---------------------------------------------------------------
set seed 20260820
set obs 1500
gen id = _n
gen E = 0
replace E = 2015 if id <= 400
replace E = 2018 if id > 400 & id <= 800
gen alpha = rnormal(0, 0.3)

expand 11
bysort id: gen year = 2009 + _n
gen did  = (E > 0) & (year >= E)
gen exp  = (year - E + 1) * did
gen y = 3 + alpha + 0.05*(year-2010) + 0.10*exp + rnormal(0, 0.25)

xtset id year
save "交错DID案例数据.dta", replace

quietly sum exp if did == 1, meanonly
display as result ">>> 真实平均ATT = " %5.3f 0.10*r(mean)

*===============================================================
* 2. 基准TWFE（对照组：应低于真实ATT）
*===============================================================
reghdfe y did, absorb(id year) vce(cluster id)
estimates store twfe

*===============================================================
* 3. Callaway-Sant'Anna：组群-时期ATT + 聚合
*===============================================================
csdid y, ivar(id) time(year) gvar(E)
estat simple                      // 总体ATT（应≈0.30）
estat event, window(-4 4) estore(cs_es)   // 事件研究动态效应
estat group                       // 分组群ATT

*===============================================================
* 4. Sun-Abraham 交互加权事件研究
*===============================================================
gen rel = year - E if E > 0
replace rel = -5 if rel < -5 & E > 0
replace rel = 4  if rel > 4  & E > 0
forvalues s = -5/4 {
    local name = cond(`s' < 0, "m" + string(-`s'), "p" + string(`s'))
    gen D_`name' = (rel == `s')
}
gen never = (E == 0)
* 以从未处理为对照；注意端点哑变量须排除（-1期为基准由命令处理）
eventstudyinteract y D_m4-D_m2 D_p0-D_p4, ///
    vce(cluster id) absorb(id year) cohort(E) control_cohort(never)
estimates store sa

*===============================================================
* 5. Borusyak-Jaravel-Spiess 插补法
*    （Ei 对从未处理者须为缺失值，不能为0）
*===============================================================
gen Ei = E if E > 0
did_imputation y id year Ei, horizons(0/4) pretrend(4)
estimates store bjs

*===============================================================
* 6. 三套事件研究系数叠加对比图
*===============================================================
coefplot (cs_es, label(Callaway-Sant'Anna)) ///
         (sa,    label(Sun-Abraham)) ///
         (bjs,   label(Borusyak等)), ///
    vertical yline(0) xtitle("相对期") ytitle("效应系数") ///
    title("三类稳健估计量的事件研究对比（真实值：第k期=0.10×(k+1)）")
graph export "交错DID_事件研究对比.png", replace width(2000)

*===============================================================
log close
display as result ">>> 全部完成！请到桌面 交错DID案例 文件夹查看输出"
