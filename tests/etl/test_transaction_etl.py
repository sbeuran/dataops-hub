import pytest
from pyspark.sql import SparkSession
from pyspark.sql.types import DoubleType, StringType, StructField, StructType, TimestampType

from src.etl.transaction_etl import transform_data


@pytest.fixture
def spark():
    """Create a Spark session for testing."""
    return (
        SparkSession.builder.appName("TestTransactionETL")
        .master("local[1]")
        .getOrCreate()
    )


def test_transform_data(spark):
    """Test data transformation logic."""
    # Create test schemas
    transaction_schema = StructType(
        [
            StructField("account_id", StringType(), False),
            StructField("transaction_amount", DoubleType(), False),
            StructField("transaction_date", TimestampType(), False),
            StructField("transaction_currency", StringType(), False),
            StructField("transaction_type", StringType(), False),
            StructField("is_fraud", StringType(), False),
            StructField("is_suspicious", StringType(), False),
        ]
    )

    customer_schema = StructType(
        [
            StructField("account_id", StringType(), False),
            StructField("account_type", StringType(), False),
            StructField("account_status", StringType(), False),
            StructField("account_balance", DoubleType(), False),
            StructField("account_owner_country", StringType(), False),
        ]
    )

    # Create test data
    transaction_data = [
        (
            "GE1",
            100.0,
            "2024-02-13 10:00:00",
            "EUR",
            "deposit",
            "false",
            "false",
        )
    ]

    customer_data = [
        ("GE1", "Checking", "Active", 1000.0, "Germany")
    ]

    # Create DataFrames
    transactions_df = spark.createDataFrame(transaction_data, transaction_schema)
    customers_df = spark.createDataFrame(customer_data, customer_schema)

    # Transform data
    result_df = transform_data(transactions_df, customers_df)

    # Verify results
    assert result_df.count() == 1
    row = result_df.collect()[0]
    assert row.account_id == "GE1"
    assert row.transaction_amount == 100.0
    assert row.account_type == "Checking"
    assert row.risk_score == 0.0  # Not fraud or suspicious 