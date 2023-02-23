FROM python:3.11

WORKDIR /app

COPY backend /app/backend

# Install PG client tools, for pg_isready & nginx
RUN apt-get -y update \
    && apt-get -y install postgresql-client nginx

# Copy nginx config
COPY infra/nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Install Dependencies
# psycopg2 is installed separately on it's own as it needs to be built from scratch rather
# than the binary we're installing for easier local development
WORKDIR /app/backend
RUN pip3 install --upgrade pip \
    && pip3 install pipenv \
    && pipenv install --system --deploy \
    && pip3 install psycopg2

# Collect staticfiles for Whitenoise & Django
RUN python3 ./manage.py collectstatic --no-input

ENTRYPOINT ["sh", "/app/backend/start_server.sh"]