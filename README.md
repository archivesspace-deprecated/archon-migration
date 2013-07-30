Archon2ArchiveSpace README
================
# Status

This software and this README are in a development state. Satisfactory results are not necessarily to be expected.

# Installing the service

Checkout the project from Github:
  
	  https://github.com/lcdhoffman/archon-migration.git
  	cd archon-migration

Download the necessary ArchivesSpace libraries:

		./scripts/import_client_libs.sh v0.6.2

This will attempt to download the ArhivesSpace source code for ArchivesSpace 0.6.2.

Install the gems in the Gemfile::

		bundle install

Now run the application:

		ruby app/main.rb


# Using the Service

Make sure you have a running Archon instance and a running ArchiveSpace instane. 
You will also need account credentials for each service. It is recommended that 
you created a separate account called 'migration_user' and assign this user the 
required permissions in each application.

Point your browser to http://localhost:4568 and fill out the form.