
miniconda:
	mkdir ~/miniconda
	wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
	bash Miniconda3-latest-Linux-x86_64.sh -b -u -p ~/miniconda # batch mode (no questions), update, path
	~/miniconda/bin/conda init zsh
	rm Miniconda3-latest-Linux-x86_64.sh
	echo "To use miniconda, add the following to your .zshrc and start a new shell: PATH=~/miniconda/bin:$PATH"

rm_miniconda:
	rm -rf ~/miniconda
	rm -rf ~/.condarc ~/.conda ~/.continuum

docker:
	curl -fsSL https://get.docker.com -o get-docker.sh
	sudo sh ./get-docker.sh
	sudo usermod -a -G docker $USER
	rm get-docker.sh
	echo "Reboot to apply changes"

sshkeys:
	ssh-keygen -t rsa -b 4096
	echo "Use `ssh-copy-id <user>@<host> / <host>` to add keys to hosts"

obsidian-vault:
	export vault_dir=~/storage/shared/obsidian; \  # https://android.stackexchange.com/a/185949
	mkdir -pv $$vault_dir; \
	cd $$vault_dir && git clone https://github.com/MaxWolf-01/knowledge-base; \
	cd knowledge-base && git clone https://github.com/MaxWolf-01/.obsidian-mobile && mv .obsidian-mobile .obsidian
