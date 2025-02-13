import black
import pathlib


def format_file(file_path: str) -> None:
    path = pathlib.Path(file_path)
    content = path.read_text(encoding="utf-8")

    mode = black.Mode(
        target_versions={black.TargetVersion.PY39},
        line_length=88,
        string_normalization=True,
        is_pyi=False,
    )

    try:
        formatted = black.format_file_contents(
            content.rstrip() + "\n", fast=False, mode=mode
        )
        path.write_text(formatted, encoding="utf-8")
    except Exception as e:
        print(f"Error formatting {file_path}: {e}")


# Format test files
format_file("tests/conftest.py")
format_file("tests/data_generator/test_generate_data.py")
format_file("tests/etl/test_transaction_etl.py")
