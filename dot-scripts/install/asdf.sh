#!/bin/bash

export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# Node
asdf plugin add nodejs
asdf install nodejs latest
asdf set --home nodejs latest

asdf plugin add pnpm
asdf install pnpm latest
asdf set --home pnpm latest

# Python 
asdf plugin add python
asdf install python latest
asdf install python 3.13.11
asdf set --home python latest

# uv
asdf plugin add uv
asdf install uv latest
asdf set --home uv latest

# Java
asdf plugin add java
asdf install java openjdk-17.0.2
asdf set --home java openjdk-17.0.2