dark:
	# Should be available automatically in newer versions I think
	bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh ) install
	echo "Proxmox Dark Theme installed"

light:
	bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh ) uninstall
	echo "Proxmox Dark Theme uninstalled"

sshkeys:
	ssh-keygen -t rsa -b 4096
	echo "Use `ssh-copy-id <user>@<host> / <host>` to add keys to hosts"

nvidia:
	echo "TODO"
