# Windows 초기 설정

Windows 설치 직후 winget 프로그램 설치, Windows 기능 활성화, WSL(Fedora) 개발 환경 구성.

## Windows (PowerShell)

```powershell
##################################################
# Winget
##################################################
pwsh$ winget upgrade --all

##################################################
# 필수 프로그램 설치
##################################################
pwsh$ winget install Microsoft.WindowsTerminal
pwsh$ winget install Mozilla.Firefox.ko
pwsh$ winget install Microsoft.PowerShell
pwsh$ winget install Kakao.KakaoTalk
pwsh$ winget install Microsoft.VisualStudioCode
pwsh$ winget install Git.Git
pwsh$ winget install cURL.cURL
pwsh$ winget install Postman.Postman
pwsh$ winget install DBeaver.DBeaver.Community
pwsh$ winget install Notepad++.Notepad++
pwsh$ winget install 7zip.7zip
pwsh$ winget install QL-Win.QuickLook
pwsh$ winget install ShareX.ShareX
pwsh$ winget install Microsoft.PowerToys
pwsh$ winget install UnicornSoft.UnicornHTTPS
pwsh$ winget install Apple.iTunes
pwsh$ winget install CharlesMilette.TranslucentTB
pwsh$ winget install Netflix
pwsh$ winget install Spotify.Spotify
pwsh$ winget install VideoLAN.VLC
pwsh$ winget upgrade --all

##################################################
# Windows 기능 활성화
##################################################
pwsh$ dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
pwsh$ dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

##################################################
# Windows 기능 활성화 : for windows pro
##################################################
pwsh$ dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V-All /all /norestart
pwsh$ dism.exe /online /enable-feature /featurename:Containers /all /norestart

##################################################
# install wsl distribution
##################################################
pwsh$ wsl --install --no-distribution
pwsh$ Restart-Computer
pwsh$ wsl --install -d FedoraLinux-42
pwsh$ wsl -d FedoraLinux-42
```

## WSL (Fedora)

```bash
##################################################
# set account
##################################################
wsl$ sudo -i
wsl$ passwd # <ROOT_PASSWORD>
wsl$ passwd kkmaddress

##################################################
# set wsl
##################################################
wsl$ vi /etc/wsl.conf
[boot]
systemd=true                            # systemctrl 활성화

[user]
default="kkmaddress"                    # 기본 로그인 사용자 지정

[interop]
enabled=true                            # 윈도우 프로세스와의 상호 운용 활성화

[automount]
enabled=true                            # 윈도우 드라이브 자동 마운트 활성화
root=/mnt                               # 마운트 경로 지정
options="metadata,umask=22,fmask=11"    # metadata : Linux 권한 및 심볼릭 링크 지원
                                        # umask=22  : 새 파일 기본 권한 755
                                        # fmask=11  : 새 파일 기본 권한 644

##################################################
# install git
##################################################
wsl$ sudo dnf install -y git
wsl$ git config --global pull.rebase true
wsl$ git config --global rebase.autoStash true
wsl$ git config --global i18n.logOutputEncoding utf-8
wsl$ git config --global core.quotepath false
wsl$ git config --global user.name "kkmname"
wsl$ git config --global user.email "kkmaddress@gmail.com"
wsl$ git config --global credential.helper store
wsl$ git config --global core.editor "vim"
wsl$ git config --global core.pager cat
wsl$ git config --global init.defaultBranch main
wsl$ echo "https://kkmname:<GITHUB_TOKEN>@github.com" > ~/.git-credentials

##################################################
# install common. library
##################################################
wsl$ sudo dnf update -y
wsl$ sudo dnf install -y wget yum-utils nss-tools jq

##################################################
# install docker
##################################################
wsl$ sudo dnf install -y dnf-plugins-core
wsl$ sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
wsl$ sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc
wsl$ sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
wsl$ sudo systemctl enable docker.service
wsl$ sudo setenforce 0
wsl$ sudo sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
wsl$ sudo systemctl disable firewalld --now
wsl$ sudo usermod -aG docker $USER
wsl$ newgrp docker

##################################################
# install fonts
##################################################
wsl$ sudo dnf install -y fontconfig
wsl$ mkdir -p ~/.local/share/fonts
wsl$ wget -O ~/.local/share/fonts/MesloLGS\ NF\ Regular.ttf https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
wsl$ wget -O ~/.local/share/fonts/MesloLGS\ NF\ Bold.ttf https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
wsl$ wget -O ~/.local/share/fonts/MesloLGS\ NF\ Italic.ttf https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
wsl$ wget -O ~/.local/share/fonts/MesloLGS\ NF\ Bold\ Italic.ttf https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf
wsl$ fc-cache -f -v

##################################################
# install zsh
##################################################
wsl$ sudo dnf install -y zsh
wsl$ sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
wsl$ git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
wsl$ git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
wsl$ git clone https://github.com/zsh-users/zsh-completions $ZSH_CUSTOM/plugins/zsh-completions
wsl$ sed -i 's|^ZSH_THEME=.*|ZSH_THEME="sunrise"|' ~/.zshrc
wsl$ sed -i '/^plugins=(git)$/c\
plugins=(\
    git\
    zsh-autosuggestions\
    zsh-completions\
    zsh-syntax-highlighting\
)' ~/.zshrc
wsl$ source ~/.zshrc

### powerlevel10k 테마 사용 시
wsl$ git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
### powerlevel10k 설정 초기화 시
wsl$ rm ~/.p10k.zsh
wsl$ p10k configure

##################################################
# install jabba(java)
##################################################
wsl$ curl -sL https://github.com/shyiko/jabba/raw/master/install.sh | bash && . ~/.jabba/jabba.sh
wsl$ cat ~/.zshrc | grep jabba
[ -s "/home/kkmaddress/.jabba/jabba.sh" ] && source "/home/kkmaddress/.jabba/jabba.sh"
wsl$ source ~/.zshrc
wsl$ jabba ls-remote | grep openjdk
wsl$ jabba install openjdk@1.17.0
wsl$ jabba use openjdk@1.17.0
wsl$ jabba alias default openjdk@1.17.0

### oracle 1.8.202 사용 시
wsl$ wget https://repo.huaweicloud.com/java/jdk/8u202-b08/jdk-8u202-linux-x64.tar.gz
wsl$ jabba install oracle@1.8.202=tgz+file:///root/jdk-8u202-linux-x64.tar.gz

##################################################
# install Maven
##################################################
wsl$ cd ~
wsl$ wget https://archive.apache.org/dist/maven/maven-3/3.6.0/binaries/apache-maven-3.6.0-bin.tar.gz
wsl$ tar -xzf apache-maven-3.6.0-bin.tar.gz
wsl$ mv apache-maven-3.6.0 /opt/utils/maven
wsl$ cat >> ~/.zshrc << 'EOF'
# Maven
export MAVEN_HOME=/opt/utils/maven
export PATH=$MAVEN_HOME/bin:$PATH
EOF
wsl$ source ~/.bashrc
wsl$ mvn -version

##################################################
# install vscode
##################################################
### code 명령 실행 시 호스트의 VSCODE WSL 확장에서
### VS Code Server 설치가 진행됨
wsl$ code
wsl$ code --install-extension ms-ceintl.vscode-language-pack-ko
wsl$ code --install-extension vscjava.vscode-java-pack
wsl$ code --install-extension vmware.vscode-spring-boot
wsl$ code --install-extension vscjava.vscode-gradle
wsl$ code --install-extension eamodio.gitlens
wsl$ code --install-extension mhutchie.git-graph
wsl$ code --install-extension sdras.night-owl
wsl$ code --install-extension vscode-icons-team.vscode-icons
wsl$ code --install-extension vscjava.vscode-spring-initializr
wsl$ code --install-extension ms-vscode-remote.remote-wsl

##################################################
# install lazyssh
##################################################
wsl$ LATEST_TAG=$(curl -fsSL https://api.github.com/repos/Adembc/lazyssh/releases/latest | jq -r .tag_name)
wsl$ curl -L -o "lazyssh.tar.gz" "https://github.com/Adembc/lazyssh/releases/download/${LATEST_TAG}/lazyssh_$(uname)_$(uname -m).tar.gz"
wsl$ tar -xzf lazyssh.tar.gz
wsl$ sudo mv lazyssh /usr/local/bin/
wsl$ lazyssh

##################################################
# install Claude
##################################################
wsl$ curl -fsSL https://claude.ai/install.sh | bash
wsl$ vi ~/.zshrc
...
alias claude+='claude --dangerously-skip-permissions'
```
