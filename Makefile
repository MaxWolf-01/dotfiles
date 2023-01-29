install_all: miniconda docker clone_repos

miniconda:
	mkdir ~/miniconda
	wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
	bash Miniconda3-latest-Linux-x86_64.sh -b -u -p ~/miniconda # batch mode (no questions), update, path
	conda init zsh
	rm Miniconda3-latest-Linux-x86_64.sh

rm_miniconda:
	rm -rf ~/miniconda
	rm -rf ~/.condarc ~/.conda ~/.continuum

docker:
	curl -fsSL https://get.docker.com -o get-docker.sh
	sudo sh ./get-docker.sh
	rm get-docker.sh

clone_repos:
	echo "TODO"
    # TODO private env file with repo names
    # https://stackoverflow.com/questions/10929453/read-a-file-line-by-line-assigning-the-value-to-a-variable


nvidia:
	echo "TODO"
