#!/bin/bash

set -e  # 遇到错误时退出

# 配置变量
export GH_PROXY='https://ghproxy.129262.xyz/'
export GITHUB_TOKEN="xxx"
export AUTOLOADER_DIR="/opt/autoloader"
export AUTOLOADER_REPO_OWNER="owner"
export AUTOLOADER_REPO_NAME="repo"
export AUTOLOADER_FILE_NAME="python.py"
export BRANCH_NAME="main"
export AUTOLOADER_FILE="$AUTOLOADER_DIR/$(basename $AUTOLOADER_FILE_NAME)"

# 自定义字体彩色，read 函数
warning() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; } # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
hint() { echo -e "\033[34m\033[01m$*\033[0m"; }   # 蓝色
reading() { read -rp "$(info "$1")" "$2"; }

# 清理可能存在的旧的 AUTOLOADER_DIR 目录
clean_old_directory() {
    sudo rm -rf "$AUTOLOADER_DIR"
}

# 创建目录
create_directory() {
    info "创建目录: $AUTOLOADER_DIR"
    sudo mkdir -p "$AUTOLOADER_DIR"
}

# 创建 autoloader.sh 脚本
create_autoloader_script() {
    AUTOLOADER_SCRIPT="$AUTOLOADER_DIR/autoloader.sh"
    info "创建脚本: $AUTOLOADER_SCRIPT"
    sudo tee "$AUTOLOADER_SCRIPT" > /dev/null <<EOL
#!/bin/bash
/usr/bin/python3 $AUTOLOADER_DIR/autoloader_v*.py*

#
#
# 44 10 * * 1-5 /usr/bin/sh /path/to/shell.sh >> /path/to/shell.log 2>&1
#
# ps aux | grep xxx
#
# 00 10 * * * /sbin/shutdown -r 18:00 (10点关机，18点重启）
#
# 每周一到周五9点到15点每分钟执行：
#
# */1 9-14 * * 1-5
#
#
# Linux
#     *    *    *    *    *
#     -    -    -    -    -
#     |    |    |    |    |
#     |    |    |    |    +----- day of week (0 - 7) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
#     |    |    |    +---------- month (1 - 12) OR jan,feb,mar,apr ...
#     |    |    +--------------- day of month (1 - 31)
#     |    +-------------------- hour (0 - 23)
#     +------------------------- minute (0 - 59)
EOL
    sudo chmod +x "$AUTOLOADER_SCRIPT"
}

# 创建 systemd 服务文件
create_systemd_service() {
    SERVICE_FILE="/etc/systemd/system/autoloader.service"
    info "创建 systemd 服务文件: $SERVICE_FILE"
    sudo tee "$SERVICE_FILE" > /dev/null <<EOL
[Unit]
Description=Autoloader service
Wants=network.target
After=network.target network.service

[Service]
Type=simple
WorkingDirectory=$AUTOLOADER_DIR
ExecStart=/usr/bin/bash $AUTOLOADER_DIR/autoloader.sh
Restart=on-failure
ExecStop=/usr/bin/kill -15 \$MAINPID
StandardOutput=null

[Install]
WantedBy=multi-user.target
EOL
}

# 下载 Python 文件
download_python_file() {
    info "下载文件: $(basename $AUTOLOADER_FILE_NAME)"
    #info "下载文件到: $(AUTOLOADER_FILE)"

    response=$(curl -s -w "%{http_code}" -o /dev/null \
                    "https://api.github.com/repos/$AUTOLOADER_REPO_OWNER/$AUTOLOADER_REPO_NAME")

    http_code="${response: -3}"

    if [ "$http_code" == "200" ]; then
        wget -q \
            "${GH_PROXY}https://raw.githubusercontent.com/$AUTOLOADER_REPO_OWNER/$AUTOLOADER_REPO_NAME/$BRANCH_NAME/$AUTOLOADER_FILE_NAME" \
            -O "$AUTOLOADER_FILE"
    else
        wget -q --header="Authorization: token $GITHUB_TOKEN" \
            "${GH_PROXY}https://raw.githubusercontent.com/$AUTOLOADER_REPO_OWNER/$AUTOLOADER_REPO_NAME/$BRANCH_NAME/$AUTOLOADER_FILE_NAME" \
            -O "$AUTOLOADER_FILE"
    fi
}

# 编译 Python 文件为 .pyc
compile_python_file() {
    rm -rf "$AUTOLOADER_DIR/__pycache__"
    /usr/bin/python3 -m py_compile "$AUTOLOADER_FILE"
}

# 移动 .pyc 文件到目标目录
move_pyc_file() {
    PYC_FILE=$(find "$AUTOLOADER_DIR/__pycache__" -name "$(basename "$AUTOLOADER_FILE" .py)*.pyc")
    mv "$PYC_FILE" "$AUTOLOADER_DIR/"
    info "编译后的文件已移到: $AUTOLOADER_DIR"
}

# 清理原始 .py 文件和 __pycache__ 目录
clean_up() {
    rm -f "$AUTOLOADER_FILE"
    rm -rf "$AUTOLOADER_DIR/__pycache__"
}

# 重新加载 systemd 配置
reload_systemd() {
    sudo systemctl daemon-reload
    
    hint "提示：为了启用 autoloader 服务并启动，请执行以下命令："
    info "sudo systemctl enable autoloader.service"
    info "sudo systemctl start autoloader.service"
    
    hint "查看服务状态，请执行："
    info "sudo systemctl status autoloader.service"
}

# 检测是否需要启用 Github CDN，如能直接连通，则不使用
check_cdn() {
    if [ -n "$GH_PROXY" ]; then
        if wget --server-response --quiet --output-document=/dev/null --no-check-certificate --tries=2 --timeout=3 "https://raw.githubusercontent.com/xlogice/public/main/README.md" >/dev/null 2>&1; then
            unset GH_PROXY
        fi
    fi
}

check_root() {
    if [ "$(id -u)" != 0 ]; then
        echo "必须以 root 权限运行脚本，可以输入 sudo -i"
        exit 1
    fi
}

main() {
    check_root
    check_cdn
    info "正在初始化 autoloader ..."
    clean_old_directory
    create_directory
    create_autoloader_script
    create_systemd_service
    download_python_file
    compile_python_file
    move_pyc_file
    clean_up
    reload_systemd
    info "初始化 autoloader 完成！！！"
}

main
