param(
  [string]$Save     = "$env:USERPROFILE\AppData\LocalLow\TesseractStudio\TaskbarHero\SaveFile_Live.es3",
  [string]$Password = "emuMqG3bLYJ938ZDCfieWJ",
  [int]$Poll        = 15,
  [switch]$NoToast,
  [switch]$Once
)

$ErrorActionPreference = 'Stop'
$Root      = Split-Path -Parent $MyInvocation.MyCommand.Path
$Advisor   = Join-Path $Root 'monitor\advisor.cjs'
$StateFile = Join-Path $Root 'runtime\state.json'
$EventFile = Join-Path $Root 'runtime\event.json'
$LogFile   = Join-Path $Root 'runtime\monitor.log'
$TmpRaw    = Join-Path $env:TEMP 'tbh_monitor_raw.json'
$ToastAppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

$rt = Join-Path $Root 'runtime'; if(-not (Test-Path $rt)){ New-Item -ItemType Directory -Path $rt | Out-Null }
if(-not (Test-Path $Advisor)){ Write-Host "advisor bridge nao encontrado: $Advisor" -ForegroundColor Red; exit 1 }
if(-not (Get-Command node -ErrorAction SilentlyContinue)){ Write-Host "node nao esta no PATH — o monitor precisa do node pra rodar o engine." -ForegroundColor Red; exit 1 }

function Read-Bytes($path){
  for($i=0;$i -lt 8;$i++){ try { return [System.IO.File]::ReadAllBytes($path) } catch { Start-Sleep -Milliseconds 250 } }
  return $null
}
function Decrypt-Raw($path,$pw){
  $bytes = Read-Bytes $path
  if(-not $bytes){ return $null }
  try {
    $iv = New-Object byte[] 16; [Array]::Copy($bytes,0,$iv,0,16)
    $cipher = New-Object byte[] ($bytes.Length-16); [Array]::Copy($bytes,16,$cipher,0,$bytes.Length-16)
    $d = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pw,$iv,100); $key=$d.GetBytes(16)
    $a = New-Object System.Security.Cryptography.AesManaged; $a.Mode='CBC'; $a.Padding='PKCS7'; $a.Key=$key; $a.IV=$iv
    $plain = $a.CreateDecryptor().TransformFinalBlock($cipher,0,$cipher.Length)
    if($plain.Length -ge 2 -and $plain[0] -eq 0x1f -and $plain[1] -eq 0x8b){
      $msIn = New-Object System.IO.MemoryStream(,$plain)
      $gz   = New-Object System.IO.Compression.GZipStream($msIn,[System.IO.Compression.CompressionMode]::Decompress)
      $msOut= New-Object System.IO.MemoryStream
      $gz.CopyTo($msOut); $gz.Dispose()
      $plain = $msOut.ToArray()
    }
    $json  = [System.Text.Encoding]::UTF8.GetString($plain)
    $outer = $json | ConvertFrom-Json
    return [string]$outer.PlayerSaveData.value
  } catch { return $null }
}

function Get-Advice($rawValue,$gps){
  [System.IO.File]::WriteAllText($TmpRaw,$rawValue,(New-Object System.Text.UTF8Encoding($false)))
  $a = @($Advisor, $TmpRaw)
  if($null -ne $gps){ $a += [string]([math]::Round($gps,2)) }
  try {
    $jsonOut = (& node @a) -join ''
    if(-not $jsonOut){ return $null }
    $adv = $jsonOut | ConvertFrom-Json
    if($adv.PSObject.Properties.Name -contains 'error'){ Write-Host "  advisor: $($adv.error)" -ForegroundColor DarkYellow; return $null }
    return $adv
  } catch { return $null }
}

function Show-Toast($title,$text){
  if($NoToast){ return }
  try {
    [void][Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument,Windows.Data.Xml.Dom,ContentType=WindowsRuntime]
    $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $tn  = $xml.GetElementsByTagName('text')
    [void]$tn.Item(0).AppendChild($xml.CreateTextNode([string]$title))
    [void]$tn.Item(1).AppendChild($xml.CreateTextNode([string]$text))
    $toast = New-Object Windows.UI.Notifications.ToastNotification($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($ToastAppId).Show($toast)
  } catch { }
}
function Alert($icon,$title,$text){
  Write-Host ("  {0}  {1} — {2}" -f $icon,$title,$text) -ForegroundColor Yellow
  Show-Toast ("TBH · " + $title) $text
  try {
    Add-Content -Path $LogFile -Value ("{0}`t{1}`t{2}" -f (Get-Date).ToString('s'),$title,$text) -Encoding UTF8
    @{ type='alert'; time=(Get-Date).ToString('s'); title=$title; text=$text } | ConvertTo-Json | Set-Content -Path $EventFile -Encoding UTF8
  } catch { }
}

function LevelMap($adv){ $m=@{}; foreach($l in @($adv.levels)){ $m["$($l.hero)"]=$l } ; return $m }
function Fmt($n){ try { return ('{0:N0}' -f [double]$n) } catch { return "$n" } }

$script:samples = New-Object System.Collections.ArrayList
function Sample-Gps($playTime,$gold){
  $last = if($script:samples.Count){ $script:samples[$script:samples.Count-1] } else { $null }
  if(-not $last -or $last.pt -ne $playTime -or $last.g -ne $gold){ [void]$script:samples.Add([pscustomobject]@{pt=$playTime;g=$gold}) }
  while($script:samples.Count -gt 60){ $script:samples.RemoveAt(0) }
  if($script:samples.Count -lt 2){ return $null }
  $gain=0.0; $dt=0.0
  for($i=1;$i -lt $script:samples.Count;$i++){
    $dp = $script:samples[$i].pt - $script:samples[$i-1].pt
    $dg = $script:samples[$i].g  - $script:samples[$i-1].g
    if($dp -gt 0){ $dt += $dp; if($dg -gt 0){ $gain += $dg } }
  }
  if($dt -gt 0){ return ($gain/$dt) } else { return $null }
}

function Compare-Advice($prev,$a){
  $pm = LevelMap $prev
  foreach($l in @($a.levels)){
    $p = $pm["$($l.hero)"]
    if($p){
      if([int]$l.level -gt [int]$p.level){ Alert '' 'Subiu de nível' ("$($l.heroName) chegou ao Lv$($l.level)") }
      if([int]$l.ap -gt [int]$p.ap -and [int]$l.ap -gt 0){ Alert '' 'Pontos pra gastar' ("$($l.heroName) tem $($l.ap) ponto(s) de habilidade não gasto(s)") }
    }
  }
  if($null -ne $a.maxStage -and $null -ne $prev.maxStage -and [int]$a.maxStage -gt [int]$prev.maxStage){
    Alert '' 'Stage novo limpo' ("avançou para [$($a.maxStage)] — novos drops disponíveis")
  }
  if($null -ne $a.firstDpsCost){
    $prevAff = ($null -ne $prev.firstDpsCost) -and ([double]$prev.gold -ge [double]$prev.firstDpsCost)
    $nowAff  = [double]$a.gold -ge [double]$a.firstDpsCost
    if($nowAff -and -not $prevAff){
      Alert '' 'Dá pra comprar DPS' ("já tem ouro pra corrente até $($a.firstDpsTargetName) ($(Fmt $a.firstDpsCost) g)")
    }
  }
  $prevSwaps=@{}; foreach($s in @($prev.swaps)){ $prevSwaps["$($s.hero)-$($s.gt)"]=$true }
  foreach($s in @($a.swaps)){
    if([double]$s.dPower -gt 0){
      $k = "$($s.hero)-$($s.gt)"
      if(-not $prevSwaps.ContainsKey($k)){ Alert '' 'Upgrade de equipamento' ("$($s.heroName): +$(Fmt $s.dPower) POWER trocando o $($s.gt)") }
    }
  }
  if([int]$a.almostFreeAffordable -gt [int]$prev.almostFreeAffordable){
    Alert '' 'Runa quase de graça' ("$($a.almostFreeAffordable) runa(s) baratíssima(s) que dá pra comprar agora")
  }
  if([math]::Floor([double]$a.gold/100000) -gt [math]::Floor([double]$prev.gold/100000)){
    Alert '' 'Marco de ouro' ("cruzou $([math]::Floor([double]$a.gold/100000)*100)k — agora $(Fmt $a.gold)")
  }
  if("$($a.party)" -ne "$($prev.party)"){ Alert '' 'Party mudou' ("[$($prev.party)]  [$($a.party)]") }
  if([int]$a.pets -gt [int]$prev.pets){ Alert '' 'Novo pet' ("desbloqueou um pet (total $($a.pets))") }
  if($a.survival -and $prev.survival){
    if(($a.survival.survivable -eq $true) -and ($prev.survival.survivable -ne $true)){
      Alert '' 'Dá pra empurrar' ("agora você sobrevive em $($a.survival.lvl) — suba de stage")
    }
  }
}

function Status-Line($a){
  $gps = Sample-Gps ([int]$a.playTime) ([double]$a.gold)
  $gph = if($null -ne $gps){ " · " + (Fmt ($gps*3600)) + "/h" } else { "" }
  $surv = if($a.survival){ " · push:$($a.survival.rating)" } else { "" }
  $line = ("[{0}]  {1}{2}  POWER {3}  {4}{5}" -f (Get-Date).ToString('HH:mm:ss'),(Fmt $a.gold),$gph,(Fmt $a.partyPower),$a.curStageLabel,$surv)
  Write-Host $line -ForegroundColor Gray
  return $gps
}

function Save-State($a){
  try { @{ time=(Get-Date).ToString('s'); advice=$a } | ConvertTo-Json -Depth 8 | Set-Content -Path $StateFile -Encoding UTF8 } catch { }
}
function Load-Prev(){
  if(-not (Test-Path $StateFile)){ return $null }
  try { $s = Get-Content -Path $StateFile -Raw | ConvertFrom-Json; return $s.advice } catch { return $null }
}

Write-Host ""
Write-Host "  TBH CO·PILOT — WATCHER" -ForegroundColor Cyan
Write-Host ("  save: {0}" -f $Save) -ForegroundColor DarkGray
$toastState = if($NoToast){'off'}else{'on'}
Write-Host ("  toasts: {0} · poll: {1}s · engine: monitor/advisor.cjs" -f $toastState,$Poll) -ForegroundColor DarkGray
Write-Host ""

if(-not (Test-Path $Save)){ Write-Host "  save nao encontrado — abra o jogo uma vez." -ForegroundColor Red; exit 1 }

$prev = Load-Prev
$gpsNow = $null

$raw = Decrypt-Raw $Save $Password
if(-not $raw){ Write-Host "  falha ao decriptar no startup (a senha pode ter mudado num update)." -ForegroundColor Red; exit 1 }
$a = Get-Advice $raw $null
if(-not $a){ Write-Host "  o engine nao conseguiu computar (veja monitor/advisor.cjs)." -ForegroundColor Red; exit 1 }
$gpsNow = Status-Line $a
if($prev){ Compare-Advice $prev $a } else { Write-Host "  (baseline — vou avisar quando algo mudar)" -ForegroundColor DarkGray }
Save-State $a
$prev = $a
$lastWrite = (Get-Item $Save).LastWriteTimeUtc

if($Once){ Write-Host ""; Write-Host "  -Once: feito." -ForegroundColor DarkGray; exit 0 }

while($true){
  Start-Sleep -Seconds $Poll
  $fi = Get-Item $Save -ErrorAction SilentlyContinue
  if(-not $fi){ continue }
  if($fi.LastWriteTimeUtc -eq $lastWrite){ continue }
  $lastWrite = $fi.LastWriteTimeUtc
  $raw = Decrypt-Raw $Save $Password
  if(-not $raw){ Alert '' 'Senha mudou?' 'o save mudou mas não decripta — provável update do jogo'; continue }
  $a = Get-Advice $raw $gpsNow
  if(-not $a){ continue }
  $gpsNow = Status-Line $a
  Compare-Advice $prev $a
  Save-State $a
  $prev = $a
}
