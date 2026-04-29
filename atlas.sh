# ─────────────────────────────────────────────────────────────────────────────────────────── \\  ▼  // ─────────────────────────────────────────────────────────────────────────────────────────── #
                                                                                               atlas()
{

    (( executing )) || {
        local executing=1 cmds=$* bold="\e[1m" dim="\e[2m" red="\e[31m" r="\e[m" hc="\e[?25l" sc="\e[?25h" origin="\e[7G"
        local children flatpaks i ii indent intent last lastc opt orphans pfx pkg pulse root log
        local -A delta lineage modified null

        echo
        atlas .resolve
    }

#  ┌── control ───────────────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .resolve ]] && {
        cmds=${cmds//[ -]}
        [[ $cmds =~ [^qinrofsudc] ]] && atlas .syntax
        [[ ${cmds//[qin]} ]] || cmds+=irofsudc

        atlas .sig

        [[ $cmds =~ n ]] || atlas .scan $cmds

        for i in $(fold -w1 <<< $cmds)
        do atlas .$i
        done

        atlas .sig 0
    }

    [[ $1 = .syntax ]] && {
        echo -e "$bold ▼ atlas commands$r"
        echo
        echo "  ┌── modifiers ──────────────┐"
        echo "  │ q  ·  quiet output        │"
        echo "  │ i  ·  implicit mode       │"
        echo "  │ n  ·  no caching          │"
        echo "  └───────────────────────────┘"
        echo
        echo "  ┌── operations ─────────────┐"
        echo "  │ r  ·  view root           │"
        echo "  │ o  ·  view orphans        │"
        echo "  │ f  ·  view flatpaks       │"
        echo "  │ s  ·  temporary save      │"
        echo "  │ u  ·  upgrade system      │"
        echo "  │ d  ·  view difference     │"
        echo "  │ c  ·  cleanup orphans     │"
        echo "  └───────────────────────────┘"

        kill -2 $$
    }

    [[ $1 = .sig ]] && {
        [[ $2 ]] && {
            trap - 2 15
            echo -en "$sc"
            stty echo </dev/tty
        return;}

        trap '
            atlas .read 0
            atlas .pulse 0
            atlas .sig 0
            echo -e "\r$red> atlas: terminated ⚠$r\e[K"
            kill -2 $$
        ' 2 15
        echo -en "$hc"
        stty -echo
    }

#  └──────────────────────────────────────────────────────────────────────────────────────────────┘

#  ┌── operations ────────────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .r ]] && {
        atlas .scan r

        echo -e "${bold}root (${#root[@]})$r"
        local -n arr=root
        local -n assoca=lineage
        atlas .render
    }

    [[ $1 = .o ]] && {
        atlas .scan o

        [[ $orphans ]] && {
            echo -e "$bold${red}orphans (${#orphans[@]})$r"
            local -n arr=orphans
            local -n assoca=null
            atlas .render $red
        return;}

        [[ $cmds =~ i ]] || echo -e "${dim}orphans: nil$r\n"
    }

    [[ $1 = .f ]] && {
        atlas .scan f

        [[ $flatpaks ]] && {
            echo -e "${bold}flatpaks (${#flatpaks[@]})$r"
            local -n arr=flatpaks
            local -n assoca=null
            atlas .render
        return;}

        [[ $cmds =~ i ]] || echo -e "${dim}flatpaks: nil$r\n"
    }

    [[ $1 = .s ]] && {
        atlas .scan a

        declare -gA save

        save[root]=$(printf "%s\n" "${root[@]}")
        save[orphans]=$(printf "%s\n" "${orphans[@]}")
        save[flatpaks]=$(printf "%s\n" "${flatpaks[@]}")

        [[ $cmds =~ i ]] || echo -e "${dim}saved$r\n"
    }

    [[ $1 = .u ]] && {
        [[ $cmds =~ i ]] && {
            [[ $(tac /var/log/pacman.log | grep -m1 upgrade) > [$(date -d -3days +%F) ]] 2>/dev/null && return
            echo -en "scan for updates? (y/${bold}n$r) "
            atlas .read
        :;} || intent=y

        [[ ${intent,,} = y ]] && {

            [[ $(command -v yay) ]] && {
                yay
            :;} || {
                [[ $(command -v paru) ]] && {
                    paru
                :;} || sudo pacman -Syu
            }

            [[ $(command -v flatpak) ]] && {
                echo
                flatpak update
                flatpak remove --unused
            }
        }

        atlas .read 0
        echo
    }

    [[ $1 = .d ]] && {
        [[ ${save[@]} ]] || {
            echo -e "${dim}no save found$r\n"
        return;}

        atlas .scan a

        for i in root orphans flatpaks
        do
            local -n arr=$i

            delta[${i}0]=$(grep -vxf <(printf "%s\n" "${arr[@]}") <(echo "${save[$i]}"))
            delta[${i}1]=$(grep -vxf <(echo "${save[$i]}") <(printf "%s\n" "${arr[@]}"))

            [[ ${delta[${i}0]}${delta[${i}1]} ]] && {
                echo -e "${bold}$i delta$r"
                [[ ${delta[${i}0]} ]] && echo -e "$red${delta[${i}0]}$r"
                [[ ${delta[${i}1]} ]] && echo -e "${delta[${i}1]}"
                echo
            }
        done

        [[ $cmds =~ i || ${delta[@]} =~ [^\ ] ]] || echo -e "${dim}delta: nil$r\n"
    }

    [[ $1 = .c ]] && {
        atlas .scan o

        [[ $orphans ]] && {
            [[ $cmds =~ i ]] && {
                echo -en "remove orphans? (y/${bold}n$r) "
                atlas .read
            :;} || intent=y

            [[ ${intent,,} = y ]] && sudo pacman -Rns ${orphans[@]}

            atlas .read 0
            echo
        return;}

        [[ $cmds =~ i ]] || echo -e "${dim}no orphans to remove$r\n"
    }

#  └──────────────────────────────────────────────────────────────────────────────────────────────┘

#  ┌── internal ──────────────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .scan ]] && {
        {
            modified[p1]=$(stat -c %Y /var/log/pacman.log)
            modified[f1]=$(stat -c %Y /var/lib/flatpak)
        } 2>/dev/null

        [[ ${modified[p0]} && ${modified[p0]} = ${modified[p1]} ]] || {
            log=${log//[ro]}
            modified[p0]=${modified[p1]}
        }

        [[ ${modified[f0]} && ${modified[f0]} = ${modified[f1]} ]] || {
            log=${log//f}
            modified[f0]=${modified[f1]}
        }

        [[ $2 =~ a ]] && set $1 ${2}qrof
        [[ $2 =~ c ]] && set $1 ${2}o
        [[ $cmds =~ n ]] || set $1 ${2//[$log]}

        atlas .pulse

        {
            [[ $2 =~ [ro] ]] && {
                echo -en "$origin${dim}atlas: scanning orphans…$r\e[K"
                orphans=( $(pacman -Qqtd) )
                log+=o
            }

            [[ $2 =~ r ]] && {
                echo -en "$origin${dim}atlas: scanning root…$r\e[K"
                root=( $(grep -vxf <(printf "%s\n" "${orphans[@]}") <(pacman -Qqtt)) )
                [[ $2 =~ q || $cmds =~ q ]] || atlas .extract
                log+=r
            }

            [[ $2 =~ f ]] && {
                echo -en "$origin${dim}atlas: scanning flatpaks…$r\e[K"
                mapfile -t flatpaks < <(flatpak list --app --columns=name)
                log+=f
            }
        } 2>/dev/null

        atlas .pulse 0
    }

    [[ $1 = .render ]] && {
        for i in ${!arr[@]}
        do
            pkg=${arr[i]}

            last=$(( i == ${#arr[@]} - 1 ))
            [[ $cmds =~ q ]] || {
                (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
            }

            echo -e "$2$pfx$pkg$r"

            children=( ${assoca[$pkg]} )

            for ii in ${!children[@]}
            do
                pkg=${children[ii]}

                lastc=$(( ii == ${#children[@]} - 1 ))
                (( last )) && indent="   " || indent="│  "
                (( lastc )) && pfx="└─ " || pfx="├─ "

                echo -e "$2$indent$dim$pfx$pkg$r"
            done
        done

        echo
    }

    [[ $1 = .read ]] && {
        [[ $2 ]] && {
            stty -echo
            echo -en "$hc"
        return;}

        while read -t 0 intent
        do read intent
        done

        echo -en "$sc"
        stty echo
        read intent
    }

    [[ $1 = .pulse ]] && {
        {
            [[ $2 ]] && {
                kill $pulse
                wait $pulse
                echo -en "\r\e[K"
            return;}

            while :
            do
                for c in '/' '—' '\' '|'
                do
                    echo -en "\r$bold( $c )$r"
                    sleep 0.05
                done
            done &pulse=$!
        } 2>/dev/null
    }

    [[ $1 = .extract ]] && {
        lineage=()

        while read pkg opt
        do [[ " ${root[@]} " =~ " $opt " ]] && lineage[$pkg]+="$opt "
        done < <(LC_ALL=C pacman -Qi ${root[@]} | awk '
            proceed {
                if (/^ /) {
                    gsub(/^ +|:.*/, "")
                    print pkg, $0
                    next
                }

                proceed = 0
                next
            }

            /^Name/ {
                pkg = $NF
                next
            }

            /^Optional Deps/ {
                gsub(/^Optional Deps *: *|:.*/, "")
                print pkg, $0
                proceed = 1
            }
        ')
    }

#  └──────────────────────────────────────────────────────────────────────────────────────────────┘

}

# ───────────────────────────────────────────────────────────────────────────────────────── << atlas() >> ───────────────────────────────────────────────────────────────────────────────────────── #
