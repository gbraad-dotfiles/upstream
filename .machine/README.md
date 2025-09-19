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
app macadam install
app machinefile install
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


## CentOS-specifc actions

### build-centos
```sh interactive
machine centos-output build ./centos-cloud/Machinefile from centos-cloud
```

### export-centos
```sh interactive
machine centos-output export dotcentos
```

### clean-centos
```sh interactive
machine centos-output rm
```


## AlmaLinux-specifc actions

### build-almalinux
```sh interactive
machine almalinux-output build ./almalinux-cloud/Machinefile from almalinux-cloud
```

### export-almalinux
```sh interactive
machine almalinux-output export dotalmalinux
```

### clean-almalinux
```sh interactive
machine almalinux-output rm
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


## Ubuntu-specifc actions

### build-ubuntu
```sh interactive
machine ubuntu-output build ./ubuntu-cloud/Machinefile from ubuntu-cloud
```

### export-ubuntu
```sh interactive
machine ubuntu-output export dotubuntu
```

### clean-ubuntu
```sh interactive
machine ubuntu-output rm
```


## Alpine-specifc actions

### build-alpine
```sh interactive
machine alpine-output build ./alpine-cloud/Machinefile from alpine-cloud
```

### export-alpine
```sh interactive
machine alpine-output export dotalpine
```

### clean-alpine
```sh interactive
machine alpine-output rm
```



