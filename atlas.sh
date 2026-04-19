# ─────────────────────────────────────────────────────────────────────────────────────────── \\  ▼  // ─────────────────────────────────────────────────────────────────────────────────────────── #
                                                                                               atlas()
{

#  ┌──────────── layer 0 ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐

    (( executing )) || {
        local executing=1
        echo

        local bold="\e[1m" dim="\e[2m" red="\e[31m" r="\e[m" hc="\e[?25l" sc="\e[?25h" origin="\e[7G" ops=$*
        local children core flatpaks i ii indent intent last lastc opt orphans pfx pkg pulse scache sig
        local -A clineage nullaa

        atlas .interpret
        atlas .resolve
    }

#  ┌──────────── layer 1 ───────────────────────────────────────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .interpret ]] && {
        ops=${ops//[ -]}
        [[ $ops =~ [^qncofsudr] ]] && atlas .clarify
        [[ -z ${ops//[qn]} ]] && ops+=cofsudr
    }

    [[ $1 = .resolve ]] && {
        [[ $ops =~ n ]] || atlas .scan $ops

        while read -n1 i
        do
            [[ $i = c ]] && atlas .core
            [[ $i = o ]] && atlas .orphans
            [[ $i = f ]] && atlas .flatpaks
            [[ $i = s ]] && atlas .save
            [[ $i = u ]] && atlas .upgrade
            [[ $i = d ]] && atlas .delta
            [[ $i = r ]] && atlas .remove
        done <<< $ops
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

    [[ $1 = .core ]] && {
        atlas .scan c

        echo -e "${bold}core (${#core[*]})$r"
        local -n arr=core
        local -n lineage=clineage
        atlas .render
    }

    [[ $1 = .orphans ]] && {
        atlas .scan o

        [[ $orphans ]] && {
            echo -e "$bold${red}orphans (${#orphans[*]})$r"
            local -n arr=orphans
            local -n lineage=nullaa
            atlas .render $red
        :;} || {
            [[ $ops =~ [^o] ]] || echo -e "${dim}nil$r\n"
        }
    }

    [[ $1 = .flatpaks ]] && {
        atlas .scan f

        [[ $flatpaks ]] && {
            echo -e "${bold}flatpaks (${#flatpaks[*]})$r"
            local -n arr=flatpaks
            local -n lineage=nullaa
            atlas .render
        :;} || {
            [[ $ops =~ [^f] ]] || echo -e "${dim}nil$r\n"
        }
    }

    [[ $1 = .save ]] && {
        atlas .scan a
        echo -n #wip
    }

    [[ $1 = .upgrade ]] && {
        echo -en "scan for updates? (y/${bold}n$r) "
        scache=
        read intent </dev/tty
        [[ ${intent,,} = y ]] && {
            flatpak update
            flatpak remove --unused
            echo -n #wip
        } 2>/dev/null
        echo
    }

    [[ $1 = .delta ]] && {
        atlas .scan a
        echo -n #wip
    }

    [[ $1 = .remove ]] && {
        atlas .scan o

        [[ $orphans ]] && {
            echo -en "remove orphans? (y/${bold}n$r) "
            scache=
            read intent </dev/tty
            [[ ${intent,,} = y ]] && sudo pacman -Rns ${orphans[*]}
            echo
        } || {
            [[ $ops =~ [^r] ]] || echo -e "${dim}nil$r\n"
        }
    }

#  ┌──────────── layer 3 ───────────────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .scan ]] && {
        [[ $2 =~ a ]] && set -- $1 ${2}cofq
        [[ $2 =~ r ]] && set -- $1 ${2}o
        [[ $ops =~ q ]] && set -- $1 ${2}q
        [[ $ops =~ n ]] || set -- $1 ${2//[$scache]}

        {
            atlas .pulse

            [[ $2 =~ [co] ]] && {
                echo -en "$origin${dim}atlas: scanning orphans$r"
                orphans=( $(pacman -Qqtd) )
                scache+=o
            }

            [[ $2 =~ c ]] && {
                echo -en "$origin${dim}atlas: scanning core$r\e[K"
                core=( $(grep -vxf <(printf "%s\n" ${orphans[*]}) <(pacman -Qqtt)) )
                [[ $2 =~ q ]] || atlas .extractcl
                scache+=c
            }

            [[ $2 =~ f ]] && {
                echo -en "$origin${dim}atlas: scanning flatpaks$r\e[K"
                mapfile -t flatpaks < <(flatpak list --app --columns=name)
                scache+=f
            }

            atlas .pulse
        } 2>/dev/null
    }

    [[ $1 = .render ]] && {
        for i in ${!arr[*]}
        do
            pkg=${arr[i]}

            last=$(( i == ${#arr[*]} - 1 ))

            [[ $ops =~ q ]] || {
                (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
            }

            echo -e "$2$pfx$pkg$r"

            children=( ${lineage[$pkg]} )

            for ii in ${!children[*]}
            do
                pkg=${children[ii]}

                lastc=$(( ii == ${#children[*]} - 1 ))

                (( last )) && indent="   " || indent="│  "
                (( lastc )) && pfx="└─ " || pfx="├─ "

                echo -e "$2$indent$dim$pfx$pkg$r"
            done
        done
        echo
    }

#  ┌──────────── layer 4 ─────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .pulse ]] && {
        (( pulse )) && {
            eval "${sig:-trap - 2}"
            kill $pulse
            wait $pulse
            pulse=
            echo -en "\r\e[K$sc"
            stty echo </dev/tty
            return
        }

        while :
        do
            for c in '/' '—' '\' '|'
            do
                echo -en "\r$bold( $c )$r"
                sleep 0.05
            done
        done &

        pulse=$!
        echo -en "$hc"
        stty -echo
        sig=$(trap -p 2)
        trap '
            atlas .pulse
            echo -e "${red}scanning terminated$r"
            kill -2 $$
        ' 2
    }

    [[ $1 = .extractcl ]] && {
        clineage=()
        while read pkg opt
        do [[ " ${core[*]} " =~ " $opt " ]] && clineage[$pkg]+="$opt "
        done < <(LC_ALL=C pacman -Qi ${core[*]} | awk '
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
