#!/bin/bash
#
# SSH through a jump host to a target host and launch (or attach to) a tmux session.
#
# Replicates this manual sequence in a single connection:
#     ssh kali@c2c.foo.solutions        # jump host
#     ssh -p 9900 trik@localhost        # target, reached from the jump host
#     tmux new -A -s squad              # create-or-attach session
#
# Usage:
#   ./ssh_tmux.sh <jump_host> <target_host> <target_port> <session_name>
#
# Host arguments accept user@host; the jump host may include a non-default port
# as host:port. SSH config (~/.ssh/config) aliases are respected.
#
# Example:
#   ./ssh_tmux.sh kali@c2c.foo.solutions trik@localhost 9900 squad

set -euo pipefail

usage() {
    echo "Usage: $0 <jump_host> <target_host> <target_port> <session_name>" >&2
    exit 1
}

[ "$#" -eq 4 ] || usage

JUMP_HOST="$1"
TARGET_HOST="$2"
TARGET_PORT="$3"
SESSION_NAME="$4"

# -J : ProxyJump — tunnel through JUMP_HOST; localhost is resolved on that side.
# -p  : port for the TARGET_HOST connection (forwarded via the jump host).
# -t  : force pseudo-terminal allocation so tmux can attach interactively.
# new-session -A : attach to the session if it exists, otherwise create it.
ssh -J "$JUMP_HOST" -p "$TARGET_PORT" "$TARGET_HOST" -t \
    "tmux new-session -A -s '$SESSION_NAME'"
