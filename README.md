Packer + Machinefile test
=========================

Use Packer and Machinefile to create a Debian VM from a containerfile


## Instructions

### Requirements and preparations

This installs packer, macadam, machinefile and logs in to the container registry.

```sh
$ ./prepare.sh
```

> [!NOTE]
> This relies on my dotfiles


### Build process

This runs packer and waits until SSH becomes available, after whish it starts `machinefile` to perform the instructions as mentioned in the `Machinefile` container description file. This is a direct copy from my .devcontainer setup

```sh
$ ./build.sh
```

### Image publish

This wraps the output from the build step in a container image and publishes this on the GitHub Container Registry

```
$ ./diskimage.sh
```

### Usage

```sh
$ machine dotdebian install
```

> [!NOTE]
> This relies on my dotfiles
