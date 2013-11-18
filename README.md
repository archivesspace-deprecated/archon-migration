Archon2ArchivesSpace README
================
# System Requirements

You will need to have Ruby 1.9.3 installed to run this service

	ruby --version
    # example output: ruby 1.9.3p429 (2013-05-15 revision 40747)

If your system has a different version of Ruby installed, the simplest way to
leave your system intact and get 1.9.3 is to install RVM (https://rvm.io/).

# Installing the service

Download a release or just checkout the project from Github:

    git clone https://github.com/lcdhoffman/archon-migration.git
    cd archon-migration

Run a script to download the necessary ArchivesSpace libraries:

	./scripts/import\_client\_libs.sh v1.0.0RC1

This will attempt to download the ArchivesSpace source code for ArchivesSpace v1.0.0RC1.
*Note: the service ships with libraries for ArchivesSpace 1.0.0, so you can skip this step
if you are targeting 1.0.0.

Install the application dependencies listed in the Gemfile:

    gem install bundler
    bundle install

Now run the application:

    ruby app/main.rb

The service runs on port 4568 by default. To change this:

	touch config/config_local.rb
    echo "Appdata.port_number YOUR_FAVORITE_PORT_HERE" >> config/config_local.rb

# Daemonizing the Service

The service can be daemonized in several ways. One option is to install a native
ruby solution such as the Daemonize gem (http://daemons.rubyforge.org/). However,
since the service is intended to be short-lived, it may be easiest to simply
send the process to the background and disown it.

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

To change, for example, the version of the ArchivesSpace target, add the following
line

	Appdata.aspace_version 'v1.0.1'

If Archon response times become slow due to network latency or large datasets, it is
possible to speed up successive tests by turning on database caching. Note that you must manually delete
the database if you point the migration tool at a new Archon instance.

	Appdata.use_dbcache  true

*Note: this feature is not complete and should be left off by default.

# Notes

A typical migration can take several hours and could cause ArchivesSpace's 
indexer to get backed up. Migrated records may not appear right away in browse or search results in ArchivesSpace. Consider running ArchivesSpace with the indexer
turned off to speed up the migration process, or upgrading to a later version of ArchivesSpace.

Do not run a migration process against an ArchivesSpace instance that already
contains data.

Do not allow Archon users to create or edit data while the migration is running.

Do not allow ArchivesSpace users to create or edit data while the migration is
running.

You can optimize the performance of the migration tool by adjusting the number of
pages of Archon data that are cached. For example, if your largest Archon collection contains 50,000 Content records, and you are running the migration tool in an environment that can afford around 300MB of memory, you might want to add this line to your config_local.rb file:

    Appdata.archon_page_cache_size 500

There's no (or little) advantage to setting the page cache size to a value larger than the number of Content records in the largest Collection, divided by 100. There is a significant disadvantage to keeping your page cache size smaller than the number of pages of items in your largest collection.
