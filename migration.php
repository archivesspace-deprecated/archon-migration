<?php

include ('migrclass.php');

function get_session($site){
    $response = rest_helper($site.'/users/admin/login', array('password'=>'admin'),null, 'POST');
    // print_r($response);
    return $response->session;
}


function rest_helper($url, $params = null,$data=null, $verb = 'GET', $format = 'json', $session = null)
{
    $cparams = array(
        'http' => array(
            'method' => $verb,
            'ignore_errors' => true

        )
    );
    if ($session) {
        $cparams['http']['header'] = "X-ArchivesSpace-Session: $session";
    }


    if ($params !== null) {
        $params = http_build_query($params);
        if ($verb == 'POST') {
            $cparams['http']['content'] = $params;
        } else {
            $url .= '?' . $params;
        }
    }

    $context = stream_context_create($cparams);
    $fp = fopen($url, 'rb', false, $context);
    if (!$fp) {
        $res = false;
    } else {
        // If you're trying to troubleshoot problems, try uncommenting the
        // next two lines; it will show you the HTTP response headers across
        // all the redirects:
        $meta = stream_get_meta_data($fp);
        var_dump($meta['wrapper_data']);
        $res = stream_get_contents($fp);
    }

    if ($res === false) {
        throw new Exception("$verb $url failed: $php_errormsg");
    }

    switch ($format) {
        case 'json':
            $r = json_decode($res);
            if ($r === null) {
                throw new Exception("failed to decode $res as json");
            }
            return $r;

        case 'xml':
            $r = simplexml_load_string($res);
            if ($r === null) {
                throw new Exception("failed to decode $res as xml");
            }
            return $r;
    }
    return $res;
}



function Begin_ArchonMigration($site,$user,$password)
{
		echo "Welcome to the Archon to Aspace Migration Utility\n";
	//	$site ="http://192.168.1.8:8089";
	//	$password='admin';
	//	$user='admin';

    $session = get_session($site);
		
			
			if (strlen($session)>0){
			    echo "\nLogin Sucessfull\n";
			    echo "\n";
					echo "Your session is ".$session  . "\n";
			 
			}
			
		return $session;
}


function Process_Repository ($arrRepositories,$session,$site)
{				
		global $_ARCHON;
		global $arrCountries;
					echo "\n\nSITE:".$site	;
				 	echo "\n\n\nProceding to Migrate Repositories*********************\n\n\n";
				 	foreach($arrRepositories as  $Repository)
			      {
			      		extract ((array)$Repository);
			       		$rep = new Aspace_repository();
			        //	$rep->description=$Name;
			        //	$rep->repo_code=$Code;
			        	$rep->name= $Name;
							//	$rep->= $Administrator;
								$rep->repo_code=$Code;
								$rep->address_1=$Address;
								$rep->address_2=$Address2;
								$rep->city=$City;
								$rep->district=$State;
								echo $CountryID;
							$fixCountry= $arrCountries[$CountryID]->ISOAlpha2;
							//	$fixCountry=$_ARCHON->mdb2->query($query);
								echo "\n**fixcountry***".$fixCountry."\n" ;
								$rep->country=$fixCountry;
								$rep->post_code=$ZIPCode . $ZIPPlusFour;
								$rep->telephone=$Phone;
								$rep->telephone_ext=$PhoneExtension;
								$rep->fax=$Fax;
								$rep->email=$Email;
								$rep->url=$URL;
								$rep->email_signature=$EmailSignature;
							$data =json_encode($rep);
						//	print_r($rep);
			        	$repid=$rep->connect($session, $site, $data);
			      }
				 		echo "\nCompleted  Repository Migration*********************\n\n\n";
 				 	
}


function get_Process_Users($arrUsers,$site,$session){
    $qreponse= rest_helper($site.'/users' ,array('page'=>1,'page_size'=>10),'GET');
    print_r($qreponse);
}

Function Process_Users($arrUsers,$session,$site){
//Achron to Aspace permission mappings
    $Map_Group = array(31=>'/groups/1',15=>'/groups/7',7=>'/groups/8',1=>'/groups/9');

    global $_ARCHON;

    echo "\n\nSITE:".$site	;
    echo "\n\n\nProceding to Migrate USERS*********************\n\n\n";
    foreach($arrUsers as  $USER)
    {   print_r($USER);
        extract ((array)$USER);
        $_user = new Aspace_user();
        $_user->username = $Login;
        $name= ( trim($displayname) != false)? $displayname : $firstname . " " . $lastname;
        $name = (trim($name)!= false)?$name:$Login;
        $_user->name=$name;

        $data =json_encode($_user);
        	print_r($_user);
        //$userid=$_user->connect($session, $site, $data);
        $qreponse= rest_helper($site.'/users' ,array('password' =>'password',array('group'=> '/groups/1'),$data) ,null,'POST','json' ,$session);
        print_r($qreponse);
        echo $qreponse->userid ."Has Just been created\n";
    }
    echo "\nCompleted  User Migration*********************\n\n\n";

  // " {"user":"----","username":"test2","name":"test2"}"//





}

?>