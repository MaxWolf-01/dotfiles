all: miniconda docker miscl clone_repos

miscl: toolbox act ssh

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

toolbox:
	# latest jetbrains toolbox (https://github.com/nagygergo/jetbrains-toolbox-install)
	curl -fsSL https://raw.githubusercontent.com/nagygergo/jetbrains-toolbox-install/master/jetbrains-toolbox.sh | bash
	cd /usr/local/bin && ./jetbrains-toolbox

act:
	# local github actions runner
	curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo zsh

sshkeys:
	ssh-keygen -t rsa -b 4096
	echo "Use `ssh-copy-id <user>@<host> / <host>` to add keys to hosts"

clone_repos: obsidian_vault

obsidian_vault:
	export vault_dir=~/repos/obsidian; \
	mkdir -pv $$vault_dir; \
	cd $$vault_dir && git clone git@github.com:MaxWolf-01/knowledge-base.git; \
	cd knowledge-base && git clone git@github.com:MaxWolf-01/.obsidian-pc.git && mv .obsidian-pc .obsidian


nvidia:
	echo "TODO"
