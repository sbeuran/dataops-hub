import black
import pathlib


def format_file(file_path: str) -> None:
    path = pathlib.Path(file_path)
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    mode = black.Mode(
        target_versions={black.TargetVersion.PY39},
        line_length=88,
        string_normalization=True,
        is_pyi=False,
    )

    formatted = black.format_file_contents(content, fast=False, mode=mode)

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(formatted)


# Format both files
format_file("src/etl/transaction_etl.py")
format_file("src/data_generator/generate_data.py")
