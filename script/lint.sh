#!/bin/sh
# scripts/lint

swift format lint --strict --parallel --recursive .
