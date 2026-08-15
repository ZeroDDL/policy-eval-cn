*===============================================================
* PSM-DID组合方法完整案例（新手一键运行版）
* 用法：Ctrl+A 全选 -> Ctrl+D 一次运行
* 故事：2000家企业，2016年起部分企业获得"数字化转型补贴"，
*       规模大的企业更可能获得补贴、且规模本身带来更快增长
*       （基线失衡 + 趋势不同）——先看朴素DID的偏误，
*       再看"先PSM后DID"如何把估计拉回真实值 0.30
*===============================================================

clear all
set more off
set varabbrev off

*---------------------------------------------------------------
* 0. 设定工作目录（输出文件都在这里找）
*---------------------------------------------------------------
capture log close
log using "PSMDID案例.log", replace text

*---------------------------------------------------------------
* 自动检查并安装所需命令（首次联网安装一次即可）
*---------------------------------------------------------------
capture which psmatch2
if _rc ssc install psmatch2, replace
capture which reghdfe
if _rc ssc install reghdfe, replace
capture which coefplot
if _rc ssc install coefplot, replace

*---------------------------------------------------------------
* 1. 模拟面板数据：2000家企业 × 8年（2013-2020），政策年2016
*    【换用真实数据时，替换这一段即可，后面代码不用动】
*---------------------------------------------------------------
set seed 20260818
set obs 2000
gen id      = _n
gen size    = rnormal(8, 1)            // 资产规模（对数）
gen firmage = rnormal(12, 4)           // 成立年限
gen lev     = runiform()*0.8           // 杠杆率

* 选择方程：规模大、成立久、杠杆高的企业更可能获补贴（自选择）
gen z       = -3.5 + 0.35*size + 0.06*firmage + 1.5*lev
gen treated = runiform() < invlogit(z)

gen alpha   = rnormal(0, 0.3)          // 企业固定效应
expand 8
bysort id: gen year = 2012 + _n
gen post = (year >= 2016)

* 结果方程：产出对数；规模带来更快的趋势（0.03*size*t），
* 真实补贴效应 = 0.30
gen y = 5 + alpha + 0.02*(year-2012) + 0.03*size*(year-2012) ///
      + 0.30*treated*post + rnormal(0, 0.25)
*         ↑真实效应

xtset id year
save "PSMDID案例数据.dta", replace

*===============================================================
* 2. 朴素DID（全样本、未匹配）：有偏的对照
*===============================================================
gen did = treated * post
reghdfe y did, absorb(id year) vce(cluster id)
estimates store naive
display as result ">>> 朴素DID估计（应明显偏离真实值0.30）"

*===============================================================
* 3. 第一步：用政策前（2015年）协变量做倾向得分匹配
*===============================================================
preserve
keep if year == 2015                  // 政策前一期截面
logit treated size firmage lev
predict pscore, pr
psmatch2 treated, pscore(pscore) neighbor(1) caliper(0.05) common
pstest size firmage lev, both graph   // 平衡性检验：匹配后偏差应<10%
graph export "PSMDID_平衡性检验图.png", replace width(2000)

* 共同支撑图
twoway (histogram pscore if treated==1, width(0.02) color(red%55)) ///
       (histogram pscore if treated==0, width(0.02) color(navy%55)), ///
    legend(label(1 "处理组") label(2 "对照组")) ///
    xtitle("倾向得分") ytitle("频数") title("共同支撑检验")
graph export "PSMDID_共同支撑图.png", replace width(2000)

* 保存匹配成功个体的编号与权重
keep id _weight
keep if !missing(_weight) & _weight > 0
save "matched_id.dta", replace
restore

*===============================================================
* 4. 第二步：匹配样本上的DID
*===============================================================
preserve
merge m:1 id using "matched_id.dta", keep(match) nogen
reghdfe y did, absorb(id year) vce(cluster id)
estimates store matched
display as result ">>> PSM-DID估计（应回到真实值0.30附近）"

* 事件研究（匹配样本）：政策前系数应含0
gen rel = year - 2016
forvalues s = -3/4 {
    local name = cond(`s' < 0, "m" + string(-`s'), "p" + string(`s'))
    gen D_`name' = (rel == `s' & treated == 1)
}
drop D_m1                                // 以政策前一期为基准
reghdfe y D_*, absorb(id year) vce(cluster id)
coefplot, keep(D_*) vertical yline(0) xline(3.5, lpattern(dash)) ///
    coeflabels(D_m3="-3" D_m2="-2" D_p0="0" D_p1="1" D_p2="2" D_p3="3" D_p4="4") ///
    xtitle("相对政策时点") ytitle("效应系数") ///
    title("事件研究：政策前系数含0，政策后约为0.30")
graph export "PSMDID_事件研究图.png", replace width(2000)
restore

*===============================================================
* 5. 结果对照：朴素DID vs PSM-DID
*===============================================================
capture which esttab
if _rc ssc install estout, replace
esttab naive matched using "PSMDID回归结果.rtf", replace ///
    b(%9.3f) se(%9.3f) star(* 0.1 ** 0.05 *** 0.01) ///
    keep(did) mtitles("朴素DID（有偏）" "PSM-DID") ///
    title("PSM-DID估计结果（真实效应 = 0.30）") ///
    addnotes("括号内为企业层面聚类稳健标准误")

*===============================================================
log close
display as result ">>> 全部完成！请到桌面 PSMDID案例 文件夹查看输出"
