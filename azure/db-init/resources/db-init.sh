#!/bin/sh
# Azure does not support automatically user creation - this script will be run as a step to prepare the databases
# and create users and set their generated passwords.

set -ex

apk add postgresql14-client

OASIS_DB_USERNAME_WITHOUT_SERVER_NAME="$(echo $OASIS_DB_USERNAME | sed 's/@.*//')"
KEYCLOAK_DB_USERNAME_WITHOUT_SERVER_NAME="$(echo $KEYCLOAK_DB_USERNAME | sed 's/@.*//')"
CELERY_DB_USERNAME_WITHOUT_SERVER_NAME="$(echo $CELERY_DB_USERNAME | sed 's/@.*//')"

echo "Oasis user: $OASIS_DB_USERNAME_WITHOUT_SERVER_NAME"
echo "Keycloak user: $KEYCLOAK_DB_USERNAME_WITHOUT_SERVER_NAME"
echo "Celery user: $CELERY_DB_USERNAME_WITHOUT_SERVER_NAME"

psql "sslmode=require host=${OASIS_DB_SERVER_HOST} user=${OASIS_DB_SERVER_ADMIN_USERNAME} password=${OASIS_DB_SERVER_ADMIN_PASSWORD} dbname=postgres" << EOF

DO \$\$
BEGIN
  IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles  -- SELECT list can be empty for this
      WHERE rolname = '${OASIS_DB_USERNAME_WITHOUT_SERVER_NAME}') THEN

      CREATE ROLE ${OASIS_DB_USERNAME_WITHOUT_SERVER_NAME} LOGIN PASSWORD '${OASIS_DB_PASSWORD}';
      GRANT ALL PRIVILEGES ON DATABASE oasis TO ${OASIS_DB_USERNAME_WITHOUT_SERVER_NAME};
  ELSE
    ALTER USER ${OASIS_DB_USERNAME_WITHOUT_SERVER_NAME} WITH PASSWORD '${OASIS_DB_PASSWORD}';
  END IF;

  IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles  -- SELECT list can be empty for this
      WHERE rolname = '${KEYCLOAK_DB_USERNAME_WITHOUT_SERVER_NAME}') THEN

      CREATE ROLE ${KEYCLOAK_DB_USERNAME_WITHOUT_SERVER_NAME} LOGIN PASSWORD '${KEYCLOAK_DB_PASSWORD}';
      GRANT ALL PRIVILEGES ON DATABASE oasis TO ${KEYCLOAK_DB_USERNAME_WITHOUT_SERVER_NAME};
  ELSE
    ALTER USER ${KEYCLOAK_DB_USERNAME_WITHOUT_SERVER_NAME} WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}';
  END IF;

  IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles  -- SELECT list can be empty for this
      WHERE rolname = '${CELERY_DB_USERNAME_WITHOUT_SERVER_NAME}') THEN

      CREATE ROLE ${CELERY_DB_USERNAME_WITHOUT_SERVER_NAME} LOGIN PASSWORD '${CELERY_DB_PASSWORD}';
      GRANT ALL PRIVILEGES ON DATABASE oasis TO ${CELERY_DB_USERNAME_WITHOUT_SERVER_NAME};
  ELSE
    ALTER USER ${CELERY_DB_USERNAME_WITHOUT_SERVER_NAME} WITH PASSWORD '${CELERY_DB_PASSWORD}';
  END IF;
END \$\$
EOF

echo "Users:"

psql "sslmode=require host=${OASIS_DB_SERVER_HOST} user=${OASIS_DB_SERVER_ADMIN_USERNAME} password=${OASIS_DB_SERVER_ADMIN_PASSWORD} dbname=postgres" << EOF
\du
EOF

echo "Done"

