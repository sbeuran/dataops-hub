from datetime import datetime
from unittest.mock import Mock, patch

import pytest

from src.etl.transaction_etl import transform_data


@pytest.fixture
def mock_dataframes():
    """Create mock DataFrames for testing."""
    # Mock transaction DataFrame
    transactions_df = Mock()
    transactions_df.join = Mock(return_value=transactions_df)
    transactions_df.select = Mock(return_value=transactions_df)
    transactions_df.withColumn = Mock(return_value=transactions_df)

    # Create a mock row that will be returned by collect()
    mock_row = Mock()
    mock_row.account_id = "GE1"
    mock_row.transaction_amount = 100.0
    mock_row.account_type = "Checking"
    mock_row.is_fraud = "false"
    mock_row.is_suspicious = "false"
    mock_row.risk_score = 0.0

    transactions_df.collect = Mock(return_value=[mock_row])
    transactions_df.count = Mock(return_value=1)

    # Mock customer DataFrame
    customers_df = Mock()

    return transactions_df, customers_df


@patch("src.etl.transaction_etl.col")
@patch("src.etl.transaction_etl.when")
@patch("src.etl.transaction_etl.current_timestamp")
def test_transform_data(mock_current_timestamp, mock_when, mock_col, mock_dataframes):
    """Test data transformation logic."""
    # Setup mocks
    transactions_df, customers_df = mock_dataframes
    mock_when.return_value.when.return_value.otherwise.return_value = (
        "mocked_risk_score"
    )
    mock_current_timestamp.return_value = datetime(2024, 2, 13, 10, 0, 0)

    # Transform data
    result_df = transform_data(transactions_df, customers_df)

    # Verify the transformation results
    assert result_df.count() == 1
    row = result_df.collect()[0]
    assert row.account_id == "GE1"
    assert row.transaction_amount == 100.0
    assert row.account_type == "Checking"
    assert row.risk_score == 0.0

    # Verify DataFrame operations were called correctly
    transactions_df.join.assert_called_once_with(customers_df, "account_id")
    assert transactions_df.select.call_count == 1
    assert (
        transactions_df.withColumn.call_count >= 2
    )  # One for risk_score, one for processed_at
