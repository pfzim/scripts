<?php
// Runbook starter through CURL

	if(!defined('ROOTDIR'))
	{
		define('ROOTDIR', dirname(__FILE__));
	}

	if(!file_exists(ROOTDIR.DIRECTORY_SEPARATOR.'inc.config.php'))
	{
		header('Location: install.php');
		exit;
	}

	error_reporting(E_ALL);
	define('Z_PROTECTED', 'YES');

	require_once(ROOTDIR.DIRECTORY_SEPARATOR.'inc.config.php');

	header("Content-Type: text/plain; charset=utf-8");
	
	if(empty($_GET['id']))
	{
		exit;
	}

	$request = <<<'EOT'
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<entry xmlns:d="http://schemas.microsoft.com/ado/2007/08/dataservices" xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata" xmlns="http://www.w3.org/2005/Atom">
    <content type="application/xml">
        <m:properties>
EOT;

	$request .= '<d:RunbookId m:type="Edm.Guid">'.$_GET['id'].'</d:RunbookId>';

	if(!empty($_GET['param']))
	{
		$request .= '<d:Parameters><![CDATA[<Data>';
		foreach($_GET['param'] as $key => $value)
		{
			$request .= '<Parameter><ID>{'.$key.'}</ID><Value>'.$value.'</Value></Parameter>';
		}
		$request .= '</Data>]]></d:Parameters>';
	}
	$request .= <<<'EOT'
        </m:properties>
    </content>
</entry>
EOT;

	$ch = curl_init();

	curl_setopt($ch, CURLOPT_URL, ORCHESTRATOR_URL);
	curl_setopt($ch, CURLOPT_POST, true);
	curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_NTLM);
	curl_setopt($ch, CURLOPT_USERPWD, LDAP_USER.':'.LDAP_PASSWD);
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
	curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/atom+xml'));
	curl_setopt($ch, CURLOPT_POSTFIELDS, $request);


	$output = curl_exec($ch);
	$result = curl_getinfo($ch);

	echo 'HTTP status code: '.$result['http_code'];
	
	//echo $request;
	//echo "\r\n\r\n\r\n----------------------------------------------------------\r\n\r\n\r\n";
	/*
	echo $output;

	$xml = @simplexml_load_string($output);
	if($xml !== FALSE)
	{
		echo 'ID: '.$xml->entry->content->children('d', true)->Id;
	}
	*/

