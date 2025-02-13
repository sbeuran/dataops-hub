from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, current_timestamp
import boto3
import json


def get_db_credentials():
    """Get database credentials from AWS Secrets Manager."""
    session = boto3.session.Session()
    client = session.client("secretsmanager")

    secret = client.get_secret_value(SecretId="dataops-hub/rds-credentials")
    return json.loads(secret["SecretString"])


def create_spark_session():
    """Create and configure Spark session."""
    return (
        SparkSession.builder.appName("TransactionETL")
        .config("spark.jars.packages", "org.postgresql:postgresql:42.2.18")
        .getOrCreate()
    )


def read_from_postgres(spark, credentials):
    """Read data from PostgreSQL."""
    jdbc_url = f"jdbc:postgresql://{credentials['host']}:{credentials['port']}/{credentials['dbname']}"

    # Read transactions
    transactions_df = (
        spark.read.format("jdbc")
        .option("url", jdbc_url)
        .option("dbtable", "transactions")
        .option("user", credentials["username"])
        .option("password", credentials["password"])
        .option("driver", "org.postgresql.Driver")
        .load()
    )

    # Read customers
    customers_df = (
        spark.read.format("jdbc")
        .option("url", jdbc_url)
        .option("dbtable", "customers")
        .option("user", credentials["username"])
        .option("password", credentials["password"])
        .option("driver", "org.postgresql.Driver")
        .load()
    )

    return transactions_df, customers_df


def transform_data(transactions_df, customers_df):
    """Transform the data."""
    # Join transactions with customer data
    enriched_transactions = transactions_df.join(customers_df, "account_id").select(
        "account_id",
        "transaction_date",
        "transaction_amount",
        "transaction_currency",
        "transaction_type",
        "account_type",
        "account_status",
        "account_balance",
        "is_fraud",
        "is_suspicious",
        "account_owner_country",
        col("transaction_amount").cast("double").alias("amount"),
    )

    # Add risk score
    risk_scored = enriched_transactions.withColumn(
        "risk_score",
        when(col("is_fraud"), 1.0).when(col("is_suspicious"), 0.7).otherwise(0.0),
    )

    # Add processing timestamp
    final_df = risk_scored.withColumn("processed_at", current_timestamp())

    return final_df


def write_to_s3(df, bucket_name, path):
    """Write DataFrame to S3 in Parquet format."""
    df.write.mode("overwrite").partitionBy("transaction_date").parquet(
        f"s3://{bucket_name}/{path}"
    )


def main():
    """Main ETL job."""
    # Get credentials
    credentials = get_db_credentials()

    # Create Spark session
    spark = create_spark_session()

    try:
        # Extract
        print("Extracting data from PostgreSQL...")
        transactions_df, customers_df = read_from_postgres(spark, credentials)

        # Transform
        print("Transforming data...")
        transformed_df = transform_data(transactions_df, customers_df)

        # Load
        print("Loading data to S3...")
        write_to_s3(transformed_df, "dataops-hub-data", "processed/transactions")

        print("ETL job completed successfully!")

    finally:
        spark.stop()


if __name__ == "__main__":
    main()
