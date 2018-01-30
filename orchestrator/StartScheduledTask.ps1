$task_name = "ALB_BP_KORP_Clone"

$sess = New-PSSession -ComputerName "brc-ssmc-01"
$exit_code = Invoke-Command -Session $sess -ArgumentList $task_name -ScriptBlock {
    Start-ScheduledTask -TaskName $args[0]
}
Remove-PSSession -Session $sess
