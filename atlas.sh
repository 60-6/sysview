# ─────────────────────────────────────────────────────────────────────────────────────────── \\  ▼  // ─────────────────────────────────────────────────────────────────────────────────────────── #
                                                                                               atlas()
{

#  ┌──────────── layer 0 ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐

    (( executing )) || {
        local executing=1 ops=$* bold="\e[1m" dim="\e[2m" red="\e[31m" r="\e[m" hc="\e[?25l" sc="\e[?25h" origin="\e[7G"
        local children core flatpaks i ii indent intent last lastc opt orphans pfx pkg pulse log sig
        local -A delta lineage null

        echo
        atlas .resolve
    }

#  ┌──────────── layer 1 ───────────────────────────────────────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .resolve ]] && {
        ops=${ops//[ -]}
        [[ $ops =~ [^qncofsudr] ]] && atlas .clarify
        [[ ${ops//[qn]} ]] || ops+=cofsudr

        atlas .sig 1

        [[ $ops =~ n ]] || atlas .scan $ops

        for i in $(fold -w1 <<< $ops)
        do
            [[ $i = c ]] && atlas .core
            [[ $i = o ]] && atlas .orphans
            [[ $i = f ]] && atlas .flatpaks
            [[ $i = s ]] && atlas .save
            [[ $i = u ]] && atlas .upgrade
            [[ $i = d ]] && atlas .delta
            [[ $i = r ]] && atlas .remove
        done

        atlas .sig
    }

#  ┌──────────── layer 2 ───────────────────────────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .clarify ]] && {
        echo "  q  ➜  quiet mode"
        echo "  n  ➜  no cache"
        echo "  c  ➜  view core packages"
        echo "  o  ➜  view orphans"
        echo "  f  ➜  view flatpak apps"
        echo "  s  ➜  save state"
        echo "  u  ➜  upgrade system"
        echo "  d  ➜  view difference"
        echo "  r  ➜  remove orphans"

        kill -2 $$
    }

    [[ $1 = .sig ]] && {
        (( $2 )) && {
            echo -en "$hc"
            stty -echo

            sig=$(trap -p 2)
            trap '
                atlas .read
                atlas .pulse
                atlas .sig
                echo -e "$red\ratlas: terminated$r\e[K"
                kill -2 $$
            ' 2
        return;}

        eval "${sig:-trap - 2}"
        echo -en "$sc"
        stty echo </dev/tty
    }

    [[ $1 = .core ]] && {
        atlas .scan c

        echo -e "${bold}core (${#core[@]})$r"
        local -n arr=core
        local -n assoca=lineage
        atlas .render
    }

    [[ $1 = .orphans ]] && {
        atlas .scan o

        [[ $orphans ]] && {
            echo -e "$bold${red}orphans (${#orphans[@]})$r"
            local -n arr=orphans
            local -n assoca=null
            atlas .render $red
        return;}

        [[ $ops =~ [^o] ]] || echo -e "${dim}nil$r\n"
    }

    [[ $1 = .flatpaks ]] && {
        atlas .scan f

        [[ $flatpaks ]] && {
            echo -e "${bold}flatpaks (${#flatpaks[@]})$r"
            local -n arr=flatpaks
            local -n assoca=null
            atlas .render
        return;}

        [[ $ops =~ [^f] ]] || echo -e "${dim}nil$r\n"
    }

    [[ $1 = .save ]] && {
        atlas .scan a

        declare -gA save

        save[core]=$(printf "%s\n" "${core[@]}")
        save[orphans]=$(printf "%s\n" "${orphans[@]}")
        save[flatpaks]=$(printf "%s\n" "${flatpaks[@]}")

        [[ $ops =~ [^s] ]] || echo -e "${dim}saved$r\n"
    }

    [[ $1 = .upgrade ]] && {
        echo -en "scan for updates? (y/${bold}n$r) "
        atlas .read 1

        [[ ${intent,,} = y ]] && {
            {
                flatpak update
                flatpak remove --unused
            } 2>/dev/null

            [[ $(command -v yay) ]] && {
                yay
            :;} || {
                [[ $(command -v paru) ]] && {
                    paru
                :;} || sudo pacman -Syu
            }

            log=
        }

        atlas .read
    }

    [[ $1 = .delta ]] && {
        atlas .scan a

        [[ ${save[@]} ]] || {
            echo -e "${dim}no save found$r\n"
        return;}

        delta[core0]=$(grep -vxf <(printf "%s\n" "${core[@]}") <(echo "${save[core]}"))
        delta[core1]=$(grep -vxf <(echo "${save[core]}") <(printf "%s\n" "${core[@]}"))

        delta[orphans0]=$(grep -vxf <(printf "%s\n" "${orphans[@]}") <(echo "${save[orphans]}"))
        delta[orphans1]=$(grep -vxf <(echo "${save[orphans]}") <(printf "%s\n" "${orphans[@]}"))

        delta[flatpaks0]=$(grep -vxf <(printf "%s\n" "${flatpaks[@]}") <(echo "${save[flatpaks]}"))
        delta[flatpaks1]=$(grep -vxf <(echo "${save[flatpaks]}") <(printf "%s\n" "${flatpaks[@]}"))

        [[ ${delta[core0]}${delta[core1]} ]] && {
            echo -e "${bold}core delta$r"
            [[ ${delta[core0]} ]] && echo -e "$red${delta[core0]}$r"
            [[ ${delta[core1]} ]] && echo -e "${delta[core1]}"
            echo
        }

        [[ ${delta[orphans0]}${delta[orphans1]} ]] && {
            echo -e "${bold}orphans delta$r"
            [[ ${delta[orphans0]} ]] && echo -e "$red${delta[orphans0]}$r"
            [[ ${delta[orphans1]} ]] && echo -e "${delta[orphans1]}"
            echo
        }

        [[ ${delta[flatpaks0]}${delta[flatpaks1]} ]] && {
            echo -e "${bold}flatpaks delta$r"
            [[ ${delta[flatpaks0]} ]] && echo -e "$red${delta[flatpaks0]}$r"
            [[ ${delta[flatpaks1]} ]] && echo -e "${delta[flatpaks1]}"
            echo
        }

        [[ $(printf "%s" "${delta[@]}") || $ops =~ [^sd] ]] || echo -e "${dim}nil$r\n"
    }

    [[ $1 = .remove ]] && {
        atlas .scan o

        [[ $orphans ]] && {
            echo -en "remove orphans? (y/${bold}n$r) "
            atlas .read 1

            [[ ${intent,,} = y ]] && {
                sudo pacman -Rns ${orphans[@]}
                log=${log//o}
            }

            atlas .read
        return;}

        [[ $ops =~ [^r] ]] || echo -e "${dim}nil$r\n"
    }

#  ┌──────────── layer 3 ───────────────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .scan ]] && {
        [[ $2 =~ a ]] && set -- $1 ${2}cofq
        [[ $2 =~ r ]] && set -- $1 ${2}o
        [[ $ops =~ q ]] && set -- $1 ${2}q
        [[ $ops =~ n ]] || set -- $1 ${2//[$log]}

        atlas .pulse 1

        {
            [[ $2 =~ [co] ]] && {
                echo -en "$origin${dim}atlas: scanning orphans$r\e[K"

                orphans=( $(pacman -Qqtd) )
                log+=o
            }

            [[ $2 =~ c ]] && {
                echo -en "$origin${dim}atlas: scanning core$r\e[K"

                core=( $(grep -vxf <(printf "%s\n" "${orphans[@]}") <(pacman -Qqtt)) )
                [[ $2 =~ q ]] || atlas .extract
                log+=c
            }

            [[ $2 =~ f ]] && {
                echo -en "$origin${dim}atlas: scanning flatpaks$r\e[K"

                mapfile -t flatpaks < <(flatpak list --app --columns=name)
                log+=f
            }
        } 2>/dev/null

        atlas .pulse
    }

    [[ $1 = .render ]] && {
        for i in ${!arr[@]}
        do
            pkg=${arr[i]}

            last=$(( i == ${#arr[@]} - 1 ))
            [[ $ops =~ q ]] || {
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
        (( $2 )) && {
            while read -t 0 intent
            do read intent
            done

            echo -en "$sc"
            stty echo
            read intent
        return;}

        stty -echo
        echo -en "$hc\n"
    }

#  ┌──────────── layer 4 ─────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .pulse ]] && {
        {
            (( $2 )) && {
                while :
                do
                    for c in '/' '—' '\' '|'
                    do
                        echo -en "\r$bold( $c )$r"
                        sleep 0.05
                    done
                done & pulse=$!
            return;}

            kill $pulse
            wait $pulse
            echo -en "\r\e[K"
        } 2>/dev/null
    }

    [[ $1 = .extract ]] && {
        lineage=()

        while read pkg opt
        do [[ " ${core[@]} " =~ " $opt " ]] && lineage[$pkg]+="$opt "
        done < <(LC_ALL=C pacman -Qi ${core[@]} | awk '
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

}

# ───────────────────────────────────────────────────────────────────────────────────────── << atlas() >> ───────────────────────────────────────────────────────────────────────────────────────── #
