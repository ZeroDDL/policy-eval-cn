*===============================================================
* 多期与渐进DID完整案例（新手一键运行版）
* 用法：Ctrl+A 全选 -> Ctrl+D 一次运行
* 故事：1500家企业分两批进入"绿色信贷试点"（2015年一批、
*       2018年一批），效应随进入年限逐年累积（每年+0.10）。
*       演示：TWFE在渐进处理+动态效应下的偏误，以及
*       Goodman-Bacon分解如何诊断"坏比较"
*===============================================================

clear all
set more off
set varabbrev off

*---------------------------------------------------------------
* 0. 设定工作目录（输出文件都在这里找）
*---------------------------------------------------------------
capture log close
log using "多期DID案例.log", replace text

*---------------------------------------------------------------
* 自动检查并安装所需命令（首次联网安装一次即可）
*---------------------------------------------------------------
capture which bacondecomp
if _rc ssc install bacondecomp, replace
capture which reghdfe
if _rc ssc install reghdfe, replace
capture which coefplot
if _rc ssc install coefplot, replace

*---------------------------------------------------------------
* 1. 模拟面板数据：1500家企业 × 11年（2010-2020）
*    组群：2015年首批试点（400家）、2018年二批（400家）、从未试点（700家）
*    真实效应：试点后第k年效应 = 0.10 × k（动态累积）
*    【换用真实数据时，替换这一段即可，后面代码不用动】
*---------------------------------------------------------------
set seed 20260819
set obs 1500
gen id = _n
gen E = 0                               // 首次处理年份
replace E = 2015 if id <= 400           // 首批试点
replace E = 2018 if id > 400 & id <= 800 // 二批试点
gen alpha = rnormal(0, 0.3)             // 企业固定效应

expand 11
bysort id: gen year = 2009 + _n
gen did  = (E > 0) & (year >= E)        // 处理状态
gen exp  = (year - E + 1) * did         // 试点年限（0表示未试点）

* 结果方程：真实效应 = 0.10 × 试点年限（动态效应）
gen y = 3 + alpha + 0.05*(year-2010) + 0.10*exp + rnormal(0, 0.25)
*                                        ↑真实效应（逐年累积）

xtset id year
save "多期DID案例数据.dta", replace

* 真实平均ATT（备查）：处理单元×处理期的平均效应
quietly sum exp if did == 1, meanonly
display as result ">>> 真实平均ATT = 0.10 × 平均试点年限 = " %5.3f 0.10*r(mean)

*===============================================================
* 2. 基准TWFE回归：在动态效应下会明显偏误
*===============================================================
reghdfe y did, absorb(id year) vce(cluster id)
estimates store twfe
display as result ">>> TWFE估计（与真实平均ATT对比，观察偏误方向与幅度）"

*===============================================================
* 3. Goodman-Bacon分解：TWFE是哪些2×2比较的加权平均？
*===============================================================
bacondecomp y did, ddetail
* 重点看三行的权重（weight）：
*   Treated vs Never treated（干净比较）
*   Earlier vs Later treated（干净比较）
*   Later vs Earlier treated（坏比较：早处理组充当对照）
* 坏比较权重越大，TWFE越不可信

*===============================================================
* 4. 事件研究（TWFE版）：展示动态效应与预趋势
*===============================================================
gen rel = year - E if E > 0             // 相对政策时点
replace rel = -5 if rel < -5 & E > 0    // 端点归并
replace rel = 4  if rel > 4  & E > 0
forvalues s = -5/4 {
    local name = cond(`s' < 0, "m" + string(-`s'), "p" + string(`s'))
    gen D_`name' = (rel == `s')
}
replace D_m5 = 0 if E == 0              // 从未处理企业所有哑变量取0
forvalues s = -4/4 {
    local name = cond(`s' < 0, "m" + string(-`s'), "p" + string(`s'))
    replace D_`name' = 0 if E == 0
}
drop D_m1                               // 以政策前一期为基准

reghdfe y D_*, absorb(id year) vce(cluster id)
coefplot, keep(D_*) vertical yline(0) xline(5.5, lpattern(dash)) ///
    coeflabels(D_m5="-5-" D_m4="-4" D_m3="-3" D_m2="-2" D_p0="0" ///
               D_p1="1" D_p2="2" D_p3="3" D_p4="4+") ///
    xtitle("相对政策时点") ytitle("效应系数") ///
    title("TWFE事件研究（真实效应：第k期=0.10×(k+1)）")
graph export "多期DID_事件研究图.png", replace width(2000)

*===============================================================
* 5. 解读要点（对照日志输出）
*===============================================================
display as result ">>> 解读：TWFE系数偏离真实ATT，bacondecomp显示坏比较权重，"
display as result ">>> 事件研究政策前系数若偏离0，说明传统设定失真——转Day 8稳健估计量"

*===============================================================
log close
display as result ">>> 全部完成！请到桌面 多期DID案例 文件夹查看输出"
