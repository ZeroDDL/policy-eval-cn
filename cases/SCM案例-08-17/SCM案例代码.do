*===============================================================
* SCM合成控制法完整案例（新手一键运行版）
* 用法：Ctrl+A 全选 -> Ctrl+D 一次运行
* 故事：省份1于2016年率先试点"低碳发展政策"，其余30省未试点，
*       评估试点对碳排放强度（y）的影响。真实效应 = -0.08
*===============================================================

clear all
set more off
set varabbrev off

*---------------------------------------------------------------
* 0. 设定工作目录（输出文件都在这里找）
*---------------------------------------------------------------
capture log close
log using "SCM案例.log", replace text

*---------------------------------------------------------------
* 自动检查并安装所需命令（首次联网安装一次即可）
*---------------------------------------------------------------
capture which synth
if _rc ssc install synth, replace

*---------------------------------------------------------------
* 1. 模拟面板数据：31省 × 23年（2000-2022），2016年为政策年
*    【换用真实数据时，替换这一段即可，后面代码不用动】
*---------------------------------------------------------------
set seed 20260817
set obs 31
gen id     = _n
gen lambda = 0.5 + runiform()          // 因子载荷：省份对共同趋势的敏感度
gen x      = rnormal(0, 1)             // 省份特征（不随时间变化）：产业结构指数
gen mu     = rnormal(0, 0.08)          // 省份固定截距

expand 23
bysort id: gen year = 1999 + _n
xtset id year

gen f   = 0.15*sin((year-2000)/3.5)      // 共同时间趋势（周期波动，无长期漂移）
gen post    = (year >= 2016)
gen treated = (id == 1)              // 处理单元：省份1

* 结果方程：碳排放强度；真实政策效应 = -0.08（试点后下降）
gen y = 2 + lambda*f + 0.1*x + mu - 0.08*post*treated + rnormal(0, 0.015)
*                                       ↑真实效应

label var y "碳排放强度"
save "SCM案例数据.dta", replace

*===============================================================
* 2. 基准合成控制：构造"合成省份1"
*===============================================================
synth y x y(2005) y(2010) y(2015), ///
    trunit(1) trperiod(2016) fig keep("synth_main.dta") replace
* 输出：合成权重表 + 政策前 RMSPE + 路径对比图
graph export "SCM_路径对比图.png", replace width(2000)

* 政策后逐年处理效应 = 处理单元 - 合成对照
* 注意：keep 文件尾部有 31 行权重记录（_time 缺失），须先剔除
use "synth_main.dta", clear
keep if !missing(_time)
rename _time year
gen effect = _Y_treated - _Y_synthetic
list year effect if year >= 2014, noobs
twoway line effect year, xline(2015.5, lpattern(dash)) ///
    yline(0, lcolor(gs10)) yline(-0.08, lcolor(red) lpattern(dash)) ///
    xtitle("年份") ytitle("处理效应（实际-合成）") ///
    title("政策后处理效应路径（红线为真实效应 -0.08）")
graph export "SCM_处理效应路径.png", replace width(2000)

*===============================================================
* 3. In-space 安慰剂检验（置换检验）
*    把每个省份依次"假装"为处理单元，比较政策后/前 RMSPE 比值：
*    若省份1的比值在 31 个单元中最大，p 值 = 名次/31
*===============================================================
use "SCM案例数据.dta", clear
matrix PL = J(31, 3, .)                 // 存：单元编号、政策前RMSPE、政策后RMSPE
forvalues i = 1/31 {
    quietly use "SCM案例数据.dta", clear
    if `i' != 1 quietly drop if id == 1    // 关键：供体池须剔除真处理单元
    quietly synth y x y(2005) y(2010) y(2015), ///
        trunit(`i') trperiod(2016) keep("synth_plc.dta") replace
    quietly {
        use "synth_plc.dta", clear
        keep if !missing(_time)            // keep 文件尾部含权重行，须剔除
        gen diff2 = (_Y_treated - _Y_synthetic)^2
        sum diff2 if _time < 2016, meanonly
        local pre = sqrt(r(mean))
        sum diff2 if _time >= 2016, meanonly
        local post = sqrt(r(mean))
        * 同时保存每个单元的效应路径，供安慰剂图使用
        gen eff = _Y_treated - _Y_synthetic
        keep _time eff
        rename _time year
        rename eff eff_`i'
        save "eff_`i'.dta", replace
    }
    matrix PL[`i',1] = `i'
    matrix PL[`i',2] = `pre'
    matrix PL[`i',3] = `post'
}

* 政策后/政策前 RMSPE 比值排名（安慰剂检验的 p 值）
* 按 Abadie 等惯例：剔除政策前拟合过差（>2倍处理单元）的安慰剂
clear
svmat PL
rename PL1 unit
rename PL2 pre_rmspe
rename PL3 post_rmspe
gen ratio = post_rmspe / pre_rmspe
quietly sum pre_rmspe if unit == 1, meanonly
local pre1 = r(mean)
keep if pre_rmspe <= 2*`pre1'
gsort -ratio
gen rank = _n
quietly count
local n_kept = r(N)
list unit pre_rmspe post_rmspe ratio rank if unit == 1 | rank <= 3, noobs
quietly sum rank if unit == 1, meanonly
display as result ">>> 安慰剂检验 p 值 = " r(mean) "/" `n_kept' " ≈ " %5.3f r(mean)/`n_kept'

* 安慰剂路径图：灰线为 30 个假处理效应，黑线为真实处理效应
use "eff_1.dta", clear
forvalues i = 2/31 {
    quietly merge 1:1 year using "eff_`i'.dta", nogen
}
twoway (line eff_2-eff_31 year, lcolor(gs12%50) lwidth(vthin)) ///
       (line eff_1 year, lcolor(black) lwidth(medthick)), ///
    xline(2015.5, lpattern(dash)) yline(0, lcolor(gs10)) ///
    legend(order(31 "真实处理（省份1）" 1 "安慰剂（30省）")) ///
    xtitle("年份") ytitle("效应（实际-合成）") ///
    title("In-space 安慰剂检验：真实效应应最极端")
graph export "SCM_安慰剂检验图.png", replace width(2000)
forvalues i = 1/31 {
    erase "eff_`i'.dta"
}
erase "synth_plc.dta"

*===============================================================
* 4. In-time 安慰剂检验：虚构政策提前到 2012 年（应无效应）
*===============================================================
use "SCM案例数据.dta", clear
synth y x y(2005) y(2008) y(2011), ///
    trunit(1) trperiod(2012) fig keep("synth_intime.dta") replace
graph export "SCM_intime检验图.png", replace width(2000)
* 虚构时点前后路径应始终重合，无系统分岔

*===============================================================
log close
display as result ">>> 全部完成！请到桌面 SCM案例 文件夹查看输出"
