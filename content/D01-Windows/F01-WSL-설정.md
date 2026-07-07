# WSL 설정

WSL2 전역 설정, Zone.Identifier 비활성화, Windows interop 복구, DNS 초기화.

## WSL 전역 설정

```powershell
# C:\Users\<username>\.wslconfig
[wsl2]
memory=8GB
swap=2GB
processors=4
```

## Zone.Identifier 비활성화

```powershell
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Force
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "SaveZoneInformation" -Value 1 -PropertyType DWORD -Force
```

## Windows interop 복구

`explorer.exe .`, `code .`, `cmd.exe /c echo ok` 등 Windows `.exe` 실행이 안 될 때 수행한다.

```bash
##################################################
# WSLInterop 상태 확인
##################################################
$ cat /proc/sys/fs/binfmt_misc/WSLInterop 2>/dev/null || echo "WSLInterop missing"

##################################################
# WSLInterop missing 상태일 경우 복구 수행
##################################################
$ sudo mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null || true
$ echo ':WSLInterop:M::MZ::/init:PF' | sudo tee /proc/sys/fs/binfmt_misc/register

##################################################
# WSLInterop 정상 등록 여부 확인 및 테스트
##################################################
$ cat /proc/sys/fs/binfmt_misc/WSLInterop
$ cmd.exe /c echo ok
```

bash 스크립트로 등록해 두면 편하다.

```bash
$ mkdir -p ~/.local/bin
$ vi repair
#!/usr/bin/env bash

set -euo pipefail

readonly BINFMT_DIR="/proc/sys/fs/binfmt_misc"
readonly WSL_INTEROP_FILE="${BINFMT_DIR}/WSLInterop"
readonly REGISTER_FILE="${BINFMT_DIR}/register"
readonly WSL_INTEROP_RULE=":WSLInterop:M::MZ::/init:PF"

########################################
# Output helpers
########################################

section() {
  echo
  echo "##################################################"
  echo "# $1"
  echo "##################################################"
}

info() {
  echo "[INFO] $1"
}

ok() {
  echo "[OK] $1"
}

warn() {
  echo "[WARN] $1"
}

error() {
  echo "[ERROR] $1" >&2
}

########################################
# WSLInterop helpers
########################################

show_wslinterop_status() {
  cat "${WSL_INTEROP_FILE}" 2>/dev/null
}

ensure_binfmt_misc_mounted() {
  info "Mount binfmt_misc"

  sudo mount -t binfmt_misc binfmt_misc "${BINFMT_DIR}" 2>/dev/null || true

  if [ ! -e "${REGISTER_FILE}" ]; then
    error "${REGISTER_FILE} not found"
    error "binfmt_misc mount failed or this environment is not normal WSL"
    exit 1
  fi
}

register_wslinterop() {
  info "Register WSLInterop"

  printf '%s\n' "${WSL_INTEROP_RULE}" | sudo tee "${REGISTER_FILE}" >/dev/null
}

repair_wslinterop() {
  section "WSLInterop missing 상태이므로 복구 수행"

  ensure_binfmt_misc_mounted
  register_wslinterop
}

verify_wslinterop() {
  section "WSLInterop 정상 등록 여부 확인"

  if show_wslinterop_status; then
    ok "WSLInterop registered"
  else
    error "WSLInterop registration failed"
    exit 1
  fi
}

test_windows_interop() {
  section "cmd.exe 실행 테스트"

  if cmd.exe /c echo ok; then
    ok "Windows interop test succeeded"
  else
    error "Windows interop test failed"
    exit 1
  fi
}

########################################
# Main
########################################

main() {
  section "WSLInterop 상태 확인"

  if show_wslinterop_status; then
    echo
    ok "WSLInterop already registered"
  else
    warn "WSLInterop missing"
    repair_wslinterop
  fi

  verify_wslinterop
  test_windows_interop
}

main "$@"

$ chmod +x ~/.local/bin/repair
```

## DNS 문제 발생 시 초기화

```bash
$ sudo rm -f /etc/resolv.conf
$ echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```
