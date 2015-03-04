Archon2ArchivesSpace README
================
# System Requirements

You will need to have java installed to run this service. Example:

    java -version
    -> Java(TM) SE Runtime Environment (build 1.7.0_17-b02)
    -> Java HotSpot(TM) 64-Bit Server VM (build 23.7-b01, mixed mode)

# Running the service

Download the .war file from the Releases page: https://github.com/lcdhoffman/archon-migration/releases

To run the service:

    java -jar archon-migration.war [--httpPort=XXXX]

If you are running the service on a Windows server use the -Dfile flag to ensure proper migration of quotations:

    java -Dfile.encoding=UTF-8 -jar archon-migration.war [--httpPort=XXXX]

This will start the application within an embedded webserver. The default port of the webserver is 8080.

# Building the distribution

You can build a distribution by cloning the source code:

    git clone https://github.com/archivesspace/archon-migration.git
    cd archon-migration

and using warbler to build a web application archive:

    gem install warbler
    warble executable war

Now visit your application at http://localhost:8080

For running the application without building a JRuby release
	cd archon-migration
	rackup -p 8080
