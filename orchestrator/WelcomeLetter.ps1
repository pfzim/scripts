$smtp_from = "orchestrator@contoso.com"
$smtp_to = ""
$smtp_bc = "wt@contoso.com"
$smtp_creds = New-Object System.Management.Automation.PSCredential ("", (ConvertTo-SecureString "" -AsPlainText -Force))
$smtp_server = "smtp.contoso.com"

$body = Get-Content -Path C:\Orchestrator\template-mail\index.html -Encoding UTF8 | Out-String

Send-MailMessage -from $smtp_from -to -cc $smtp_to, $smtp_cc -Encoding UTF8 -subject "Welcome letter!" -bodyashtml -body $body -Attachments "C:\Orchestrator\template-mail\ph.png", "C:\Orchestrator\template-mail\top.png", "C:\Orchestrator\template-mail\Attachment-1.pdf" -smtpServer $smtp_server -Credential $smtp_creds
