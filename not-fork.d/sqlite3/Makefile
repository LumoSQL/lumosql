# Generate a few files in this directory

FILES = $(shell awk '/^[^\#]/ { print "files/lumo_" $0 }' backend-files)

all: backend-rename.mod backend-new-files.mod files

# replace references to files listed in "backend-files" to prefix a "lumo_" to them
backend-rename.mod : backend-files sqlite3-files backend-generate
	sh backend-generate sed backend-files sqlite3-files > $@

# create new files with name "lumo_X" for each file X in "backend-files"
backend-new-files.mod : backend-files sqlite3-files backend-generate
	sh backend-generate replace backend-files > $@

.PHONY : files
files :
	sh backend-generate files backend-files

