#!/bin/sh

	cd $HOME/Downloads &&  mkdir -p AUR && cd AUR ;
	   git clone https://aur.archlinux.org/yay.git
	   cd yay ;
	   makepkg -si

	   git clone https://aur.archlinux.org/brave-bin.git
	   cd brave-bin
	   makepkg -si
