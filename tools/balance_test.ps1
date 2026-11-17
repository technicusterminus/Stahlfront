# Balance-Messreihe: KI gegen KI, jede Fraktion an jeder Startposition.
# Aufruf: powershell -File tools/balance_test.ps1 -Godot <pfad> -Seeds "7,31,55" -Quit 650 -Out ergebnis.txt
param(
    [string]$Godot,
    [string]$Seeds = "7,31,55",
    [int]$Quit = 650,
    [int]$Speed = 6,
    [string]$Out = "balance_result.txt"
)
$proj = Split-Path -Parent $PSScriptRoot
Set-Location $proj
"" | Set-Content $Out
$rows = @()
foreach ($s in ($Seeds -split "," | ForEach-Object { [int]$_ })) {
    foreach ($f in "west", "red", "shadow") {
        $o = & $Godot --headless --path . -- --demo --enemies=2 --seed=$s --faction=$f --speed=$Speed --quit=$Quit 2>&1
        $err = ($o | Select-String -Pattern "SCRIPT ERROR").Count
        foreach ($l in ($o | Select-String -Pattern "^P\d")) {
            if ($l.Line -match "^P(\d) (\w+) alive=(\w+) credits=(\d+) units=(\d+) bldgs=(\d+) kills=(\d+) losses=(\d+)") {
                $rows += [pscustomobject]@{Seed = $s; Start = $f; Pos = [int]$matches[1]; Fac = $matches[2]; Alive = $matches[3]; Units = [int]$matches[5]; Bldgs = [int]$matches[6]; Kills = [int]$matches[7]; Losses = [int]$matches[8]; Errors = $err}
            }
        }
    }
}
$rows | Export-Csv -NoTypeInformation -Path "$Out.csv"
$sum = $rows | Group-Object Fac | ForEach-Object {
    $g = $_.Group
    [pscustomobject]@{
        Fraktion = $_.Name
        Laeufe = $g.Count
        Ueberlebt = ($g | Where-Object { $_.Alive -eq "true" }).Count
        KillsSchnitt = [math]::Round(($g | Measure-Object Kills -Average).Average, 0)
        VerlusteSchnitt = [math]::Round(($g | Measure-Object Losses -Average).Average, 0)
        EinheitenEnde = [math]::Round(($g | Measure-Object Units -Average).Average, 0)
        GebaeudeEnde = [math]::Round(($g | Measure-Object Bldgs -Average).Average, 0)
    }
}
($sum | Format-Table -AutoSize | Out-String) | Add-Content $Out
"Skriptfehler gesamt: " + ($rows | Measure-Object Errors -Sum).Sum | Add-Content $Out
