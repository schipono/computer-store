#! /usr/bin/env bash

# Check for RDS/PG
until pg_isready -h $POSTGRES_HOST; do
  >&2 echo 'Postgres is unavailable. Rechecking in 1 second.'
  sleep 1
done

# Run migrations
cd /app/backend/
python3 manage.py migrate --no-input

# Start Gunicorn
gunicorn -c python:gunicornconfig shop.wsgi &

# Start Nginx
nginx -g "daemon off;"