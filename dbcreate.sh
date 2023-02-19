#!/bin/sh
# Creating Test DB

set -x

PGPORT=5432
PGHOST="localhost"
PGUSER="testuser"
PGDBASE="testdb"
PGSECRET="testsecret"

su - postgres -c "createuser $PGUSER"
su - postgres -c "createdb  -E utf8 $PGDBASE"
su - postgres -c "psql -c \"alter user $PGUSER with encrypted password '$PGSECRET';\""
su - postgres -c "psql -c \"grant all privileges on database $PGDBASE to $PGUSER;\""

# SQL
su - postgres -c "psql -U $PGUSER -d $PGDBASE -c 'CREATE TABLE message (created TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,id VARCHAR NOT NULL,int_id CHAR(16) NOT NULL,str VARCHAR NOT NULL,status BOOL,CONSTRAINT message_id_pk PRIMARY KEY(id));'"
su - postgres -c "psql -U $PGUSER -d $PGDBASE -c 'CREATE INDEX message_created_idx ON message (created);'"
su - postgres -c "psql -U $PGUSER -d $PGDBASE -c 'CREATE INDEX message_int_id_idx ON message (int_id);'"
su - postgres -c "psql -U $PGUSER -d $PGDBASE -c 'CREATE TABLE log (created TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,int_id CHAR(16) NOT NULL,str VARCHAR,address VARCHAR);'"
su - postgres -c "psql -U $PGUSER -d $PGDBASE -c 'CREATE INDEX log_address_idx ON log USING hash (address);'"



