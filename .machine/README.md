# Machinefiles

## info

These files describe how to build a VM image with dotfiles based on a provided cloudimage.

Each of these images can be build as follows:

```sh
run fedora build
run fedora export
```

## dependencies
```sh 
apps macadam install
apps machinefile install
```


> [!NOTE]
> This assumes you have my `dotfiles` installed.



## build-fedora 
```sh interactive
machine output build ./fedora-cloud/Machinefile from fedora-cloud
```

## export-fedora 
```sh interactive
machine output export dotfedora
```


## clean
```sh interactive
machine output rm
```
