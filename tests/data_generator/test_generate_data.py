from src.data_generator.generate_data import (
    generate_customer,
    generate_iban,
    generate_transaction,
)


def test_generate_iban():
    """Test IBAN generation."""
    account_number = "1234567890"
    iban = generate_iban("Germany", account_number)
    assert iban.startswith("DE89")
    assert len(iban) == 24  # Standard IBAN length


def test_generate_customer():
    """Test customer data generation."""
    customer = generate_customer("Germany", 1)
    assert customer["account_id"].startswith("GE")
    assert isinstance(customer["account_balance"], float)
    assert customer["account_type"] in ["Checking", "Savings", "Investment"]
    assert customer["account_status"] in ["Active", "Dormant", "Suspended"]


def test_generate_transaction():
    """Test transaction data generation."""
    customer = {"account_id": "GE1"}
    transaction = generate_transaction(customer)
    assert transaction["account_id"] == "GE1"
    assert isinstance(transaction["transaction_amount"], float)
    assert transaction["transaction_currency"] == "EUR"
    assert transaction["transaction_type"] in ["deposit", "withdrawal", "transfer", "payment"] 