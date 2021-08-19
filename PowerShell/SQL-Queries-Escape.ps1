# Functions for work with SQL queries

function sql_escape
{
	param(
		[string] $value
	)

	#$escapers = @("\", "`"", "`n", "`r", "`t", "`x08", "`x0c", "'", "`x1A", "`0");
	#$replacements = @("\\", "\`"", "\n", "\r", "\t", "\f", "\b", "\'", "\Z", "\0");

	return $value.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n').Replace("`r", '\r').Replace("'", "\'").Replace("`0", '\0').Replace("`t", '\t').Replace("`f", '\f').Replace("`b", '\b').Replace([string][char]([convert]::toint16('1A', 16)), '\Z')
}

<#
 *  \brief Replace placeholders with numbered parameters (zero-based)
 *  
 *  \return Return replaced string
 *  
 *  \details {d0} - safe integer
 *           {s0} - safe trimmed sql string
 *           {f0} - safe float
 *           {r0} - unsafe raw string
 *           @    - DB_PREFIX
 *           {{   - {
 *           {@   - @
 *           {#   - #
 *           {!   - !
 *           #    - safe integer (param by order)
 *           !    - safe trimmed sql string (param by order)
#>

function rpv
{
	param(
		[string] $string,
		[array] $data
	)

	$out_string = ''
	$len = $string.Length
	$n = 0

	$i = 0

	while($i -lt $len)
	{
		if($string[$i] -eq '#')
		{
			$out_string += try { [int] $data[$param] } catch { 0 }
			$n++
		}
		elseif($string[$i] -eq '!')
		{
			$out_string += "'" + (sql_escape -value $data[$n]) +"'"
			$n++
		}
		elseif($string[$i] -eq '{')
		{
			$i++
			if($string[$i] -eq '{')
			{
				$out_string += '{'
			}
			elseif($string[$i] -eq '@')
			{
				$out_string += '@'
			}
			elseif($string[$i] -eq '#')
			{
				$out_string += '#'
			}
			elseif($string[$i] -eq '!')
			{
				$out_string += '!'
			}
			else
			{
				$prefix = $string[$i]
				$param = ''
				$i++
				while($string[$i] -ne '}')
				{
					$param += $string[$i]
					$i++
				}

				$param = try { [int] $param } catch { 0 }

				switch($prefix)
				{
					'd' {
							$out_string += try { [int] $data[$param] } catch { 0 }
						}
					's' {
							$out_string += "'" + (sql_escape -value $data[$param]) + "'"
						}
					'f' {
							$out_string += try { [double] $data[$param] } catch { 0 }
						}
					'r' {
							$out_string += $data[$param]
						}
				}
			}
		}
		else
		{
			$out_string += $string[$i]
		}

		$i++
	}

	return $out_string
}



