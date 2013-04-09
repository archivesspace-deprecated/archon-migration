<?php

include ('migrclass.php');






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
    global $repository_Map;
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
							print_r($rep);
			        	//$repid=$rep->connect($session, $site, $data);

                      $qreponse= rest_helper($site."/repositories",'','POST', 'json', $session,$data);
                      print_r($qreponse);
                      if (isset($qreponse->id)){$repository_Map[$ID] = $qreponse->id;
                      }
			      }


                    // need to save rep array
                    $odata = new DataHandler('datacache');
                    $odata->save('rep.dat',$repository_Map);


				 		echo "\nCompleted  Repository Migration*********************\n\n\n";
 				 	
}


/*function get_Process_Users($arrUsers,$site,$session){
    $qreponse= rest_helper($site.'/users' ,array('page'=>1,'page_size'=>10),'GET');
    print_r($qreponse);
}
*/
Function Process_Users($arrUsers,$session,$site){
//Achron to Aspace permission mappings
    $Map_Group = array(31=>1,15=>7,7=>8,1=>9, 0=>9);

    global $_ARCHON;
    global $repository_Map;
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
        print_r("JSON\n"+$data);
        $group =array();
        foreach ($Permissions as $key => $value){
        $repid= $repository_Map[$key];
        $groupid =$Map_Group[$value];

           if (!empty($repid)){
               $qreponse= rest_helper($site.'/users', array('password'=>'password', 'groups[]' => "/repositories/{$repid}/groups/{$groupid}"), 'POST', 'json', $session, $data);
               print_r($qreponse);
               echo $qreponse->id ."Has Just been created\n";


           }
        }


    }
    echo "\nCompleted  User Migration*********************\n\n\n";

  // " {"user":"----","username":"test2","name":"test2"}"//





}

?>