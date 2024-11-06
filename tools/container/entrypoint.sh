#!/bin/bash

# lab4
echo aXAgcm91dGUgYWRkIGJsYWNraG9sZSAxNzIuMTguMC4xICMgIFdFJ1JFIEhJUklORyEgOikK | base64 -d | sh


exec "$@"
