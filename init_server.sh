#!/usr/bin/env bash

# 스크립트 내에서 오류 발생 시 즉시 종료
# -E : 함수나 서브셸, 파이프라인 등에서도 ERR 트랩이 유효
# -e : 명령 실패 시 즉시 종료
# -u : 설정되지 않은 변수 사용 시 에러
# -o pipefail : 파이프라인 내 명령어 하나라도 실패 시 전체 오류
set -Eeuo pipefail

# 에러 발생 시 어느 라인, 어떤 명령에서 실패했는지 로그 출력
trap 'echo "[ERROR] Script failed at line $LINENO: $BASH_COMMAND (exit code: $?)" >&2' ERR

echo "==== 0. 서버 시간 동기화 ===="
sudo timedatectl set-timezone Asia/Seoul

echo "===== 1. APT Update ====="
sudo apt update -y

echo "===== 2. OpenJDK-17 (Headless) 설치 ====="
sudo apt install -y openjdk-17-jdk-headless

echo "===== 3. Python 3.10 Minimal 설치 ====="
sudo apt install -y python3.10-minimal

echo "===== 4. Docker 구버전 제거 ====="
# 4-1. Docker 비공식 패키지 제거
PACKAGES="docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc"
for pkg in $PACKAGES; do
  echo "Removing $pkg..."
  # 실패해도 스크립트를 중단하지 않고 넘어가기 위해 || true 사용
  sudo apt-get remove -y "$pkg" || true
done

# 4-2. Docker Engine 제거
echo "Purging existing Docker Engine packages..."
sudo apt-get purge -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  docker-ce-rootless-extras || true

# 4-3. 모든 이미지, 컨테이너 및 볼륨 삭제
echo "Removing /var/lib/docker and /var/lib/containerd..."
sudo rm -rf /var/lib/docker /var/lib/containerd || true

# 4-4. 소스 목록 및 키링 제거
echo "Removing Docker source list and key..."
sudo rm /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc || true

echo "===== 5. Docker apt 저장소 설정 ====="
# 5-1. Add Docker's official GPG key
echo "Installing prerequisites (ca-certificates, curl)..."
sudo apt-get install -y ca-certificates curl

echo "Creating /etc/apt/keyrings directory..."
sudo install -m 0755 -d /etc/apt/keyrings || true

echo "Adding Docker's GPG key..."
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 5-2. Add the repository to Apt sources
echo "Adding Docker repository to sources.list.d..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

echo "===== 6. Docker 특정 버전 설치 ====="
VERSION_STRING=5:28.0.0-1~ubuntu.22.04~jammy
sudo apt-get install -y \
  docker-ce=$VERSION_STRING \
  docker-ce-cli=$VERSION_STRING \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

echo "===== 7. Docker 그룹 및 권한 설정 ====="
# 그룹이 이미 존재해도 오류를 무시하고 넘어가기 위해 || true
sudo groupadd docker || true

# 현재 사용자($USER)를 docker 그룹에 추가
sudo usermod -aG docker "$USER"

echo "===== Docker 설치 및 설정 완료 ====="
echo "현재 세션을 종료했다가 재 접속한 후 사용해 주세요."
