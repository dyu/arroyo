#!/bin/sh

CURRENT_DIR=$PWD
# locate
if [ -z "$BASH_SOURCE" ]; then
    SCRIPT_DIR=`dirname "$(readlink -f $0)"`
elif [ -e '/bin/zsh' ]; then
    F=`/bin/zsh -c "print -lr -- $BASH_SOURCE(:A)"`
    SCRIPT_DIR=`dirname $F`
elif [ -e '/usr/bin/realpath' ]; then
    F=`/usr/bin/realpath $BASH_SOURCE`
    SCRIPT_DIR=`dirname $F`
else
    F=$BASH_SOURCE
    while [ -h "$F" ]; do F="$(readlink $F)"; done
    SCRIPT_DIR=`dirname $F`
fi
# change pwd
cd $SCRIPT_DIR

mkdir -p target

PG_VERSION='17.0.0'
PG_DIR='target/postgresql'
PG_DATA='target/data/v17'

gen_pg_hba_conf() {
cat << EOF
local   all     postgres                  trust
local   all     arroyo                    trust
host    all     pgz_user_clear            all            password
host    all     pgz_user_nopass           all            trust
host    all     pgz_user_scram_sha256     all            scram-sha-256
host    all     all                       all            scram-sha-256
EOF
}

gen_pg_hba_conf > 'target/pg_hba.conf'

mkdir -p $PG_DATA $PG_DIR
[ -e "$PG_DIR/$PG_VERSION" ] || ln -s /opt/target/pgsql "$PG_DIR/$PG_VERSION"

UNAME=`uname`
[ "$UNAME" = 'Linux' ] && export LD_LIBRARY_PATH='/opt/target/openssl/lib'

POSTGRES_USER='postgres' \
POSTGRES_PASSWORD='root_pw' \
PGPORT='5432' \
PGDATA="$PWD/$PG_DATA" \
PGDIR="$PWD/$PG_DIR" \
PGVERSION=$PG_VERSION \
PGCONF='{ "hba_file": "target/pg_hba.conf", "wal_level": "logical", "timezone": "UTC", "log_timezone": "UTC", "log_statement": "none", "datestyle": "iso", "default_text_search_config": "pg_catalog.english", "shared_preload_libraries": "pg_stat_statements" }' \
nohup epg $@ &

gen_arroyo_sql() {
cat << EOF
CREATE USER arroyo WITH PASSWORD 'arroyo' SUPERUSER;
CREATE DATABASE arroyo;
EOF
}

init_arroyo_pg() {
gen_arroyo_sql | /opt/target/pgsql/bin/psql -U postgres -f - && \
refinery migrate -c refinery.toml -p crates/arroyo-api/migrations && \
touch 'target/arroyo-setup-done'
}

[ ! -e 'target/arroyo-setup-done' ] && sleep 5 && init_arroyo_pg
