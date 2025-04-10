#!/bin/sh

POSTGRES_URL='postgresql://arroyo:arroyo@localhost:5432/arroyo'

if [ "$#" -eq 0 ]; then
/opt/target/pgsql/bin/psql "$POSTGRES_URL"
else
/opt/target/pgsql/bin/psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 $@
fi
