#!/bin/bash
# Скрипт для сборки и загрузки образа JupyterHub в Kubernetes кластер

set -e

IMAGE_NAME="jupyterhub-spark"
IMAGE_TAG="latest"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
TAR_FILE="${IMAGE_NAME}.tar"

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Сборка образа JupyterHub+Spark ===${NC}"
cd "$(dirname "$0")/.."

# Сборка образа
echo -e "${YELLOW}Сборка Docker образа...${NC}"
docker build -t "${FULL_IMAGE}" -f jupyterhub/Dockerfile jupyterhub/

if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка при сборке образа${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Образ собран успешно${NC}"

# Определение runtime кластера
echo -e "${YELLOW}Определение runtime Kubernetes кластера...${NC}"

if kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}' | grep -q containerd; then
    RUNTIME="containerd"
elif kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}' | grep -q cri-o; then
    RUNTIME="cri-o"
elif kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}' | grep -q docker; then
    RUNTIME="docker"
else
    echo -e "${YELLOW}Не удалось определить runtime, используем containerd по умолчанию${NC}"
    RUNTIME="containerd"
fi

echo -e "${GREEN}Обнаружен runtime: ${RUNTIME}${NC}"

# Сохранение образа в tar
echo -e "${YELLOW}Сохранение образа в tar...${NC}"
docker save "${FULL_IMAGE}" -o "${TAR_FILE}"

if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка при сохранении образа${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Образ сохранен в ${TAR_FILE}${NC}"

# Загрузка образа в кластер
echo -e "${YELLOW}Загрузка образа в кластер (${RUNTIME})...${NC}"

case $RUNTIME in
    containerd)
        echo "Используется containerd..."
        sudo ctr -n k8s.io images import "${TAR_FILE}"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Образ загружен в containerd${NC}"
            sudo ctr -n k8s.io images list | grep "${IMAGE_NAME}"
        else
            echo -e "${RED}Ошибка при загрузке образа в containerd${NC}"
            exit 1
        fi
        ;;
    cri-o)
        echo "Используется CRI-O..."
        sudo podman load -i "${TAR_FILE}"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Образ загружен в CRI-O${NC}"
        else
            echo -e "${RED}Ошибка при загрузке образа в CRI-O${NC}"
            exit 1
        fi
        ;;
    docker)
        echo "Используется Docker..."
        docker load < "${TAR_FILE}"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Образ загружен в Docker${NC}"
            docker images | grep "${IMAGE_NAME}"
        else
            echo -e "${RED}Ошибка при загрузке образа в Docker${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}Неизвестный runtime: ${RUNTIME}${NC}"
        exit 1
        ;;
esac

# Очистка временного файла
read -p "Удалить временный файл ${TAR_FILE}? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "${TAR_FILE}"
    echo -e "${GREEN}✓ Временный файл удален${NC}"
fi

echo -e "${GREEN}=== Готово! ===${NC}"
echo -e "Образ ${FULL_IMAGE} готов к использованию в кластере."
echo -e "Примените манифесты: kubectl apply -f local-k8s/"

