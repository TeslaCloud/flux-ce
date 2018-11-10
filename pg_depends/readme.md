1. Locate the files for your OS (windows or linux)
2. Put these files to the folder where your srcds executable is, which is usually these paths:

On Windows:
`.\SERVER_DIR\srcds.exe`

On any Linux:
`./SERVER_DIR/srcds_linux`

Yes, the "bin" folder from this folder is supposed to go on top of the "SERVER_DIR/bin" folder.

**In case it doesn't work on Linux:**
```sh
# add postgresql apt repos beforehand!
sudo apt-get install libpq-dev:i386
```
