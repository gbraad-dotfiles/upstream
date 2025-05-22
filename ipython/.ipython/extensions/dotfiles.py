from IPython.core.magic import register_line_cell_magic, register_line_magic

def load_ipython_extension(ipython):
    print("dotfiles extension loaded!")

    @register_line_cell_magic
    def dotfiles(line, cell=None):
        command = line
        if cell:
            command += '\n' + cell
        get_ipython().system(f"zsh -i -c 'if ! typeset -f dotfiles >/dev/null; then source ~/.dotfiles/source.sh; fi; {command}'")


import subprocess
import re

@register_line_magic
def dot(line):
    command = f". ~/.dotfiles/source.sh; {line}"
    result = subprocess.run(
        ['zsh', '-c', command],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"Command failed: {result.stderr}")
    # Remove ANSI escape sequences
    ansi_escape = re.compile(r'\x1B\[[0-?]*[ -/]*[@-~]')
    clean_output = ansi_escape.sub('', result.stdout).strip()
    # Remove surrounding quotes, if present
    if clean_output.startswith('"') and clean_output.endswith('"'):
        clean_output = clean_output[1:-1]
    return clean_output


import configparser
from pathlib import Path

@register_line_magic
def dotini(line):
    """
    Usage: %dotini filename [mode]
    - filename: the ini file to load from ~/.config/dotfiles/
    - mode (optional): 'display', 'return', or 'both' (default: 'return')
    """
    parts = line.strip().split()
    if not parts:
        print("Usage: %dotini filename [mode]")
        return None

    ini_name = parts[0]
    mode = parts[1] if len(parts) > 1 else "return"

    ini_path = Path.home() / '.config' / 'dotfiles' / ini_name
    if not ini_path.is_file():
        print(f"File '{ini_path}' not found.")
        return None

    config = configparser.ConfigParser()
    config.read(str(ini_path))

    # Collect data
    data = []
    for section in config.sections():
        for key, value in config.items(section):
            data.append((section, key, value))

    if not data:
        print("The INI file is empty or has no sections/keys.")
        return None

    # Determine column widths for pretty-printing
    col_names = ['Section', 'Key', 'Value']
    widths = [len(name) for name in col_names]
    for row in data:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(str(cell)))

    # Prepare formatted table as a string
    fmt_row = " | ".join("{:<" + str(w) + "}" for w in widths)
    lines = [
        fmt_row.format(*col_names),
        "-+-".join('-' * w for w in widths)
    ]
    for row in data:
        lines.append(fmt_row.format(*row))
    table_str = "\n".join(lines)

    if mode == "display":
        print(table_str)
        return None
    elif mode == "both":
        print(table_str)
        return data
    else:  # default: return
        return data
