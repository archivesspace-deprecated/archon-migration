Archon Migration Project
================

# Archon to ArchivesSpace Migration code


## Tool setup


Download the Archon source code

Download ASpace and run the backend application at http://localhost:8089

Copy three files from this project to the Archon root directory

      cp migrationx.php <ARCHON_ROOT_DIR>/
      cp migration.php <ARCHON_ROOT_DIR>/
      cp migrclass.php <ARCHON_ROOT_DIR>/

From the command line navigate to the Archon web directory and type:

      php –f migrationx.php http://localhost:8089 admin admin

