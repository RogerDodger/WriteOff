#!/bin/bash
cd $(dirname "$0")
sass -C writeoff.scss ../writeoff.css
postcss --use autoprefixer -o ../writeoff.css ../writeoff.css
