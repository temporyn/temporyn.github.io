# Fedora Workstation 설정

Fedora Workstation 설치 직후의 전체 설정 과정. 시스템·데스크톱 기초 → 개발 도구 → 가상화 → GNOME 앱·확장 → CLI 유틸리티 순이다.

## 시스템 · 데스크톱 기초

```bash
########################################
# 시스템 업데이트
########################################
$ sudo dnf upgrade --refresh -y

########################################
# RPM Fusion 활성화
########################################
$ sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

########################################
# 멀티미디어 코덱 (DNF5 기준)
########################################
$ sudo dnf group install -y multimedia
$ sudo dnf group install -y sound-and-video

########################################
# Common Library
########################################
$ sudo dnf install -y wget jq nss-tools unzip zip

########################################
# Git  (토큰은 본인 것으로 교체)
########################################
$ sudo dnf install -y git
$ git config --global pull.rebase true
$ git config --global rebase.autoStash true
$ git config --global i18n.logOutputEncoding utf-8
$ git config --global core.quotepath false
$ git config --global user.name "kkmname"
$ git config --global user.email "kkmaddress@gmail.com"
$ git config --global credential.helper store
$ git config --global core.editor "vim"
$ git config --global core.pager cat
$ git config --global init.defaultBranch main
$ echo "https://kkmname:<GITHUB_TOKEN>@github.com" > ~/.git-credentials

########################################
# Docker
########################################
$ sudo dnf remove -y docker \
  docker-client \
  docker-client-latest \
  docker-common \
  docker-latest \
  docker-latest-logrotate \
  docker-logrotate \
  docker-selinux \
  docker-engine-selinux \
  docker-engine
$ sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
$ sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
$ sudo systemctl enable --now docker
$ sudo usermod -aG docker $USER
$ newgrp docker

########################################
# 한글 입력기 및 폰트
########################################
$ sudo dnf install -y --skip-unavailable \
  ibus-hangul \
  google-noto-sans-cjk-fonts \
  google-noto-serif-cjk-fonts

# 입력 소스: 한글 엔진만 등록 (영문은 엔진 내부 토글)
$ gsettings set org.gnome.desktop.input-sources sources "[('ibus', 'hangul')]"

# 오른쪽 Alt → ISO_Level3_Shift 로 매핑
$ gsettings set org.gnome.desktop.input-sources xkb-options "['lv3:ralt_switch']"

# ibus-hangul 전환키: ISO_Level3_Shift (오른쪽 Alt)
$ gsettings set org.freedesktop.ibus.engine.hangul switch-keys "ISO_Level3_Shift"

# GNOME 기본 입력 소스 전환 단축키 제거 (충돌 방지)
$ gsettings set org.gnome.desktop.wm.keybindings switch-input-source "[]"
$ gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "[]"

########################################
# 테마
########################################
$ gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
$ gsettings set org.gnome.desktop.interface gtk-theme    'Adwaita-dark'

# 야간 모드
$ gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled     true
$ gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 4000

# 창 버튼 (최소화/최대화/닫기)
$ gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'

########################################
# 호스트명 변경
########################################
$ sudo hostnamectl set-hostname kkmmain

########################################
# 홈 디렉토리 한글 → 영문
# required logout for apply updated
########################################
$ LANG=C xdg-user-dirs-update --force
$ rm -rf ~/공개 ~/다운로드 ~/문서 ~/바탕화면 ~/비디오 ~/사진 ~/서식 ~/음악

# 나우틸루스 사이드바 북마크 영문 경로로 갱신
$ cat > ~/.config/gtk-3.0/bookmarks << EOF
file://$HOME/Documents
file://$HOME/Music
file://$HOME/Pictures
file://$HOME/Videos
file://$HOME/Downloads
EOF
$ nautilus -q

########################################
# 시간 설정
# 타임존: Asia/Seoul, NTP: active (정상)
# RTC in local TZ 유지 (Windows 듀얼부팅 환경)
########################################
$ timedatectl set-ntp true
```

## 셸 · 개발 도구

```bash
########################################
# MesloLGS NF 폰트
########################################
$ sudo dnf install -y fontconfig
$ mkdir -p ~/.local/share/fonts
$ wget -O ~/.local/share/fonts/MesloLGS\ NF\ Regular.ttf     https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
$ wget -O ~/.local/share/fonts/MesloLGS\ NF\ Bold.ttf        https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
$ wget -O ~/.local/share/fonts/MesloLGS\ NF\ Italic.ttf      https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
$ wget -O ~/.local/share/fonts/MesloLGS\ NF\ Bold\ Italic.ttf https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf
$ fc-cache -f -v

########################################
# Zsh + Oh My Zsh
########################################
$ sudo dnf install -y zsh
$ sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
$ git clone https://github.com/zsh-users/zsh-autosuggestions     ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
$ git clone https://github.com/zsh-users/zsh-syntax-highlighting  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
$ git clone https://github.com/zsh-users/zsh-completions          ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions
$ git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
$ sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' ~/.zshrc
$ sed -i '/^plugins=(git)$/c\plugins=(\n    git\n    zsh-autosuggestions\n    zsh-completions\n    zsh-syntax-highlighting\n)' ~/.zshrc
$ source ~/.zshrc
# powerlevel10k 초기 설정: p10k configure

########################################
# Java (SDKMAN!)
# jabba 대체 - jabba는 2021년 archived 상태
########################################
$ curl -s "https://get.sdkman.io" | bash
$ source "$HOME/.sdkman/bin/sdkman-init.sh"
$ sdk install java 17.0.13-tem
$ sdk default java 17.0.13-tem
$ java --version

########################################
# Maven
########################################
$ cd ~
$ wget https://archive.apache.org/dist/maven/maven-3/3.6.0/binaries/apache-maven-3.6.0-bin.tar.gz
$ tar -xzf apache-maven-3.6.0-bin.tar.gz
$ sudo mv apache-maven-3.6.0 /opt/maven
$ cat >> ~/.zshrc << 'EOF'
# Maven
export MAVEN_HOME=/opt/maven
export PATH=$MAVEN_HOME/bin:$PATH
EOF
$ source ~/.zshrc
$ mvn -version
```

## 가상화 (KVM · Vagrant)

```bash
########################################
# KVM/libvirt
########################################
$ grep -E -c '(vmx|svm)' /proc/cpuinfo
$ sudo dnf install -y @virtualization \
	libvirt libvirt-devel qemu-kvm \
	ruby-devel gcc make \
	libxml2-devel libxslt-devel zlib-devel
$ sudo systemctl enable --now libvirtd
$ sudo usermod -aG libvirt $USER
# required logout for apply updated
$ virt-host-validate
$ vi ~/.zshrc
...
export VAGRANT_DEFAULT_PROVIDER=libvirt

### remove/disable ###
$ sudo dnf remove @virtualization
$ sudo modprobe -r kvm_amd kvm

########################################
# Vagrant
########################################
$ sudo dnf install -y vagrant
$ vagrant plugin install vagrant-libvirt
$ vagrant plugin list
```

## 데스크톱 앱 · GNOME

```bash
########################################
# Google Chrome
########################################
$ sudo dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm

########################################
# VSCode (Microsoft RPM 저장소)
########################################
$ sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
$ sudo tee /etc/yum.repos.d/vscode.repo << 'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
$ sudo dnf install -y code
$ code --install-extension ms-ceintl.vscode-language-pack-ko
$ code --install-extension vscjava.vscode-java-pack
$ code --install-extension vmware.vscode-spring-boot
$ code --install-extension vscjava.vscode-gradle
$ code --install-extension mhutchie.git-graph
$ code --install-extension sdras.night-owl
$ code --install-extension vscode-icons-team.vscode-icons
$ code --install-extension vscjava.vscode-spring-initializr

########################################
# GNOME 유틸리티
########################################
$ sudo dnf install -y gnome-tweaks gnome-extensions-app sassc make

########################################
# AppIndicator (Fedora 패키지)
########################################
$ sudo dnf install -y gnome-shell-extension-appindicator

########################################
# Extension Manager (Flatpak)
########################################
$ sudo dnf install -y flatpak
$ flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
$ flatpak install -y flathub com.mattjakeman.ExtensionManager

########################################
# Obsidian (Flatpak)
########################################
$ flatpak install -y flathub md.obsidian.Obsidian

########################################
# Dash to Dock (GitHub 소스)
########################################
$ git clone https://github.com/micheleg/dash-to-dock.git /tmp/dash-to-dock
$ cd /tmp/dash-to-dock && make install && cd ~
$ rm -rf /tmp/dash-to-dock

########################################
# Blur my Shell (GitHub 소스)
########################################
$ git clone https://github.com/aunetx/blur-my-shell.git /tmp/blur-my-shell
$ cd /tmp/blur-my-shell && make install && cd ~
$ rm -rf /tmp/blur-my-shell

########################################
# Vitals (GitHub 소스)
########################################
$ git clone https://github.com/corecoding/Vitals.git /tmp/vitals
$ mkdir -p ~/.local/share/gnome-shell/extensions/Vitals@CoreCoding.com
$ cp -r /tmp/vitals/* ~/.local/share/gnome-shell/extensions/Vitals@CoreCoding.com/
$ glib-compile-schemas ~/.local/share/gnome-shell/extensions/Vitals@CoreCoding.com/schemas/
$ rm -rf /tmp/vitals

########################################
# Caffeine
########################################
$ sudo dnf install -y gnome-shell-extension-caffeine
$ gnome-extensions list | grep caffeine

########################################
# Extension 활성화
# required logout for apply updated
########################################
$ gnome-extensions enable dash-to-dock@micxgx.gmail.com
$ gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com
$ gnome-extensions enable blur-my-shell@aunetx
$ gnome-extensions enable Vitals@CoreCoding.com
$ gnome-extensions enable caffeine@patapon.info
```

## 시스템 서비스 · CLI 유틸 · 미디어

```bash
########################################
# lazyssh
########################################
$ LATEST_TAG=$(curl -fsSL https://api.github.com/repos/Adembc/lazyssh/releases/latest | jq -r .tag_name)
$ curl -L -o lazyssh.tar.gz "https://github.com/Adembc/lazyssh/releases/download/${LATEST_TAG}/lazyssh_$(uname)_$(uname -m).tar.gz"
$ tar -xzf lazyssh.tar.gz
$ sudo mv lazyssh /usr/local/bin/
$ rm -f lazyssh.tar.gz
$ echo "alias lsh='lazyssh'" >> ~/.zshrc

########################################
# Claude Code
########################################
$ curl -fsSL https://claude.ai/install.sh | bash
$ echo "alias claude+='claude --dangerously-skip-permissions'" >> ~/.zshrc

########################################
# SMB GUI 마운트 (192.168.1.145/drive)
# GNOME Files 네트워크에 표시, 로그인 시 자동 마운트
# SMB 서버 다운 시 마운트만 실패, 부팅/로그인에는 영향 없음
########################################
$ sudo dnf install -y gvfs-smb

# 마운트 스크립트 (비밀번호 평문 포함 - 700 권한으로 잠금)
$ mkdir -p ~/.local/bin
$ cat > ~/.local/bin/mount-drive.sh << 'EOF'
#!/bin/bash
printf 'kkmaddress\nSAMBA\n<PASSWORD>\n' | gio mount "smb://192.168.1.145/drive"
EOF
$ chmod 700 ~/.local/bin/mount-drive.sh

# systemd user 서비스 등록 (GUI 로그인 후 자동 마운트)
$ mkdir -p ~/.config/systemd/user
$ cat > ~/.config/systemd/user/gvfs-drive.service << 'EOF'
[Unit]
Description=Mount SMB drive via gvfs
After=default.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=%h/.local/bin/mount-drive.sh
ExecStop=gio mount -u "smb://192.168.1.145/drive"

[Install]
WantedBy=default.target
EOF
$ systemctl --user daemon-reload
$ systemctl --user enable --now gvfs-drive.service
$ systemctl --user status gvfs-drive.service

########################################
# Timeshift
########################################
$ sudo dnf install -y timeshift
$ rpm -q timeshift
# sudo timeshift --create --comments "Initialize"
# sudo timeshift --list

########################################
# fzf
########################################
$ sudo dnf install -y fzf

########################################
# bat
########################################
$ sudo dnf install -y bat
$ echo "alias cat='bat'" >> ~/.zshrc

########################################
# ripgrep
########################################
$ sudo dnf install -y ripgrep
$ rg --version

########################################
# btop
########################################
$ sudo dnf install -y btop
$ btop --version

########################################
# VLC Media
########################################
$ sudo dnf install -y vlc.x86_64

########################################
# Spotify
########################################
$ flatpak install flathub com.spotify.Client

########################################
# git-delta
########################################
$ sudo dnf install -y git-delta
$ delta --version
$ git config --global interactive.diffFilter "delta --color-only"
$ git config --global core.pager delta
$ git config --global delta.navigate true
$ git config --global delta.line-numbers true
$ git config --global delta.side-by-side true
$ git config --global merge.conflictStyle zdiff3
$ git config --global diff.colorMoved default

########################################
# Apple Usbmux
########################################
$ sudo dnf install -y libimobiledevice libimobiledevice-utils usbmuxd ifuse
$ mkdir -p ~/apple/vlc
# Connect Apple Cable
$ idevice_id -l
$ ideviceinfo
$ idevicepair pair
$ idevicepair validate
$ ifuse --documents org.videolan.vlc-ios ~/apple/vlc
$ ls ~/apple/vlc
# Unmount
$ fusermount -u ~/apple/vlc

########################################
# 사용자 프로필 이미지
# profile.png 를 홈 경로에 두고 실행
########################################
$ sudo cp "$HOME/profile.png" /var/lib/AccountsService/icons/$USER
$ sudo chmod 644 /var/lib/AccountsService/icons/$USER
$ sudo tee /var/lib/AccountsService/users/$USER << EOF
[User]
Languages=ko_KR.UTF-8;
Session=
PasswordHint=
Icon=/var/lib/AccountsService/icons/$USER
SystemAccount=false
EOF
$ sudo systemctl restart accounts-daemon

########################################
# 배경화면
# background.jpg 를 홈 경로에 두고 실행
########################################
$ mkdir -p "$HOME/.local/share/backgrounds"
$ mv "$HOME/background.jpg" "$HOME/.local/share/backgrounds/background.jpg"
$ gsettings set org.gnome.desktop.background picture-uri      "file://$HOME/.local/share/backgrounds/background.jpg"
$ gsettings set org.gnome.desktop.background picture-uri-dark "file://$HOME/.local/share/backgrounds/background.jpg"
$ gsettings set org.gnome.desktop.background picture-options  "zoom"
```

## 검토 목록 (Utilization Review List)

우선순위: ↑ 우선 / - 보통 / ↓ 보류 가능

```text
# [진단/네트워크]
# - bind-utils: dig, nslookup. DNS 1차 진단 툴 (우선순위: ↑)
# - nmap + nmap-ncat: 포트 스캔, nc (우선순위: -)
# - mtr: traceroute + ping 결합. 경로 구간별 손실 추적 (우선순위: -)
# - tcpdump: 패킷 캡처 (우선순위: -)
# - iperf3: 대역폭 측정. SMB 등 망 성능 검증 (우선순위: ↓)
# - socat: 범용 소켓 릴레이. 포트 포워딩/디버깅 (우선순위: ↓)
#
# [Fedora]
# - snapper: CLI 스냅샷/롤백 수단 (우선순위: ↑)
# - dnf-automatic: 보안 업데이트 자동 적용 (우선순위: -)
#
# [Utils]
# - fd: find 대체제 (우선순위: -)
# - eza: ls 대체제 (우선순위: -)
# - zoxide: cd 대체. 디렉터리 점프 (우선순위: -)
# - git-delta: git diff 페이저 (우선순위: -)
# - lazygit: git tui (우선순위: -)
# - btop: 리소스 상세 진단 (우선순위: -)
# - direnv: 디렉터리별 환경변수 (우선순위: ↓)
# - tldr: man 요약 (우선순위: ↓)
# - DBeaver: db client (우선순위: -)
# - Bruno: postman 대체제 (우선순위: -)
# - httpie: cli api (우선순위: ↓)
# - flameshot: 주석 가능한 스크린샷 (우선순위: ↓)
# - Remmina: rdp/vnc/ssh tool (우선순위: -)
# - KeePassXC: 비밀번호 관리자 (우선순위: -)
# - VLC: Media Player (우선순위: ↓)
# - Meld: 시각적 3-way diff/merge (우선순위: ↓)
# - hadolint: Dockerfile 린터 [컨테이너 도메인] (우선순위: ↓)
# - stern: 다중 Pod 로그 동시 tail [컨테이너 도메인] (우선순위: ↓)
#
# [Gnome Extensions]
# - Clipboard Indicator: 클립보드 히스토리 (우선순위: -)
# - Tiling Assistant: 창 타일링 (우선순위: -)
# - GSConnect: KDE Connect의 GNOME (우선순위: ↓)
# - Removable Drive Menu: USB/마운트 빠른 접근 (우선순위: ↓)
# - Just Perfection: GNOME 셸 세부 요소 토글 (우선순위: ↓)
#
# [Terminal]
# - ghostty terminal: GNOME Terminal 대체 (우선순위: -)
```
