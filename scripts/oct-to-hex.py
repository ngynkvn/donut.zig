import sys
import re


def octal_to_hex(match):
    octal = match.group(1)
    return f"\\x{int(octal, 8):02x}"


def convert_octal_to_hex(input_string):
    # Pattern to match octal escape sequences
    pattern = r"\\([0-3][0-7]{2}|[0-7]{1,2})"
    # Replace octal escapes with hex escapes
    return re.sub(pattern, octal_to_hex, input_string)


for line in sys.stdin:
    print(convert_octal_to_hex(line), end="")
