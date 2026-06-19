#!/bin/bash

## Start from scratch
git init --bare $HOME/.myconf

## CLone repo
git clone --bare https://github.com/myfoostrong/dot $HOME/.cfg

alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
## Is the below the same, or for inline execution? re: https://www.atlassian.com/git/tutorials/dotfiles
function config {
   /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME $@
}
mkdir -p .config-backup
config checkout
if [ $? = 0 ]; then
  echo "Checked out config.";
  else
    echo "Backing up pre-existing dot files.";
    config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .config-backup/{}
fi;
config checkout
config config status.showUntrackedFiles no

## Ensure origin has a proper fetch refspec + remote-tracking refs.
## A bare clone can leave remote.origin.fetch unset, which makes
## `config fetch` write only to FETCH_HEAD and `config branch -a`
## show no origin/* branches. Idempotent and work-tree-safe (fetch
## never touches $HOME), so this is safe to re-run on existing setups.
config config --replace-all remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
config fetch origin

