from IPython.core.magic import register_line_cell_magic, register_line_magic

def in_jupyter():
    try:
        from IPython import get_ipython
        shell = get_ipython().__class__.__name__
        return shell == 'ZMQInteractiveShell'  # True in Jupyter
    except:
        return False

def load_ipython_extension(ipython):
    pass

def make_tool_magic(tool):
    @register_line_magic(tool)
    def magic(line, cell=None):
        command = f"zsh -i -c 'if ! typeset -f {tool} >/dev/null; then source ~/.dotfiles/source.sh; fi; {tool} {line}'"
        get_ipython().system(command)

for tool in ["dotfiles", "app", "action", "devenv", "devbox", "machine", "notebook", "playbook"]:
    make_tool_magic(tool)

@register_line_cell_magic
def dotscript(line, cell=None):
    command = f"zsh -i -c 'source ~/.dotfiles/source.sh; {line}"
    if cell is not None:
        command += f"; {cell.strip()}"
    command += "'"
    get_ipython().system(command)


import subprocess
import re

@register_line_cell_magic
def dot(line, cell=None):
    command = f". ~/.dotfiles/activate.sh {line}"
    if cell is not None:
        command += cell

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
    return clean_output


import configparser
from pathlib import Path
from io import StringIO

@register_line_magic
def dotini(line):
    """
    Usage: %dotini filename [mode]
    - filename: the ini file to load from ~/.config/dotfiles/
    - mode (optional): 'file', 'display', 'return', or 'both' (default: 'return')
    """
    parts = line.strip().split()
    if not parts:
        print("Usage: %dotini filename [mode]")
        return None

    ini_name = parts[0]
    if not ini_name.lower().endswith('.ini'):
        ini_name += '.ini'
    mode = parts[1] if len(parts) > 1 else "return"

    ini_path = Path.home() / '.config' / 'dotfiles' / ini_name 
    if not ini_path.is_file():
        print(f"File '{ini_path}' not found.")
        return None

    config = configparser.ConfigParser()
    config.read(str(ini_path))

    if mode == "file":
        lines = []
        for section in config.sections():
            lines.append(f'[{section}]')
            for key, value in config.items(section):
                lines.append(f'\t{key} = {value}')
            lines.append('')  # Blank line between sections

        ini_string = '\n'.join(lines)
        return ini_string

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

from IPython.display import display, Markdown
from pygments import highlight
from pygments.lexers import get_lexer_by_name
from pygments.formatters import TerminalFormatter

@register_line_magic
def code(line):
    """
    Usage: %code variable_name [language]
    Displays the value of the given variable as a Markdown code block.
    Optionally specify a language for syntax highlighting.
    """
    parts = line.strip().split()
    if not parts:
        print("Usage: %code variable_name [language]")
        return
    varname = parts[0]
    language = parts[1] if len(parts) > 1 else "text"
    ipy = get_ipython()
    if varname not in ipy.user_ns:
        print(f"Variable '{varname}' not found in user namespace.")
        return
    value = ipy.user_ns[varname]
    code = str(value)
    if language:
        md = f"```{language}\n{code}\n```"
    else:
        md = f"```\n{code}\n```"
    if in_jupyter():
        display(Markdown(md))
    else:
        lexer = get_lexer_by_name(language)
        print(highlight(code, lexer, TerminalFormatter()))

