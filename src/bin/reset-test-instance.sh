#!/usr/bin/env bash
set -euo pipefail

CONTENT_DB_VERSION="0.2.8"
CONTENT_BASE="gs://planet4-default-content/"
CONTENT_DB="planet4-defaultcontent_wordpress-v${CONTENT_DB_VERSION}.sql.gz"
LOCAL_DB="defaultcontent.sql.gz"

GCLOUD_ZONE="us-central1-a"
GCLOUD_CLUSTER="p4-development"
GOOGLE_PROJECT_ID="planet-4-151612"

WP_DB_USERNAME_DC=$(echo "${WP_DB_USERNAME}" | base64 -d)
WP_DB_PASSWORD_DC=$(echo "${WP_DB_PASSWORD}" | base64 -d)
WP_DB_TO_IMPORT_TO=$(yq -r .job_environments.develop_environment.WP_DB_NAME /tmp/workspace/src/.circleci/config.yml)
CLOUDSQL_INSTANCE="planet-4-151612:us-central1:p4-develop-k8s"

echo ""
echo "Get active instance"
INSTANCE=${CONTAINER_PREFIX/planet4-/}
echo "Instance: ${INSTANCE}"
echo ""

echo ""
echo "Connect to dev cloud"
gcloud container clusters get-credentials "${GCLOUD_CLUSTER}" --zone "${GCLOUD_ZONE}" --project "${GOOGLE_PROJECT_ID}"
echo ""

echo ""
echo "Download DB dump"
gsutil cp "${CONTENT_BASE}${CONTENT_DB}" "${LOCAL_DB}"
echo ""

echo ""
echo "Configure CloudSQL"
trap finish EXIT
cloud_sql_proxy -instances="${CLOUDSQL_INSTANCE}=tcp:3306" &
echo ""

echo ""
echo "Set kubectl command to use the namespace"
kc="kubectl -n ${INSTANCE}"
echo ""

echo ""
echo "Find first php pod in ${INSTANCE}"
POD=$($kc get pods -l component=php | grep php | head -n1 | cut -d' ' -f1)
echo ""

echo ""
echo "Get instance speficic options"
GA_CLIENT_ID=$(kubectl -n test-deimos exec planet4-test-deimos-wordpress-php-6fc6858fd4-pfvsh -- wp option pluck galogin ga_clientid)
GA_CLIENT_SECRET=$(kubectl -n test-deimos exec planet4-test-deimos-wordpress-php-6fc6858fd4-pfvsh -- wp option pluck galogin ga_clientsecret)
echo ""

echo ""
echo "Sync Stateless bucket"
gsutil rsync -d -r gs://planet4-defaultcontent-stateless-develop gs://"${WP_STATELESS_BUCKET}"
echo ""

echo ""
echo "Importing the DB file"
mysql -u "${WP_DB_USERNAME_DC}" -p "${WP_DB_PASSWORD_DC}" -h 127.0.0.1 "${WP_DB_TO_IMPORT_TO}" <"${LOCAL_DB}"
echo ""

echo ""
echo "Restore instance specific options"
$kc exec "${POD}" -- wp option patch update galogin ga_clientid "${GA_CLIENT_ID}"
$kc exec "${POD}" -- wp option patch update galogin ga_clientsecret "${GA_CLIENT_SECRET}"
echo ""

echo ""
echo "Restore paths"
OLD_PATH="www-dev.greenpeace.org/defaultcontent"
NEW_PATH="www-dev.greenpeace.org/${INSTANCE}"
$kc exec "$POD" -- wp search-replace "$OLD_PATH" "$NEW_PATH" --precise --skip-columns=guid
OLD_PATH="https://www.greenpeace.org/static/defaultcontent-stateless-develop/"
NEW_PATH="https://www.greenpeace.org/static/${CONTAINER_PREFIX}-stateless-develop/"
$kc exec "$POD" -- wp search-replace "$OLD_PATH" "$NEW_PATH" --precise --skip-columns=guid
echo ""

echo ""
echo "Flushing cache"
$kc exec "${POD}" -- wp cache flush
echo ""
