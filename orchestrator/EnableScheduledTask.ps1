$task_name = "ALB_UT_Clone"

$sess = New-PSSession -ComputerName "brc-ssmc-01"
$exit_code = Invoke-Command -Session $sess -ArgumentList $task_name -ScriptBlock {
    $task = Enable-ScheduledTask -TaskName $args[0]
    $task = Get-ScheduledTask -TaskName $args[0]
    if($task)
    {
        if($task.State -eq "Ready")
        {
            return 0
        }
    }
    return 1
}
Remove-PSSession -Session $sess
