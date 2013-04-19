<?php
class JSONRecord {

  // Add $num articles of $artnr to the cart
  function save($opts = null) {
    
    $data = json_encode(get_object_vars($this));


    $aspace_backend = $GLOBALS['aspace_backend'];
    $aspace_session = $GLOBALS['aspace_session'];

    # Add Error handling here
    # Could add the rest_helper method to this class as a class method
    $qreponse = rest_helper($aspace_backend."/repositories", '', 'POST', 'json', $aspace_session, $data);
    


    if (isset($qreponse->id)) {
      return $qresponse->id;
    } else {
      return NULL;
    }
  }
}

?>