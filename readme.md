# root-preserve

A simple bash script that automates building non-packaged software and copying/symlinking certain files to your root filesystem. Built by me so I don't lose my configs when reinstalling Linux (often).

By default, copies all directories in its location except for `./build` and `./.git` to root. Files copied can be customized.

Do `./root-install.sh --help` for more info on running the script.
