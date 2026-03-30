#!/bin/sh
set -e
# 使用 ${HOME} 作为统一根路径
PICOPATH="${HOME}/.picoclaw"
WORKSPACE_DIR="${PICOPATH}/workspace"

AGENT_ADD_CMD_DIR="/my_app/AGENT_add_cmd.md"

# 首次运行：任一缺失则 onboarding
if [ ! -d "${WORKSPACE_DIR}" ] || [ ! -f "${PICOPATH}/config.json" ]; then
    picoclaw onboard
    echo ""
    echo "First-run setup complete."
    echo "Edit ${PICOPATH}/config.json (add your API key, etc.) then restart the container."

    cat "${AGENT_ADD_CMD_DIR}" >> "${WORKSPACE_DIR}/AGENT.md"
    exit 0
fi

rm -rf "${WORKSPACE_DIR}/tmp"
mkdir "${WORKSPACE_DIR}/tmp"

chmod -R 644 /my_app
find /my_app -type f -name "*.sh" -exec chmod 755 {} +


#=======================================
SRC_CLAWMARK_DIR="/my_app/clawmark"
CLAWMARK_DIR="${WORKSPACE_DIR}/skills/clawmark"

# 复制 clawmark 若不存在）
if [ ! -d "${CLAWMARK_DIR}" ]; then
    cp -a "${SRC_CLAWMARK_DIR}" "${CLAWMARK_DIR}"

    chmod 755 "${CLAWMARK_DIR}\bin\*"
    chmod 755 "${CLAWMARK_DIR}\lib\*"
    ln -sf "${CLAWMARK_DIR}\bin\clawmark" \usr\local\bin\clawmark
fi
#=======================================

#=======================================
SRC_DISCORD_BOT_DIR="/my_app/discord-send"
DISCORD_BOT_DIR="${WORKSPACE_DIR}/skills/discord-send"
DISCORD_BOT_SCRIPTS_DIR="${DISCORD_BOT_DIR}/scripts"

# 复制 discord-send（若不存在）
if [ ! -d "${DISCORD_BOT_DIR}" ]; then
    cp -a "${SRC_DISCORD_BOT_DIR}" "${DISCORD_BOT_DIR}"
fi
#=======================================


#=======================================
CRON_DIR="${WORKSPACE_DIR}/skills/cron-task-skill"
SRC_CRON_DIR="/my_app/cron-task-skill"
CRON_SCRIPTS_DIR="${CRON_DIR}/scripts"
CRON_RUN_SCRIPT="cron_run.sh"
CRON_LOG="/tmp/cron_task.log"

# 复制 cron-task-skill（若不存在）
if [ ! -d "${CRON_DIR}" ]; then
    cp -a "${SRC_CRON_DIR}" "${CRON_DIR}"
fi

# 清除旧的 cron_task 条目并添加新的 cron 任务
# 先读取现有 crontab（吞掉错误），过滤掉含 cron_task 的行，然后添加新的行
{
  crontab -l 2>/dev/null | grep -v "${CRON_RUN_SCRIPT}" || true
  # 每分钟执行（使用绝对路径）
  echo "* * * * * cd ${CRON_SCRIPTS_DIR} && ./$(basename "${CRON_RUN_SCRIPT}") >> ${CRON_LOG} 2>&1"
} | crontab - || true

service cron start 
#=======================================


# 启动主进程（确保可执行在 PATH 中）
exec picoclaw-launcher -public -no-browser
