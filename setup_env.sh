#!/bin/bash
# -*- coding: utf-8 -*-
# Первоначальная настройка среды после checkout

set -o nounset
set -o errexit
set -o pipefail


function usage()
{
    echo "Usage: $0 [--devel]" >&2
}

BASE_DIR="$(dirname $(realpath $0))"
VENV_DIR="${BASE_DIR}/.pyenv"
VENV_DROP=N
VENV_TAGS=
VENV_NAME=otus-nosql


while [ $# -ge 1 ]; do
    case "$1" in
        --dev|--devel)
            VENV_TAGS="[dev]"
            ;;
        -f|--force)
            VENV_DROP=Y
            ;;
        *)
            usage
            exit 2
            ;;
    esac
    shift
done


if [ -d "$VENV_DIR" ]; then
    if [ "$VENV_DROP" == "Y" ]; then
        rm -rf "$VENV_DIR"
    else
        echo "error: virtualenv '$VENV_DIR' already exists" >&2
        exit 1
    fi
fi

if ! $(command -v virtualenv >/dev/null 2>&1); then
    echo "error: missing virtualenv tool" >&2
    exit 1
fi

echo "creating private virtualenv ..."
virtualenv --prompt "$VENV_NAME" "$VENV_DIR"

. $VENV_DIR/bin/activate

python -m pip install pip --upgrade
pip install -r requirements.txt

# FIXME ставит в ~/.ansible/collections/ansible_collections
ansible-galaxy collection install \
               --requirements-file $BASE_DIR/ansible/galaxy/requirements.txt
