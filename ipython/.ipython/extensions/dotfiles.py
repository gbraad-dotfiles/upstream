from IPython.core.magic import register_line_cell_magic

def load_ipython_extension(ipython):
    print("dotfiles extension loaded!")

    @register_line_cell_magic
    def dotfiles(line, cell=None):
        command = line
        if cell:
            command += '\n' + cell
        get_ipython().system(f"zsh -i -c 'if ! typeset -f dotfiles >/dev/null; then source ~/.dotfiles/source.sh; fi; {command}'")

from IPython.core.magic import register_line_magic
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
