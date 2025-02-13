import json
import random
from datetime import datetime, timedelta
from typing import Dict, List

import boto3
import faker
import pandas as pd
from sqlalchemy import create_engine

# Initialize Faker for different locales
fake_generators = {
    "Germany": faker.Faker("de_DE"),
    "France": faker.Faker("fr_FR"),
    "Italy": faker.Faker("it_IT"),
    "Spain": faker.Faker("es_ES"),
    "Portugal": faker.Faker("pt_PT"),
}

# Configuration
COUNTRIES = ["Germany", "France", "Italy", "Spain", "Portugal"]
CUSTOMERS_PER_COUNTRY = 2
TRANSACTIONS_PER_CUSTOMER = 10


def get_db_connection():
    """Get database connection details from AWS Secrets Manager."""
    session = boto3.session.Session()
    client = session.client("secretsmanager")

    secret = client.get_secret_value(SecretId="dataops-hub/rds-credentials")
    credentials = json.loads(secret["SecretString"])

    return create_engine(
        f"postgresql://{credentials['username']}:{credentials['password']}@"
        f"{credentials['host']}:{credentials['port']}/{credentials['dbname']}"
    )


def generate_iban(country: str, account_number: str) -> str:
    """Generate IBAN for a specific country."""
    country_codes = {
        "Germany": "DE",
        "France": "FR",
        "Italy": "IT",
        "Spain": "ES",
        "Portugal": "PT",
    }
    return f"{country_codes[country]}89{account_number.zfill(20)}"


def generate_customer(country: str, customer_id: int) -> Dict:
    """Generate fake customer data for a specific country."""
    fake = fake_generators[country]
    account_number = str(random.randint(1000000000, 9999999999))

    return {
        "account_id": f"{country[:2].upper()}{customer_id}",
        "IBAN": generate_iban(country, account_number),
        "BIC": f"BANK{fake.random_number(digits=5, fix_len=True)}XXX",
        "SWIFT": f"SWIFT{fake.random_number(digits=5, fix_len=True)}",
        "account_number": account_number,
        "account_type": random.choice(["Checking", "Savings", "Investment"]),
        "account_status": random.choice(["Active", "Dormant", "Suspended"]),
        "account_balance": round(random.uniform(1000, 1000000), 2),
        "is_fraud": random.random() < 0.05,
        "is_suspicious": random.random() < 0.1,
        "is_blocked": random.random() < 0.03,
        "is_active": random.random() < 0.95,
        "is_deleted": random.random() < 0.01,
        "account_owner": fake.name(),
        "account_owner_email": fake.email(),
        "account_owner_phone": fake.phone_number(),
        "account_owner_address": fake.street_address(),
        "account_owner_city": fake.city(),
        "account_owner_state": fake.state(),
        "account_owner_zip": fake.postcode(),
    }


def generate_transaction(customer: Dict) -> Dict:
    """Generate a fake transaction for a customer."""
    fake = fake_generators[customer["account_id"][:2]]
    transaction_date = datetime.now() - timedelta(days=random.randint(0, 365))

    return {
        "account_id": customer["account_id"],
        "transaction_date": transaction_date,
        "transaction_amount": round(random.uniform(10, 5000), 2),
        "transaction_currency": "EUR",
        "transaction_description": fake.text(max_nb_chars=100),
        "transaction_type": random.choice(
            ["deposit", "withdrawal", "transfer", "payment"]
        ),
        "is_fraud": random.random() < 0.02,
        "is_suspicious": random.random() < 0.05,
    }


def main():
    """Main function to generate and store customer and transaction data."""
    customers = []
    transactions = []

    # Generate customer data
    for country in COUNTRIES:
        for i in range(CUSTOMERS_PER_COUNTRY):
            customer = generate_customer(country, i + 1)
            customers.append(customer)

            # Generate transactions for this customer
            for _ in range(TRANSACTIONS_PER_CUSTOMER):
                transaction = generate_transaction(customer)
                transactions.append(transaction)

    # Convert to DataFrames
    customers_df = pd.DataFrame(customers)
    transactions_df = pd.DataFrame(transactions)

    # Store in database
    engine = get_db_connection()

    customers_df.to_sql("customers", engine, if_exists="replace", index=False)
    transactions_df.to_sql("transactions", engine, if_exists="replace", index=False)

    print(f"Generated {len(customers)} customers and {len(transactions)} transactions")


if __name__ == "__main__":
    main()
