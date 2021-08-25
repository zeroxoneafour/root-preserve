# root-install - requires user to have root privilege

no_rebuild=false
no_enable=false
ask_help=false
copy=false
keep=false
overwrite=false
debug=false
disabled=false
uninstall=false

files=""

while [ $# != 0 ]
do
	case "$1" in
		"--no-rebuild")
			no_rebuild=true
			shift
			;;
		"--no-enable")
			no_enable=true
			shift
			;;
		"--help")
			ask_help=true
			shift
			;;
		"--copy")
			copy=true
			shift
			;;
		"--keep")
			keep=true
			shift
			;;
		"--overwrite")
			overwrite=true
			shift
			;;
		"--debug")
			debug=true
			shift
			;;
		"--disabled")
			disabled=true
			shift
			;;
		"--uninstall")
			uninstall=true
			shift
			;;
		*)
			files="$files $1"
			shift
			;;
	esac
done

if [ "$overwrite" == true ] && [ "$keep" == true ]; then
	echo "You cannot use overwrite and keep simultaneously"
	exit 0
fi

if [ "$ask_help" = true ]; then
	echo "root-install help - requires root ability"
	echo "usage - ./root-install.sh [options] [files]"
	echo ""
	echo "--uninstall - Uninstalls instead of installing. Works with --no-rebuild and --no-enable to not uninstall programs or stop systemd services"
	echo "--no-rebuild - Do not rebuild and reinstall software"
	echo "--no-enable - Do not enable systemd units"
	echo "--copy - Copy instead of symlinking"
	echo "--keep - Keep existing files (does not apply to build, use --no-rebuild)"
	echo "--overwrite - Overwrite existing files"
	echo "--debug - Debugging, not actually helpful. Prints out a lot of metadata about the script"
	echo "--disabled - Don't actually do anything. For debugging"
	echo ""
	echo "files are optional. You can use directories or individual files. With no input, defaults to everything except this script and build directory"
	echo ""
	echo "Example - ./root-install.sh --no-rebuild --overwrite --copy ./etc ./usr/share/xsessions"
fi

returndir=$(pwd)
basedir=$(realpath "$0" | head --bytes -16)
cd $basedir

if [ -z "$files" ]; then
	unfilteredFiles=$(find -mindepth 1 -maxdepth 1 -type d)
	for file in $unfilteredFiles; do
		if [ "$file" != "./build" ] && [ "$file" != "./.git" ]; then
			files="$files $file"
		fi
	done
fi

if [ "$debug" == true ]; then
	if [ "$ask_help" == true ]; then echo ""; fi
	echo "Very helpfulTM debug info"
	echo "Files: $files"
	echo "no_rebuild: $no_rebuild"
	echo "no_enable: $no_enable"
	echo "ask_help: $ask_help"
	echo "copy: $copy"
	echo "keep: $keep"
	echo "overwrite: $overwrite"
	echo "debug: $debug"
	echo "disabled: $disabled"
	echo "uninstall: $uninstall"
fi

if [ "$disabled" == true ] || [ "$debug" == true ] || [ "$ask_help" == true ]; then
	exit 0
fi

for line in $files
do
	cd $basedir

	if [ "$debug" == true ]; then
		echo $line
	fi

	if [[ $(file $line) == *"directory"* ]]; then
		cd $line
		subFiles=$(find -mindepth 1 -type f)
		if [ "$debug" == true ]; then
			echo "$subFiles"
		fi
		for subfile in $subFiles
		do
			path="$(echo $line | cut -c 2-)$(echo $subfile | cut -c 2-)"
			replace=true
			if [ "$(ls $path)" == "$path" ]; then
				replace=false
				if [ "$keep" == true ]; then replace=false
				elif [ "$overwrite" == true ]; then replace=true
				else 
					echo "Replace $path?"
					read -n1 -p "[y/n]: " y_n
					echo ""
					if [ -n "$(echo "$y_n" | sed -e '/[Y/y]/ p' -)" ]; then
						replace=true
					else
						replace=false
					fi
				fi
			fi

			if [ "$replace" == true ]; then
				sudo rm $path
				if [ "$uninstall" != true ]; then
					if [ "$copy" == true ]; then
						sudo cp $subfile $path
					else
						sudo ln -rs $subfile $path
					fi
				fi
			fi
		done
	else
		path=$(echo $line | cut -c 2-)
		replace=true
		if [ $(ls $path) == "$path" ]; then
			replace=false
			if [ "$keep" == true ]; then replace=false
			elif [ "$overwrite" == true ]; then replace=true
			else
				echo "Replace $path?"
				read -n1 -p "[y/n]: " y_n
				echo ""
				if [ -n "$(echo "$y_n" | sed -e '/[Y/y]/ p' -)" ]; then
					replace=true
				else
					replace=false
				fi
			fi
		fi

		if [ "$replace" == true ]; then
			sudo rm $path
			if [ "$uninstall" != true ]; then
				if [ "$copy" == true ]; then
					sudo cp -f $line $path
				else
					sudo ln -frs $line $path
				fi
			fi
		fi
	fi
done

cd $basedir

if [ "$no_rebuild" != true ]; then

	builds=$(ls build)
	cd build

	for line in $builds
	do
		cd $basedir/build/$line
		if [ "$uninstall" == true ]; then
			bash $(pwd)/uninstall.sh
		else
			bash $(pwd)/make.sh
		fi
	done
fi

if [ "$no_enable" != true ]; then

	sudo systemctl daemon-reload

	cd $basedir/etc/systemd/system

	services=$(find -mindepth 1 -maxdepth 1 -type f)

	for service in $services
	do
		if [ "$uninstall" != true ]; then
			sudo systemctl enable --now $(echo $service | cut -c 3-)
		else
			sudo systemctl disable --now $(echo $service | cut -c 3-)
		fi
	done
fi

cd $returndir
