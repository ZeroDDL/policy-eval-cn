# Windows 下 Stata 批处理运行（已验证）

## 标准运行命令（PowerShell）

```powershell
Start-Process -FilePath 'D:\Program Files\Stata18\StataMP-64.exe' -ArgumentList '/e','do','文件名.do' -WorkingDirectory '<可写目录>' -Wait -PassThru
```

- 可执行文件路径以 `config.txt` 中 `stata=` 为准。
- `-WorkingDirectory` 设为 do 文件所在文件夹；**必须可写**（不能在 `Program Files` 下），否则日志无法生成、静默失败。
- 日志生成在工作目录下，与 do 文件同名（`文件名.log`）。

## 关键坑（都踩过，务必遵守）

1. **不要用 Bash 工具调 Stata**：MSYS 会把 `/e` 参数转成路径，导致参数丢失。只用 PowerShell 工具。
2. **不要省 `-Wait`**：直接 `&` 调用 GUI 程序不等待，会读不到日志。
3. **装包只走 SSC**：`raw.githubusercontent.com` 在国内网络环境下经常不可达，`net install ... from("https://raw.githubusercontent.com/...")` 会报 host not found。do 文件里统一用：
   ```stata
   capture which <命令名>
   if _rc ssc install <命令名>, replace
   ```
4. **rddensity 必须加 all**：`ssc install rddensity, all replace`，否则附属文件 `rddensity_fun.do` 缺失，运行时报 r(601)；且需先装 `lpdensity`。加 all 后附属文件会落在当前工作目录，属正常，勿删。
5. **路径含中文/空格**：传给 Stata 的每个参数用单引号独立包裹；do 文件内部 `cd`/`use` 的路径加双引号。

## 报错排查流程

1. 读同名 log，定位第一个 `r(...)` 错误行；
2. 常见错误对照：
   - `r(601)` 文件找不到 → 路径或 rddensity 附属文件问题；
   - `r(199)` 命令不认识 → 对应包没装上（检查 ssc install 是否成功）；
   - `r(198)` 语法错误 → 检查 do 文件编辑是否破坏了语法（中文逗号、全角引号是高发原因——do 文件必须用英文标点）；
3. 修复后重跑，直到 log 中出现模板末尾的"全部完成"标记。

## 结果提取

从 log 中提取：`reghdfe`/`csdid` 等回归表的核心系数行、`display` 输出的 `>>>` 标记行（案例模板的关键结果都带这个前缀）、graph export 生成的 png 清单。
