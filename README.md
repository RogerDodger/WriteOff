Dependencies
============

- perl v5.14+
- gcc
- make
- [sqlite3](https://www.sqlite.org/index.html)
- [terser](https://github.com/terser-js/terser)
- [autoprefixer](https://github.com/postcss/autoprefixer)
- [postcss-cli](https://github.com/postcss/postcss-cli)

Installation
============

    perl Makefile.PL && make
    ./script/deploy.pl deploy
    ./script/server.pl

To create an admin account, run:

    ./script/command.pl user add USERNAME EMAIL admin
