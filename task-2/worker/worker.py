import json
import logging
import os
import time
import urllib.parse

import boto3
import psycopg2
from botocore.exceptions import ClientError

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [worker] %(message)s",
)
logger = logging.getLogger(__name__)


def env(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)
    if value is None:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


AWS_ENDPOINT_URL = env("AWS_ENDPOINT_URL", "http://localstack:4566")
AWS_REGION = env("AWS_DEFAULT_REGION", "us-east-1")
QUEUE_NAME = env("QUEUE_NAME", "task2-ingest-queue")

PGHOST = env("PGHOST", "postgres")
PGPORT = int(env("PGPORT", "5432"))
PGDATABASE = env("PGDATABASE", "geodb")
PGUSER = env("PGUSER", "geo")
PGPASSWORD = env("PGPASSWORD", "geo")


def connect_db_with_retry():
    while True:
        try:
            conn = psycopg2.connect(
                host=PGHOST,
                port=PGPORT,
                dbname=PGDATABASE,
                user=PGUSER,
                password=PGPASSWORD,
            )
            conn.autocommit = False
            logger.info("Connected to Postgres at %s:%s", PGHOST, PGPORT)
            return conn
        except Exception as exc:
            logger.warning("Waiting for Postgres: %s", exc)
            time.sleep(3)


def ensure_schema(conn):
    with conn.cursor() as cur:
        cur.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS geo_features (
              id BIGSERIAL PRIMARY KEY,
              source_bucket TEXT NOT NULL,
              source_key TEXT NOT NULL,
              feature_index INTEGER NOT NULL,
              properties JSONB,
              geom geometry(Geometry, 4326) NOT NULL,
              ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
            """
        )
    conn.commit()
    logger.info("PostGIS extension and geo_features table are ready")


def get_sqs_client():
    return boto3.client(
        "sqs",
        endpoint_url=AWS_ENDPOINT_URL,
        region_name=AWS_REGION,
        aws_access_key_id=env("AWS_ACCESS_KEY_ID", "test"),
        aws_secret_access_key=env("AWS_SECRET_ACCESS_KEY", "test"),
    )


def get_s3_client():
    return boto3.client(
        "s3",
        endpoint_url=AWS_ENDPOINT_URL,
        region_name=AWS_REGION,
        aws_access_key_id=env("AWS_ACCESS_KEY_ID", "test"),
        aws_secret_access_key=env("AWS_SECRET_ACCESS_KEY", "test"),
    )


def get_queue_url_with_retry(sqs_client):
    while True:
        try:
            response = sqs_client.get_queue_url(QueueName=QUEUE_NAME)
            queue_url = response["QueueUrl"]
            logger.info("Using queue URL: %s", queue_url)
            return queue_url
        except ClientError as exc:
            logger.warning("Waiting for queue %s: %s", QUEUE_NAME, exc)
            time.sleep(2)


def parse_geojson(text: str):
    payload = json.loads(text)
    if payload.get("type") == "FeatureCollection":
        features = payload.get("features")
        if not isinstance(features, list):
            raise ValueError("FeatureCollection.features must be a list")
        return features
    if payload.get("type") == "Feature":
        return [payload]
    raise ValueError("Supported GeoJSON types are FeatureCollection and Feature")


def ingest_features(conn, bucket: str, key: str, features: list[dict]):
    with conn.cursor() as cur:
        for index, feature in enumerate(features):
            geometry = feature.get("geometry")
            if geometry is None:
                raise ValueError(f"Feature #{index} has no geometry")

            properties = feature.get("properties", {})
            cur.execute(
                """
                INSERT INTO geo_features (source_bucket, source_key, feature_index, properties, geom)
                VALUES (%s, %s, %s, %s::jsonb, ST_SetSRID(ST_GeomFromGeoJSON(%s), 4326));
                """,
                (
                    bucket,
                    key,
                    index,
                    json.dumps(properties),
                    json.dumps(geometry),
                ),
            )
    conn.commit()
    logger.info("Inserted %s features from s3://%s/%s", len(features), bucket, key)


def process_record(conn, s3_client, record: dict):
    s3_info = record.get("s3", {})
    bucket = s3_info.get("bucket", {}).get("name")
    raw_key = s3_info.get("object", {}).get("key")

    if not bucket or not raw_key:
        logger.info("Skipping record without bucket/key")
        return

    key = urllib.parse.unquote_plus(raw_key)
    if not key.lower().endswith(".geojson"):
        logger.info("Skipping non-GeoJSON object: s3://%s/%s", bucket, key)
        return

    logger.info("Downloading s3://%s/%s", bucket, key)
    response = s3_client.get_object(Bucket=bucket, Key=key)
    data = response["Body"].read().decode("utf-8")

    logger.info("Validating GeoJSON for s3://%s/%s", bucket, key)
    features = parse_geojson(data)

    ingest_features(conn, bucket, key, features)


def process_message(conn, s3_client, body_text: str):
    body = json.loads(body_text)
    records = body.get("Records")

    if not records:
        event_name = body.get("Event")
        logger.info("Skipping non-record message type: %s", event_name)
        return

    for record in records:
        event_name = record.get("eventName", "")
        if not event_name.startswith("ObjectCreated"):
            logger.info("Skipping unsupported event: %s", event_name)
            continue
        process_record(conn, s3_client, record)


def main():
    conn = connect_db_with_retry()
    ensure_schema(conn)

    sqs_client = get_sqs_client()
    s3_client = get_s3_client()
    queue_url = get_queue_url_with_retry(sqs_client)

    logger.info("Worker started. Polling SQS for GeoJSON ingest events.")

    while True:
        try:
            response = sqs_client.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=5,
                WaitTimeSeconds=10,
                VisibilityTimeout=30,
            )

            messages = response.get("Messages", [])
            if not messages:
                continue

            for message in messages:
                receipt_handle = message["ReceiptHandle"]
                body_text = message["Body"]
                logger.info("Received SQS message id=%s", message.get("MessageId"))

                try:
                    process_message(conn, s3_client, body_text)
                except Exception as exc:
                    conn.rollback()
                    logger.exception("Failed processing message, leaving it in queue: %s", exc)
                    continue

                sqs_client.delete_message(QueueUrl=queue_url, ReceiptHandle=receipt_handle)
                logger.info("Deleted SQS message id=%s", message.get("MessageId"))

        except Exception as exc:
            logger.exception("Worker loop error: %s", exc)
            time.sleep(3)


if __name__ == "__main__":
    main()