#!/bin/bash
dump=$1

[ -f "$dump" ] && rails db:reset &&  sed '/DROP DATABASE \|CREATE DATABASE \|USE /d' "$dump" | sed 's/ datetime / datetime(6) /' | rails db -p

rails db:migrate
