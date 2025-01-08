#!/bin/bash
dump=$1

[ -f "$dump" ] && rails db:drop && rails db:create && zcat -f "$dump" | sed '/DROP DATABASE \|CREATE DATABASE \|USE `/d'  | sed 's/ datetime / datetime(6) /'  > import.sql 

cat import.sql | rails db -p

rails db:migrate

rake admin:reindex_all
