#!/bin/bash
rm -fv **/*.0.svg
7z a arcticons-$1.7z arcticons-dark arcticons-light
tar cf arcticons-$1.tar.gz arcticons-dark arcticons-light
