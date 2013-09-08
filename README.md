Archon2ArchivesSpace README
================
# Installing the service

Checkout the project from Github:

    git clone https://github.com/lcdhoffman/archon-migration.git
    cd archon-migration

Run a script to download the necessary ArchivesSpace libraries:

./scripts/import\_client\_libs.sh v1.0.0RC1

This will attempt to download the ArchivesSpace source code for ArchivesSpace v1.0.0RC1.

Install the gems in the Gemfile:

    gem install bundler
    bundle install

Now run the application:

    ruby app/main.rb

(You'll probably want to daemonize or disown this.)

# Using the Service

The service is designed to be used in a browser window. Make sure you have a 
running Archon instance and a running ArchiveSpace instance. You will also need 
account credentials for each service. It is recommended that you create a 
separate account called 'migration_user' and assign this user the required 
permissions in each application.

Point your browser to, e.g.,  http://localhost:4568 and fill out the web form. 

# Configuration Options

The best way to configure the application is to create a local config file:

    touch config/config_local.rb

To change, for example, the port that application runs on, add the following
line

    Appdata.port_number 4568
    
# Notes

A typical migration can take several hours and will cause ArchivesSpace's 
indexer to get backed up. Migrated records may not appear right away in browse or search results in ArchivesSpace. Consider running ArchivesSpace with the indexer
turned off to speed up the migration process.

Do not run a migration process against an ArchivesSpace instance that already
contains data.

Do not allow Archon users to create or edit data while the migration is running.




