<?php
/**
 * Index file for all Archon scripts.
 *
 * @package Archon
 * @author Chris Rishel
 */

require_once('includes.inc.php');
include ('migration.php');
/*require_once($_ARCHON->Script);*/
session_start();
global $_ARCHON;
 

isset($_ARCHON) or die();
//Get all Repositories for migration
$arrRepositories = $_ARCHON->getAllRepositories();
$arrUsers = $_ARCHON->getAllUsers();


//print_r($arrRepositories);




$site= $argv[1];
$user= $argv[2];
$password= $argv[3];

echo $argv[1] ."\n";
echo $argv[2] ."\n";
echo $argv[3] ."\n";



$sess=Begin_ArchonMigration($site,$user,$password);

echo"\n\n";

Process_Repository ($arrRepositories,$sess,$site);

Process_Users($arrUsers,$sess,$site);

?>