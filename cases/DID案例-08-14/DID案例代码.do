*===============================================================
* DID模型完整案例（新手一键运行版）
* 用法：Ctrl+A 全选 -> Ctrl+D 一次运行
*===============================================================

clear all
set more off
set varabbrev off

*---------------------------------------------------------------
* 0. 设定工作目录（输出文件都在这里找）
*---------------------------------------------------------------
capture log close
log using "DID案例.log", replace text

*---------------------------------------------------------------
* 安装命令（第一次时，可以把这5行注释*删除）
*---------------------------------------------------------------
*ssc install reghdfe, replace
*ssc install ftools, replace
*ssc install coefplot, replace
*ssc install diff, replace
*ssc install estout, replace

*---------------------------------------------------------------
* 1. 模拟面板数据：1000人 × 10年，2015年政策，真实效应=3
*    【换用真实数据时，替换这一段即可，后面代码不用动】
*---------------------------------------------------------------
*---------------------------------------------------------------
* 1. 模拟面板数据：1000人 × 10年，2015年政策，真实效应=0.4
*    说明：真实效应设为0.4（约为标准误的4倍），
*    真实系数会落在安慰剂分布右尾边缘，可视化最清晰
*---------------------------------------------------------------
set seed 20240101
set obs 1000
gen id    = _n
gen treat = runiform() < 0.3
gen u_i   = rnormal(0, 1) + 1.5*treat

expand 10
bysort id: gen year = 2009 + _n

gen post = year >= 2015
gen did  = treat * post
gen x1   = rnormal(0, 1)
gen x2   = rnormal(5, 2)
gen y    = u_i + 0.2*(year-2010) + 0.4*did + 0.5*x1 + 0.1*x2 + rnormal(0, 1.3)
*                                        ↑真实效应          ↑噪声从1加大到1.3

xtset id year
save "DID案例数据.dta", replace      // 存档，后面随时调用

*===============================================================
* 2. 平行趋势检验（事件研究法，基期=政策前一年）
*===============================================================
gen evt = year - 2015
forvalues k = 5(-1)2 {
    gen pre_`k'  = (evt == -`k') & treat
}
forvalues k = 0/4 {
    gen post_`k' = (evt == `k') & treat
}

reghdfe y pre_5 pre_4 pre_3 pre_2 post_0 post_1 post_2 post_3 post_4 x1 x2, ///
    absorb(id year) vce(cluster id)
estimates store event_study

coefplot event_study, vertical ///
    keep(pre_5 pre_4 pre_3 pre_2 post_0 post_1 post_2 post_3 post_4) ///
    yline(0, lcolor(red) lpattern(dash)) ///
    xline(4.5, lcolor(black) lpattern(dash)) ///
    ciopts(recast(rcap)) recast(connected) ///
    coeflabels(pre_5="-5" pre_4="-4" pre_3="-3" pre_2="-2" ///
               post_0="0" post_1="1" post_2="2" post_3="3" post_4="4") ///
    xtitle("相对政策时点（基期=-1）") ytitle("系数估计值") ///
    title("平行趋势检验（事件研究法）") ///
    note("注：政策前各期系数不显著异于0，平行趋势成立")
graph export "平行趋势检验图.png", replace width(2000)

*===============================================================
* 3. DID基准回归
*===============================================================
reghdfe y did, absorb(id year) vce(cluster id)
estimates store m1

reghdfe y did x1 x2, absorb(id year) vce(cluster id)
estimates store m2

* 真实系数存进数据变量（不用宏不用标量，永不过期）
gen true_beta = _b[did]
display as result ">>> 真实DID系数 = " %6.3f _b[did]

esttab m1 m2 using "DID基准回归结果.rtf", replace ///
    b(%9.3f) se(%9.3f) star(* 0.1 ** 0.05 *** 0.01) ///
    keep(did x1 x2) mtitles("无控制变量" "含控制变量") ///
    title("DID基准回归结果") ///
    addnotes("括号内为个体层面聚类稳健标准误")

*===============================================================
* 4. 安慰剂检验：500次随机分配处理组（全程静默）
*===============================================================
tempfile placebo
postfile pf beta se true_beta using `placebo', replace

quietly forvalues i = 1/500 {
    preserve
    bysort id (year): gen double _r = runiform() if _n == 1
    bysort id: replace _r = _r[1]
    egen _rank = group(_r)
    gen did_fake = (_rank <= 300) * post
    reghdfe y did_fake x1 x2, absorb(id year) vce(cluster id)
    post pf (_b[did_fake]) (_se[did_fake]) (true_beta[1])
    restore
}
postclose pf

use `placebo', clear
gen p_value = 2 * ttail(9998, abs(beta/se))
save "安慰剂检验结果.dta", replace    // 存档：之后重画图不用再跑500次

* --- 散点图：竖线直接引用数据中的真实系数 ---
twoway (scatter p_value beta, msize(small) mcolor(navy%60)) ///
       (scatteri 0 `=true_beta[1]', msymbol(none)), ///
    xline(`=true_beta[1]', lcolor(red) lwidth(medthick)) ///
    yline(0.1, lcolor(gray) lpattern(dash)) ///
    xtitle("随机分配的估计系数") ytitle("p值") ///
    title("安慰剂检验：500次随机化分布") legend(off) ///
    note("注：红色竖线为真实DID系数，随机系数聚集在0附近，说明政策效应非随机")
graph export "安慰剂检验_散点图.png", replace width(2000)

* --- 核密度图：隐形散点强制横轴覆盖真实系数 ---
kdensity beta, nograph generate(kx ky)
twoway (line ky kx, lcolor(navy) lwidth(medthick)) ///
       (scatteri 0 `=true_beta[1]' 0 `=-true_beta[1]', msymbol(none)), ///
    xline(`=true_beta[1]', lcolor(red) lwidth(medthick)) ///
    xline(0, lcolor(gray) lpattern(dash)) ///
    xtitle("随机分配的估计系数") ytitle("核密度") ///
    title("安慰剂检验：估计系数核密度分布") legend(off) ///
    text(0.1 `=true_beta[1]' "真实系数 = `: display %5.2f true_beta[1]' ", ///
         placement(w) color(red)) ///
    note("注：红色竖线为真实DID系数，远在随机分布之外，说明结果非随机驱动")
graph export "安慰剂检验_核密度图.png", replace width(2000)

quietly count if abs(beta) >= true_beta[1]
display as result ">>> 安慰剂检验经验p值 = " %6.4f r(N)/500

*===============================================================
log close
display as result ">>> 全部完成！请到桌面 DID案例 文件夹查看输出"