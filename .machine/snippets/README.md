Snippets
========


### info

These files are 'examples' and/or snippets from the Containerfiles that can be
executed with the [`machinefile`](https://github.com/gbraad-redhat/machinefile) tool.


### user-setup
```sh
machinefile gbraad@${TARGET} --arg USER=${USER} machine-setup-user
```

### root-setup
```sh
machinefile root@${TARGET} machine-setup-root
```

