#!/bin/bash

select_container() {
    mapfile -t containers < <(docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}")
    local container_list=()
    for container in "${containers[@]}"; do
        IFS=$'\t' read -r id name status image <<< "$container"
        if [[ "$status" == "Up"* ]]; then
            status="\Z2Запущен\Zn"
        else
            status="\Z1Остановлен\Zn"
        fi
        container_list+=("$id" "$name ($status, $image)")
    done

    container_id_or_name=$(dialog --colors --menu "Выберите контейнер:" 0 0 0 "${container_list[@]}" 2>&1 >/dev/tty)
    clear
    echo "Выбран контейнер: $container_id_or_name"
}

select_image() {
    mapfile -t images < <(docker images --format "{{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}")
    local image_list=()
    for image in "${images[@]}"; do
        IFS=$'\t' read -r id repo tag size <<< "$image"
        image_list+=("$id" "$repo:$tag ($size)")
    done

    image_id_or_name=$(dialog --menu "Выберите образ:" 0 0 0 "${image_list[@]}" 2>&1 >/dev/tty)
    clear
    echo "Выбран образ: $image_id_or_name"
}

container_info() {
    docker inspect "$container_id_or_name" > /tmp/container_info.txt
    dialog --title "Информация о контейнере $container_id_or_name" --textbox /tmp/container_info.txt 0 0
    clear
}

image_info() {
    docker inspect "$image_id_or_name" > /tmp/image_info.txt
    dialog --title "Информация об образе $image_id_or_name" --textbox /tmp/image_info.txt 0 0
    clear
}

show_logs() {
    docker logs "$container_id_or_name" &> /tmp/container_logs.txt
    dialog --title "Логи контейнера $container_id_or_name" --textbox /tmp/container_logs.txt 0 0
    clear
}

show_tail_logs() {
    local lines=$(dialog --inputbox "Сколько последних строк логов показать?" 0 0 "100" 2>&1 >/dev/tty)
    clear
    if [[ "$lines" =~ ^[0-9]+$ ]]; then
        docker logs --tail "$lines" "$container_id_or_name" &> /tmp/container_logs_tail.txt
        dialog --title "Последние $lines строк логов контейнера $container_id_or_name" --textbox /tmp/container_logs_tail.txt 0 0
    else
        dialog --msgbox "Неверное количество строк. Введите число." 0 0
    fi
    clear
}

container_menu() {
    while true; do
        choice=$(dialog --colors --menu "Действия с контейнером $container_id_or_name:" 0 0 0 \
            1 "Остановить контейнер" \
            2 "Запустить контейнер" \
            3 "Перезапустить контейнер" \
            4 "Удалить контейнер" \
            5 "Просмотреть логи контейнера" \
            6 "Просмотреть последние строки логов" \
            7 "Войти в контейнер (bash/sh)" \
            8 "Проверить информацию о контейнере" \
            9 "Выбрать другой контейнер" \
            10 "Перейти к выбору образа" \
            11 "Выход" 2>&1 >/dev/tty)
        clear

        case $choice in
            1)
                docker stop "$container_id_or_name"
                dialog --msgbox "Контейнер $container_id_or_name остановлен." 0 0
                ;;
            2)
                docker start "$container_id_or_name"
                dialog --msgbox "Контейнер $container_id_or_name запущен." 0 0
                ;;
            3)
                docker restart "$container_id_or_name"
                dialog --msgbox "Контейнер $container_id_or_name перезапущен." 0 0
                ;;
            4)
                docker rm -f "$container_id_or_name"
                dialog --msgbox "Контейнер $container_id_or_name удален." 0 0
                break
                ;;
            5)
                show_logs
                ;;
            6)
                show_tail_logs
                ;;
            7)
                if docker exec "$container_id_or_name" which bash &> /dev/null; then
                    docker exec -it "$container_id_or_name" bash
                else
                    docker exec -it "$container_id_or_name" sh
                fi
                ;;
            8)
                container_info
                ;;
            9)
                break
                ;;
            10)
                image_menu
                ;;
            11)
                exit 0
                ;;
            *)
                dialog --msgbox "Неверный выбор. Попробуйте снова." 0 0
                ;;
        esac
    done
}

image_menu() {
    while true; do
        choice=$(dialog --menu "Действия с образом $image_id_or_name:" 0 0 0 \
            1 "Удалить образ" \
            2 "Проверить информацию об образе" \
            3 "Выбрать другой образ" \
            4 "Перейти к выбору контейнера" \
            5 "Выход" 2>&1 >/dev/tty)
        clear

        case $choice in
            1)
                docker rmi -f "$image_id_or_name"
                dialog --msgbox "Образ $image_id_or_name удален." 0 0
                break
                ;;
            2)
                image_info
                ;;
            3)
                break
                ;;
            4)
                break 2
                ;;
            5)
                exit 0
                ;;
            *)
                dialog --msgbox "Неверный выбор. Попробуйте снова." 0 0
                ;;
        esac
    done
}

while true; do
    choice=$(dialog --menu "Выберите, с чем работать:" 0 0 0 \
        1 "Контейнеры" \
        2 "Образы" \
        3 "Выход" 2>&1 >/dev/tty)
    clear

    case $choice in
        1)
            select_container
            container_menu
            ;;
        2)
            select_image
            image_menu
            ;;
        3)
            exit 0
            ;;
        *)
            dialog --msgbox "Неверный выбор. Попробуйте снова." 0 0
            ;;
    esac
done
