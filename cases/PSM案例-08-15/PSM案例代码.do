*===============================================================
* PSM模型完整案例（新手一键运行版）
* 用法：Ctrl+A 全选 -> Ctrl+D 一次运行
*===============================================================

clear all
set more off
set varabbrev off

*---------------------------------------------------------------
* 0. 设定工作目录（输出文件都在这里找）
*---------------------------------------------------------------
capture log close
log using "PSM案例.log", replace text

*---------------------------------------------------------------
* 安装命令（第一次运行时，把这2行开头的*删除）
*---------------------------------------------------------------
*ssc install psmatch2, replace
*ssc install estout, replace

*---------------------------------------------------------------
* 1. 模拟截面数据：4000名劳动者，真实培训效应=0.25（对数工资）
*    【换用真实数据时，替换这一段即可，后面代码不用动】
*---------------------------------------------------------------
set seed 20240815
set obs 4000

gen age     = round(rnormal(38, 10))           // 年龄
replace age = max(min(age, 65), 22)
gen edu     = round(rnormal(12, 2.5))          // 受教育年限
replace edu = max(min(edu, 22), 6)
gen married = runiform() < 0.55                // 已婚
gen city    = runiform() < 0.60                // 城镇

* 真实选择方程：年龄大、学历高、已婚者更可能参加培训（自选择）
gen z      = -5.5 + 0.05*age + 0.22*edu + 0.7*married - 0.5*city
gen p_true = invlogit(z)
gen train  = runiform() < p_true               // 处理变量：参加职业培训

* 结果方程：对数工资；真实培训效应 = 0.25（约28%）
gen lnwage = 7.5 + 0.02*age + 0.09*edu + 0.15*married + 0.10*city ///
           + 0.25*train + rnormal(0, 0.45)
*                        ↑真实效应

tab train
save "PSM案例数据.dta", replace      // 存档，后面随时调用

*===============================================================
* 2. 朴素对比（有偏）：直接比较两组工资差异
*===============================================================
reg lnwage train, robust
estimates store naive
display as result ">>> 朴素OLS系数（存在选择偏差，应明显大于0.25）"

*===============================================================
* 3. 估计倾向得分 + 最近邻匹配（k=1，卡尺0.05，共同支撑）
*===============================================================
logit train age edu married city
predict pscore, pr                        // 倾向得分

psmatch2 train, pscore(pscore) outcome(lnwage) ///
    neighbor(1) caliper(0.05) common ate
* 输出表中 ATT 行即匹配后的培训效应，应回到 0.25 附近

quietly count if _support == 0 & train == 1
display as result ">>> 共同支撑外剔除的处理组人数 = " r(N)

*===============================================================
* 4. 平衡性检验与共同支撑图形
*===============================================================
pstest age edu married city, both graph
* 期刊标准：匹配后标准化偏差绝对值 <10%，组间差异不显著
graph export "平衡性检验_标准化偏差图.png", replace width(2000)

twoway (histogram pscore if train==1, width(0.02) color(red%55)) ///
       (histogram pscore if train==0, width(0.02) color(navy%55)), ///
    legend(label(1 "处理组（参加培训）") label(2 "对照组（未参加）")) ///
    xtitle("倾向得分") ytitle("频数") ///
    title("共同支撑检验：两组倾向得分分布") ///
    note("注：两组分布大面积重叠，共同支撑假设基本满足")
graph export "共同支撑_倾向得分分布图.png", replace width(2000)

*===============================================================
* 5. 稳健性：更换匹配算法 + 匹配样本上加权回归
*===============================================================
psmatch2 train, pscore(pscore) outcome(lnwage) kernel common
display as result ">>> 核匹配 ATT = " %6.3f r(att)

psmatch2 train, pscore(pscore) outcome(lnwage) neighbor(5) common
display as result ">>> 5近邻匹配 ATT = " %6.3f r(att)

* 回到主设定（最近邻k=1+卡尺），在匹配样本上重新加权回归
quietly psmatch2 train, pscore(pscore) outcome(lnwage) ///
    neighbor(1) caliper(0.05) common
reg lnwage train age edu married city if _support == 1 [aweight = _weight], robust
estimates store matched
* psmatch2 自带标准误未考虑倾向得分估计的不确定性，
* 文献惯例：在匹配样本上重新估计回归，推断更可靠

esttab naive matched using "PSM回归结果.rtf", replace ///
    b(%9.3f) se(%9.3f) star(* 0.1 ** 0.05 *** 0.01) ///
    keep(train age edu married city) ///
    mtitles("朴素OLS（有偏）" "匹配样本回归") ///
    title("PSM估计结果（真实效应 = 0.25）") ///
    addnotes("括号内为稳健标准误" "匹配样本回归按 _weight 加权")

*===============================================================
log close
display as result ">>> 全部完成！请到桌面 PSM案例 文件夹查看输出"
