**WORK IN PROGRESS**

dirnav
======

TODO


Installation
------------

### Manual

Clone the github repository, and source `dirnav.sh` in your shell config (eg. `.bashrc` for *bash*) using:

```
. /path/to/repo/dirnav.sh
```

If you are using *zsh*, source `dirnav.plugin.zsh` instead:

```
source /path/to/repo/dirnav.plugin.zsh
```

### Using "Antigen"

If you are using *zsh* with the *antigen* plugin-manager, add this line to your config:

```
antigen bundle notuxic/sh-dirnav 
```


Usage
-----

### ad

`ad` switches to the previous working directory. It is essentially just an alias to `cd "$OLDPWD"`


### bd

`bd` moves to the first parent directory containing the substring passed as argument.
When called without arguments, it moves up one directory.


### jd

TODO


Configuration
-------------

TODO

