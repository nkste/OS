#!/bin/bash

# Параметры ограничений
CPU_LIMIT=50          # Ограничение CPU в процентах
MEMORY_LIMIT="100M"   # Ограничение памяти
SWAP_LIMIT="50M"      # Ограничение swap

# Создание cgroup
CGROUP_NAME="my_cgroup"
sudo cgcreate -g cpu,memory:/$CGROUP_NAME

# Установка ограничений
sudo cgset -r cpu.cfs_quota_us=$(($CPU_LIMIT * 10000)) /$CGROUP_NAME
sudo cgset -r memory.limit_in_bytes=$MEMORY_LIMIT /$CGROUP_NAME
sudo cgset -r memory.memsw.limit_in_bytes=$(($(echo $MEMORY_LIMIT | sed 's/[^0-9]*//g') + $(echo $SWAP_LIMIT | sed 's/[^0-9]*//g')))M /$CGROUP_NAME

# Запуск stress в cgroup
echo "Запуск stress с ограничениями: CPU=$CPU_LIMIT%, MEMORY=$MEMORY_LIMIT, SWAP=$SWAP_LIMIT"
sudo cgexec -g cpu,memory:/$CGROUP_NAME stress --vm-bytes $(($(echo $MEMORY_LIMIT | sed 's/[^0-9]*//g') * 1024 * 1024)) --vm-keep -m 1 &

# Мониторинг процесса
STRESS_PID=$!
echo "Stress PID: $STRESS_PID"
echo "Мониторинг использования памяти и swap..."
while ps -p $STRESS_PID > /dev/null; do
    echo "Memory usage: $(ps -o rss= -p $STRESS_PID) KB"
    echo "Swap usage: $(grep VmSwap /proc/$STRESS_PID/status 2>/dev/null | awk '{print $2}') KB"
    sleep 1
done

echo "Процесс stress завершен или был OOM killed."

# Удаление cgroup
sudo cgdelete cpu,memory:/$CGROUP_NAME
