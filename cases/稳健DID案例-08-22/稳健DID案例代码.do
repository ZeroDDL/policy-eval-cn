*===============================================================
* 稳健DID"诊断—估计—报告"全流程案例（新手一键运行版）
* 用法：Ctrl+A 全选 -> Ctrl+D 一次运行
* 故事：与 Day 7/8 相同的渐进处理结构（2015/2018 两批试点），
*       演示投稿前的完整流程：Bacon分解诊断 → CS主估计 →
*       Sun-Abraham/BJS对照 → honestdid平行趋势敏感性分析
*===============================================================

clear all
set more off
set varabbrev off

*---------------------------------------------------------------
* 0. 设定工作目录（输出文件都在这里找）
*---------------------------------------------------------------
capture log close
log using "稳健DID案例.log", replace text

*---------------------------------------------------------------
* 自动检查并安装所需命令（首次联网安装一次即可）
*---------------------------------------------------------------
capture which csdid
if _rc ssc install csdid, replace
capture which drdid
if _rc ssc install drdid, replace
capture which bacondecomp
if _rc ssc install bacondecomp, replace
capture which eventstudyinteract
if _rc ssc install eventstudyinteract, replace
capture which did_imputation
if _rc ssc install did_imputation, replace
capture which honestdid
if _rc ssc install honestdid, replace
capture which reghdfe
if _rc ssc install reghdfe, replace
capture which avar
if _rc ssc install avar, replace
capture which coefplot
if _rc ssc install coefplot, replace

*---------------------------------------------------------------
* 1. 模拟面板数据（同 Day 7/8 结构）：真实平均ATT ≈ 0.30
*---------------------------------------------------------------
set seed 20260822
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
save "稳健DID案例数据.dta", replace

quietly sum exp if did == 1, meanonly
display as result ">>> 真实平均ATT = " %5.3f 0.10*r(mean)

*===============================================================
* 2. 第一步·诊断：TWFE基准 + Bacon分解（坏比较权重）
*===============================================================
reghdfe y did, absorb(id year) vce(cluster id)
bacondecomp y did, ddetail
display as result ">>> 若坏比较(Later vs Earlier)权重高，TWFE不可作主结果"

*===============================================================
* 3. 第二步·主估计：Callaway-Sant'Anna
*===============================================================
csdid y, ivar(id) time(year) gvar(E)
estat simple
estat event, window(-4 4)
estimates store cs_es

*===============================================================
* 4. 第三步·稳健对照：Sun-Abraham + Borusyak插补
*===============================================================
gen rel = year - E if E > 0
replace rel = -5 if rel < -5 & E > 0
replace rel = 4  if rel > 4  & E > 0
forvalues s = -5/4 {
    local name = cond(`s' < 0, "m" + string(-`s'), "p" + string(`s'))
    gen D_`name' = (rel == `s')
}
gen never = (E == 0)
eventstudyinteract y D_m4-D_m2 D_p0-D_p4, ///
    vce(cluster id) absorb(id year) cohort(E) control_cohort(never)

gen Ei = E if E > 0
did_imputation y id year Ei, horizons(0/4) pretrend(4)

*===============================================================
* 5. 第四步·平行趋势敏感性分析（Rambachan-Roth honestdid）
*    接在 csdid 事件研究之后：pre/post 填系数位置
*    （e(b) 中第1-2行为 Pre_avg/Post_avg，故前置期为 3/6，
*      后置期为 7/11）
*===============================================================
quietly csdid y, ivar(id) time(year) gvar(E)
estat event, window(-4 4)
honestdid, pre(3/6) post(7/11) mvec(0(0.5)1) coefplot
graph export "稳健DID_平行趋势敏感性.png", replace width(2000)
* 解读：Mbar=0 对应"平行趋势完全成立"的置信区间；
* 随 Mbar（允许的趋势偏差）增大，置信带变宽，
* 结论失效的临界 Mbar 越大，结论越稳健

*===============================================================
log close
display as result ">>> 全部完成！请到桌面 稳健DID案例 文件夹查看输出"
