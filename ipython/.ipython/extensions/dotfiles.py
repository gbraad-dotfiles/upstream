from IPython.core.magic import register_line_cell_magic

def load_ipython_extension(ipython):
    print("dotfiles extension loaded!")

    @register_line_cell_magic
    def dotfiles(line, cell=None):
        command = line
        if cell:
            command += '\n' + cell
        get_ipython().system(f"zsh -i -c '. ~/.dotfiles/source.sh; {command}'")

