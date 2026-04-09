sysview() {

    # —————————————————————————————————————————————————————————————————————————————————————————— scoping

    local arg mode quiet_flag invalid_flag bold dim red reset hide_cur show_cur loading_pid Qqtd Qqtt pkg system dep i is_last pfx j children child child_is_last indent cpfx flatpak_app_names app answer

    # —————————————————————————————————————————————————————————————————————————————————————————— setup

    mode= quiet_flag= invalid_flag=
    
    for arg
    do
        case $arg in
            s|f|o|h) mode=1 ;;
            q) quiet_flag=1 ;;
            *) invalid_flag=1 ;;
        esac
    done

    bold="\e[1m" dim="\e[2m" red="\e[31m" reset="\e[m" hide_cur="\e[?25l" show_cur="\e[?25h"

    # —————————————————————————————————————————————————————————————————————————————————————————— loading
    
    start_loading() {
        {
            while true
            do
                for c in "( / )" "( — )" "( \ )" "( | )"
                do
                    echo -en "\r${bold}${c}${reset}"
                    sleep 0.02
                done
            done &
        } 2>/dev/null

        echo -en $hide_cur
        loading_pid=$!
    }

    stop_loading() {
        kill $loading_pid
        wait $loading_pid 2>/dev/null
        echo -en "\r     \r$show_cur"
    }

    # —————————————————————————————————————————————————————————————————————————————————————————— system
    
    system_f() {
        start_loading

        mapfile -t Qqtd < <(pacman -Qqtd)
        mapfile -t Qqtt < <(pacman -Qqtt)

        local -A orphans_set system_set sys_pkgs_info
        
        for pkg in ${Qqtd[@]}
        do orphans_set[$pkg]=1
        done

        system=()
        for pkg in ${Qqtt[@]}
        do (( orphans_set[$pkg] )) || system+=($pkg)
        done
        
        (( quiet_flag )) || {
            for pkg in ${system[@]}
            do system_set[$pkg]=1
            done

            while read -r pkg dep
            do (( system_set[$dep] )) && sys_pkgs_info[$pkg]+=$dep\ 
            done < <(LC_ALL=C pacman -Qi ${system[@]} | awk '
                /^Name/ {
                    pkg = $NF
                    next
                }
                /^Optional Deps/ {
                    gsub(/^Optional Deps *: *|:.*/, "")
                    print pkg, $0
                    found = 1
                    next
                }
                found && /^ / {
                    gsub(/^ +|:.*/, "")
                    print pkg, $0
                    next
                }
                {
                    found = 0
                }
            ')
        }

        stop_loading

        echo -e "${bold}system (${#system[@]})${reset}"
        
        for i in ${!system[@]}
        do
            pkg=${system[$i]}
            
            (( i == ${#system[@]} - 1 )) && is_last=1 || is_last=

            (( quiet_flag )) && pfx= || {
                (( is_last )) && pfx=$'│\n└─ ' || pfx=$'│\n├─ '
            }
            
            echo -e "${pfx}${pkg}"

            read -a children <<< ${sys_pkgs_info[$pkg]}

            for j in ${!children[@]}
            do
                child=${children[$j]}
                    
                (( j == ${#children[@]} - 1 )) && child_is_last=1 || child_is_last=

                (( is_last )) && indent="   " || indent="│  "
                (( child_is_last )) && cpfx="└─ " || cpfx="├─ "
                    
                echo -e "${indent}${dim}${cpfx}${child}${reset}"
            done
        done
        
        echo
    }

    # —————————————————————————————————————————————————————————————————————————————————————————— flatpak
    
    flatpak_f() {
        command -v flatpak &>/dev/null || return

        start_loading
        
        (( quiet_flag )) || flatpak remove --unused -y &>/dev/null

        mapfile -t flatpak_app_names < <(flatpak list --app --columns=name)
        
        stop_loading

        (( ${#flatpak_app_names[@]} )) || return

        echo -e "${bold}flatpak (${#flatpak_app_names[@]})${reset}"
        
        for i in ${!flatpak_app_names[@]}
        do
            app=${flatpak_app_names[$i]}
        
            (( i == ${#flatpak_app_names[@]} - 1 )) && is_last=1 || is_last=

            (( quiet_flag )) && pfx= || {
                (( is_last )) && pfx=$'│\n└─ ' || pfx=$'│\n├─ '
            }
            
            echo -e "${pfx}${app}"
        done
        
        echo
    }

    # —————————————————————————————————————————————————————————————————————————————————————————— orphans
    
    orphans_f() {
        start_loading
        
        mapfile -t Qqtd < <(pacman -Qqtd)
        
        stop_loading

        (( ${#Qqtd[@]} )) || return

        echo -e "${bold}${red}orphans (${#Qqtd[@]})${reset}"
        
        for i in ${!Qqtd[@]}
        do
            pkg=${Qqtd[$i]}
        
            (( i == ${#Qqtd[@]} - 1 )) && is_last=1 || is_last=

            (( quiet_flag )) && pfx= || {
                (( is_last )) && pfx=$'│\n└─ ' || pfx=$'│\n├─ '
            }
            
            echo -e "${red}${pfx}${pkg}${reset}"
        done

        (( quiet_flag )) || {
            echo -en "\nuninstall orphans? (y/${bold}n${reset}) "
            read -r answer
            [[ ${answer,,} = y ]] && sudo pacman -Rns ${Qqtd[@]}
        }
        
        echo
    }

    # —————————————————————————————————————————————————————————————————————————————————————————— help
    
    help_f() {
        echo "usage: sysview (s) (f) (o) (q) (h)"
        echo "  s    show system packages"
        echo "  f    show flatpak apps"
        echo "  o    show orphan packages"
        echo "  q    quiet mode"
        echo "  h    show this message"
        echo
    }

    # —————————————————————————————————————————————————————————————————————————————————————————— execution

    echo

    (( invalid_flag )) && {
        echo "invalid flag"
        help_f
        return
    }
    
    (( mode )) || {
        system_f
        flatpak_f
        orphans_f
        return
    }

    for arg
    do
        case $arg in
            s) system_f ;;
            f) flatpak_f ;;
            o) orphans_f ;;
            h) help_f ;;
        esac
    done
    
    # —————————————————————————————————————————————————————————————————————————————————————————— clean up
    
    unset start_loading stop_loading system_f flatpak_f orphans_f help_f

}
