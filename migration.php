<?php

include ('migrclass.php');
// include ('json-model.php');



function Begin_ArchonMigration($site,$user,$password)
{
		echo "Welcome to the Archon to Aspace Migration Utility\n";
	//	$site ="http://192.168.1.8:8089";
	//	$password='admin';
	//	$user='admin';

    $GLOBALS['aspace_backend'] = $site;

    $session = get_session($site);
    $GLOBALS['aspace_session'] = $session;
		
			
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
							  $id = $rep->save();
                $repository_Map[$ID] = $id;

			      }


                    // need to save rep array
                   // $odata = new DataHandler('datacache');
                   // $odata->save('rep.dat',$repository_Map);

                    print_r($repository_Map);
				 		echo "\nCompleted  Repository Migration*********************\n\n\n";
 				 	
}


/*function get_Process_Users($arrUsers,$site,$session){
    $qreponse= rest_helper($site.'/users' ,array('page'=>1,'page_size'=>10),'GET');
    print_r($qreponse);
}
*/
Function Process_Users($arrUsers,$session,$site){
//Achron to Aspace permission mappings

    /*
     * Archon User Map
     * 31 = Admin
     * 15 = Power user
     * 7 = user
     * 1 = readonly
     *
     *
     */
    $Map_Group = array(31=>1,15=>7,7=>8,1=>9);
   // $repository_Map =array();
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

            if($value==31){

                //may need to move to repository default processing
                if (array_key_exists($key,$repository_Map)){
              create_Admin_GroupforRepository($repid,$site,$session );}


            }
            else
            {   if(in_array($value,$Map_Group)){


                $groupid =$Map_Group[$value];

                 }
                else
                {
                    $groupid =9; //default read only access

                }
            }


            }

            echo "\n";
   // echo "/repositories/{$repid}/groups/{$groupid}";
            echo "\n";
           if (!empty($repid)){
               echo "\"/repositories/{$repid}/groups/{$groupid}\"";
               echo "\n";
               $groupstring =  "'/repositories/{$repid}/groups/{$groupid}'";
               echo "\n";
               $qreponse= rest_helper($site.'/users', array('password'=>'password', 'groups[]' => $groupstring), 'POST', 'json', $session, $data);
               print_r($qreponse);
               echo $qreponse->id ."Has Just been created\n";


           }
        }



    echo "\nCompleted  User Migration*********************\n\n\n";

 





}
Function create_Admin_GroupforRepository($repid,$site,$session){


    $perm = Array('system_config',
                    'manage_users',
                    'view_all_records',
                    'create_repository',
                    'index_system',
                    'manage_repository',
                    'update_location_record',
                    'update_subject_record',
                    'update_agent_record',
                    'update_archival_record',
                    'update_event_record',
                    'suppress_archival_record',
                    'delete_archival_record',
                    'view_suppressed',
                    'view_repository'
                    );



    $newgroup = new Aspace_group();
    $newgroup->uri=" /repositories/{$repid}/groups/1";
    $newgroup->group_code='administrators';
    $newgroup->description='Administrators';
    $newgroup->member_usernames=Array('');
    $newgroup->grants_permissions=$perm;


    $data =json_encode($newgroup);

    $qreponse= rest_helper($site."/repositories/{$repid}/groups",'','POST', 'json', $session,$data);
    print_r($qreponse);





}
?>