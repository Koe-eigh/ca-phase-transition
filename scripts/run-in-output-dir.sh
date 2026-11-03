#!/bin/sh
set -eu

executable=$1
shift
case $executable in
    /*) ;;
    *) executable="$(pwd)/$executable" ;;
esac
cd "$OUTPUT_DIR"
exec "$executable" "$@"
