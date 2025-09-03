$ErrorActionPreference = "Stop"

$UPDATE=@'
casper_library/Accumulators,casper_library_accumulators
casper_library/Communications,casper_library_communications
casper_library/Correlator,casper_library_correlator
casper_library/Delays,casper_library_delays
casper_library/Downconverter,casper_library_downconverter
casper_library/FFTs/Twiddle/coeff_gen,casper_library_ffts_twiddle_coeff_gen
casper_library/FFTs/Twiddle,casper_library_ffts_twiddle
casper_library/FFTs,casper_library_ffts
casper_library/Flow_Control,casper_library_flow_control
casper_library/Misc,casper_library_misc
casper_library/Multipliers,casper_library_multipliers
casper_library/PFBs,casper_library_pfbs
casper_library/Reorder,casper_library_reorder
casper_library/Scopes,casper_library_scopes
'@

$REVERT=@'
casper_library_accumulators,casper_library/Accumulators
casper_library_communications,casper_library/Communications
casper_library_correlator,casper_library/Correlator
casper_library_delays,casper_library/Delays
casper_library_downconverter,casper_library/Downconverter
casper_library_ffts_twiddle_coeff_gen,casper_library/FFTs/Twiddle/coeff_gen
casper_library_ffts_twiddle,casper_library/FFTs/Twiddle
casper_library_ffts,casper_library/FFTs
casper_library_flow_control,casper_library/Flow_Control
casper_library_misc,casper_library/Misc
casper_library_multipliers,casper_library/Multipliers
casper_library_pfbs,casper_library/PFBs
casper_library_reorder,casper_library/Reorder
casper_library_scopes,casper_library/Scopes
'@

if ($args[0] -eq "-r") {
  $action="reverting"
  $grep_pattern="casper_library_"
  $sed_pattern=$REVERT -split "`n"
  $args = $args[1..($args.Length-1)]
} else {
  $action="updating"
  $grep_pattern="casper_library/"
  $sed_pattern=$UPDATE -split "`n"
}

foreach ($m in $args) {
  if (-not (Test-Path "$m")) {
    echo "$m not found"
    continue
  }
  $content=Get-Content $m
  if (-not ($content -match $grep_pattern)) {
    echo "$m modification not needed"
    continue
  }
  Write-Host -NoNewLine "$action librefs in $m..."
  #mv "$m" "$m.$PID.bak"
  $new_content= @()
  foreach ($line in $content) {
	$modified_line=$line
	foreach ($rule in $sed_pattern) {
		if ($rule -match ",") {
			$parts = $rule -split ",", 2
			$old = [regex]::Escape($parts[0])
			$new = $parts[1]
			$modified_line = $modified_line -replace $old, $new
			$test=$line -match $old
		}
	}
  	$new_content += $modified_line
  }
  #$new_content=$content -replace $sed_pattern
  Set-Content -Path $m -Value $new_content
  #rm "$m.$PID.bak"
  echo ok
}
