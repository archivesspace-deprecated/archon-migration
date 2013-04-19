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
include ('class-datahandler.php');
include ('json-model.php');
function get_session($site){
    $response = rest_helper($site.'/users/admin/login', array('password'=>'admin'),'POST');
     //print_r($response);
    return $response->session;
}


function rest_helper($url, $params = null, $verb = 'GET', $format = 'json', $session = null, $json = null)
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

    // if ($params['data']) {
    //     $cparams['http']['content'] = $params['data'];
    // }


    if ($params !== null) {
        $params = http_build_query($params);
        print_r("POST PARAMS");
        print_r($params);
        if ($verb == 'POST') {
            if ($json) {
                $cparams['http']['content'] = $json;
                $url .= '?' . $params;
            } else {
                $cparams['http']['content'] = $params;
            }
        } else {
            $url .= '?' . $params;
        }
    }

    $context = stream_context_create($cparams);
    print_r($cparams);
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
class Aspace_group{
    public $uri="";
    public $group_code="";
    public $description="";
    public $member_usernames= Array('');
    public $grants_permissions=Array('');

}



class Aspace_repository extends JSONRecord {
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
	
	
 /*function connect($session,$site,$data){
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
    }*/
}
class Aspace_user {

    public  $user = "----";
    public  $username = "----";

    public  $name = "---";
  /*  function connect($session,$site,$data){
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
    }*/






}
?>