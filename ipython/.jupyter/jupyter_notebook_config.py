import os
c = get_config()

c.ServerApp.terminado_settings = {'shell_command': ['/bin/zsh']}
c.NotebookApp.notebook_dir = os.path.expanduser('~/Documents/Notebooks')
