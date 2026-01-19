#!/bin/bash

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
brew update && brew upgrade

brew install asdf

brew install opencode

brew tap hashicorp/tap
brew install hashicorp/tap/terraform