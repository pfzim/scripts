$clients = @{
	"SQL_SystemDB" = @{
		"srv-1c-03.conoso.com" = @{
			"Full-Day" = @{
				"interval" = 7; 
				"dblist" = @{
					"model" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "modeldev"; 
						"log" = "modellog"
					}; 
					"master" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "master"; 
						"log" = "mastlog"
					}; 
					"msdb" = @{
						"media" = @(); 
						"nbimage" = $Null; 
						"mdf" = "MSDBData"; 
						"log" = "MSDBLog";
					}
				}
			}
		}; 
	}
}

$list = Get-Content -Path "c:\scripts\logs\NetBackupTestRestore.names.log" -Raw | Invoke-Expression


foreach($p_key in $clients.Keys)
{
    foreach($c_key in $clients[$p_key].Keys)
    {
        foreach($s_key in $clients[$p_key][$c_key].Keys)
        {
			foreach($d_key in $clients[$p_key][$c_key][$s_key].dblist.Keys)
			{
                if($list.Contains($d_key))
                {
                    if($list[$d_key].Contains('mdf'))
                    {
                        $clients[$p_key][$c_key][$s_key].dblist[$d_key].mdf = $list[$d_key].mdf
                    }

                    if($list[$d_key].Contains('log'))
                    {
                        $clients[$p_key][$c_key][$s_key].dblist[$d_key].log = $list[$d_key].log
                    }
                }
            }
        }
    }
}

cls
ConvertTo-PSON -Object $clients -Layers 9
