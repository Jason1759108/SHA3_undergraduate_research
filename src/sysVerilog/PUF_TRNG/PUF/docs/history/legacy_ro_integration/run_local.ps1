# Convenience launcher for this computer; override paths on another machine.
param(
    [ValidateSet('all','ecc','ro','count','wave','puf')][string]$Mode='all',
    [string]$Python='C:\Users\a0981\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',
    [string]$Verilator='C:\Users\a0981\Documents\Codex\2026-11-04\puf\work\tools\verilator\bin\verilator_bin.exe',
    [string]$Zig='C:\Users\a0981\Documents\Codex\2026-11-04\puf\work\tools\ziglang\zig.exe'
)
foreach($toolPath in @($Python,$Verilator,$Zig)) {
    if(!(Test-Path -LiteralPath $toolPath)){throw "Tool not found: $toolPath. Override the launcher parameter."}
}
& $Python (Join-Path $PSScriptRoot '00_TESTBED\run_sim.py') --mode $Mode --verilator $Verilator --zig $Zig --vcd
exit $LASTEXITCODE
