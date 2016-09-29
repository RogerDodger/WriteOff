#!/bin/bash
cd $(dirname "$0")
sassc writeoff.scss ../writeoff.css
postcss --use autoprefixer -o ../writeoff.css ../writeoff.css
