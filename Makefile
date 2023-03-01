all: miniconda docker miscl clone_repos

miscl: toolbox act ssh

miniconda:
	mkdir ~/miniconda
	wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
	bash Miniconda3-latest-Linux-x86_64.sh -b -u -p ~/miniconda # batch mode (no questions), update, path
	export PATH=~/miniconda/bin:$PATH
	conda init zsh
	rm Miniconda3-latest-Linux-x86_64.sh

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

clone_repos:
	echo "TODO"
    # TODO private env file with repo names
    # https://stackoverflow.com/questions/10929453/read-a-file-line-by-line-assigning-the-value-to-a-variable

nvidia:
	echo "TODO"
