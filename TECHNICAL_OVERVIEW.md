Archon2ArchivesSpace TECHNICAL OVERVIEW
================
# Application

The file at app/main.rb invokes a web application built on the Sinatra framework (http://www.sinatrarb.com/).

The application root ('/') responds to HTTP GET requests with a simple form in
which a user enters credentials for an Archon instance and an ArchivesSpace instance
and clicks a button. The resulting POST request initiates an instance of the
MigrationJob class. While the job is running, its output is yielded to the client's
browser as a JSON stream.

# Clients

The application contains a client class for both Archon and ArchivesSpace. Clients
handle the basic HTTP requests that are needed to read data from Archon and post
it to ArchivesSpace.

The ArchivesSpace client relies on some libraries that are extracted from the
ArchivesSpace source code. See the README document for instructions for updating
these files to match the ArchivesSpace release being targeted.

# MigrationJob

This class is the controller for a single migration from point A (Archon) to point B
(ArchivesSpace). It moves through the various Archon record types, reading the
records provided by the Archon client, transforming them, and either sending them
directly to ArchivesSpace or pushing them into a record batch that the ArchivesSpace
client posts in a single request.

# Archon Models

Archon records are represented by model classes defined in app/models. Most model
classes implement a 'transform' method which initializes a new object representing
a corresponding ArchivesSpace data structure. The new object is then fleshed out
with data and yielded (in most cases) to the block passed to the transform method.

Since not all Archon records have a 1 to 1 relationship to the ArchivesSpace data
model, there are several models that yield more than 1 object, or that function
in an idiosyncratic way.

The base class for Archon models is defined in the Archon client library. The base
class contains two types of caches to facilitate the reading of data via the
Archon API. One cache contains raw HTTP response body data from Archon. The other
cache contains instances of the ArchonRecord subclasses. A third, still experimental
cache saves Archon response data to an SQLite database, to facilitate repeated
tests against the same Archon instance.

The Archon API only provides a paginated listing of records, so ArchonRecord.find is
implemented by reading the entire set until the desired records is found. Hence the
necessity for the caching techniques described above.
