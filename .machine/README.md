# Machinefiles


### info

These files describe how to build a VM image with dotfiles based on a provided cloudimage.

Each of these images can be build as follows:

```sh
run dependencies
run fedora build
run fedora export
run clean
```

> [!NOTE]
> This assumes you have my `dotfiles` installed.


## Generic actions

### dependencies
```sh 
apps macadam install
apps machinefile install
```


## Fedora-specifc actions

### build-fedora
```sh interactive
machine fedora-output build ./fedora-cloud/Machinefile from fedora-cloud
```

### export-fedora
```sh interactive
machine fedora-output export dotfedora
```

### clean-fedora
```sh interactive
machine fedora-output rm
```


## Debian-specifc actions

### build-debian
```sh interactive
machine debian-output build ./debian-cloud/Machinefile from debian-cloud
```

### export-debian
```sh interactive
machine debian-output export dotdebian
```

### clean-debian
```sh interactive
machine debian-output rm
```

