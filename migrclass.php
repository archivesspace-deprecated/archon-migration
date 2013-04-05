<?php
/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

/**
 * Description of login
 * Sends Generic call to Post  or Get
 *
 *
 * @author randy
 */
 function archrequest($uri,$header,$data=null,$verb){

print_r($data);

$ch = curl_init($uri);

curl_setopt($ch, CURLOPT_CUSTOMREQUEST,$verb);
curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
curl_setopt($ch, CURLOPT_HTTPHEADER,$header);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$result = curl_exec($ch);
curl_close($ch);
$response=json_decode($result,true) ;
print_r($result);

if($response['status']== 'Created'){
	echo("The Repository  ".json_decode($data)->description . ' was created with the id ' .  $response['id']);
}else{

print_r($result);

}



/*
switch (json_last_error()) {
        case JSON_ERROR_NONE:
            echo '\n - No errors';
        break;
        case JSON_ERROR_DEPTH:
            echo ' - Maximum stack depth exceeded';
        break;
        case JSON_ERROR_STATE_MISMATCH:
            echo ' - Underflow or the modes mismatch';
        break;
        case JSON_ERROR_CTRL_CHAR:
            echo ' - Unexpected control character found';
        break;
        case JSON_ERROR_SYNTAX:
            echo ' - Syntax error, malformed JSON';
        break;
        case JSON_ERROR_UTF8:
            echo ' - Malformed UTF-8 characters, possibly incorrectly encoded';
        break;
        default:
            echo ' - Unknown error';
        break;
    }

    return json_decode($result,true) ;*/
 }
class Aspace_object{

}



class Aspace_repository {
	public  $name = "";
	public  $repo_code = "";
	public  $address_1 = "";
	public  $address_2 = "";
	public  $city = "";
	public  $district = "";
	public  $country = "";
	public  $post_code = "";
	public  $telephone = "";
	public  $telephone_ext = "";
	public  $fax = "";
	public  $email = "";
	public  $url = "";
	public  $email_signature = "";
	
	
 function connect($session,$site,$data){
				var_dump($data);
         $url = $site."/repositories";

        $header=(array('Content-Type: Content-Type: application/json','X-ArchivesSpace-Session:'. $session,'Content-Length: ' . strlen($data)));


         $response= archrequest($url,$header,$data,"POST");
         echo $url."\nhere ******************************\n".$response;
          print_r($response);
         //$responseSess = $response['session'];
         //extract ($responseSess);
    //get the session token
   //return $session;
    }
}
class Aspace_user {

    public  $user = "----";
    public  $username = "----";

    public  $name = "---";
    function connect($session,$site,$data){
        var_dump($data);
        $url = $site."/users";

        $header=(array('Content-Type: Content-Type: application/json','X-ArchivesSpace-Session:'. $session,'Content-Length: ' . strlen($data)));


        $response= archrequest($url,$header,$data,"POST");
        echo $url."\nhere ******************************\n".$response;
        print_r($response);
        //$responseSess = $response['session'];
        //extract ($responseSess);
        //get the session token
        //return $session;
    }






}
?>