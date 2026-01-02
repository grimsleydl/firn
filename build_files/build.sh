#!/bin/bash

set -ouex pipefail

rsync -rvKl /ctx/system_files/ /

/ctx/build_files/install-nix.sh
