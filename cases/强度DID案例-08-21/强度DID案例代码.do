*===============================================================
* 强度DID（连续处理）完整案例（新手一键运行版）
* 用法：Ctrl+A 全选 -> Ctrl+D 一次运行
* 故事：1000家企业，2018年起500家获得"技改补贴"，补贴强度
*       （占营收比例）在 0.1-0.9 之间连续分布，其余500家为零强度。
*       真实剂量效应 = 0.8 × 强度（线性剂量-反应）
*===============================================================

clear all
set more off
set varabbrev off

*---------------------------------------------------------------
* 0. 设定工作目录（输出文件都在这里找）
*---------------------------------------------------------------
capture log close
log using "强度DID案例.log", replace text

*---------------------------------------------------------------
* 自动检查并安装所需命令（首次联网安装一次即可）
*---------------------------------------------------------------
capture which reghdfe
if _rc ssc install reghdfe, replace
capture which coefplot
if _rc ssc install coefplot, replace

*---------------------------------------------------------------
* 1. 模拟面板数据：1000家企业 × 6年（2015-2020），政策年2018
*    【换用真实数据时，替换这一段即可，后面代码不用动】
*---------------------------------------------------------------
set seed 20260821
set obs 1000
gen id = _n
gen treated = (id <= 500)                    // 处理组：获得补贴
gen dose = 0
replace dose = 0.1 + 0.8*runiform() if treated   // 补贴强度 U(0.1, 0.9)
gen alpha = rnormal(0, 0.3)                  // 企业固定效应

expand 6
bysort id: gen year = 2014 + _n
gen post = (year >= 2018)

* 结果方程：真实剂量效应 = 0.8 × 强度（政策后才生效）
gen y = 2 + alpha + 0.04*(year-2015) + 0.8*dose*post + rnormal(0, 0.25)
*                                   ↑真实剂量效应

xtset id year
save "强度DID案例数据.dta", replace

quietly sum dose if treated, meanonly
display as result ">>> 处理组平均强度 = " %5.3f r(mean) "（ATT_glob 真值 ≈ 0.8 × 均值 = " %5.3f 0.8*r(mean) "）"

*===============================================================
* 2. 传统强度DID（TWFE）：连续强度 × 政策后
*    注意：reghdfe 对面板中的 c.x#i.post 因子写法处理不稳定，
*    手动构造交互项最稳妥
*===============================================================
gen dose_post = dose * post
reghdfe y dose_post, absorb(id year) vce(cluster id)
estimates store twfe
display as result ">>> 强度系数应≈0.8（线性剂量-反应下TWFE可解释）"

*===============================================================
* 3. ATT_glob：二值化后的总体处理效应
*===============================================================
gen treat_post = treated * post
reghdfe y treat_post, absorb(id year) vce(cluster id)
estimates store att
display as result ">>> ATT_glob 应≈0.8×平均强度≈0.40"

*===============================================================
* 4. 分档剂量-反应曲线（稳健性对照）
*===============================================================
xtile q = dose if treated, nq(3)             // 处理组内按强度分三档
replace q = 0 if !treated                    // 零强度对照
gen d1 = (q == 1) * post                     // 手动构造"档位×政策后"
gen d2 = (q == 2) * post
gen d3 = (q == 3) * post
reghdfe y d1 d2 d3, absorb(id year) vce(cluster id)
* 三档系数应递增且大致等距（线性剂量-反应的特征）

* 剂量-反应图：三档效应递增
coefplot, keep(d1 d2 d3) vertical yline(0) ///
    coeflabels(d1="低强度" d2="中强度" d3="高强度") ///
    xtitle("补贴强度分档") ytitle("效应系数") ///
    title("剂量-反应关系（分档估计）")
graph export "强度DID_剂量反应图.png", replace width(2000)

*===============================================================
* 5. 强度分布图（零强度对照 + 处理组强度分布）
*===============================================================
twoway (histogram dose if treated, width(0.04) color(navy%55)), ///
    xtitle("补贴强度") ytitle("频数") ///
    title("处理强度分布（另有500家零强度对照）")
graph export "强度DID_强度分布图.png", replace width(2000)

*===============================================================
log close
display as result ">>> 全部完成！请到桌面 强度DID案例 文件夹查看输出"
