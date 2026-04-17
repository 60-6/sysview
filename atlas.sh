# ─────────────────────────────────────────────────────────────────────────────────────────── \\  ▼  // ─────────────────────────────────────────────────────────────────────────────────────────── #
                                                                                               atlas()
{

#  ┌──────────── execute ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ 0

    (( executing )) || {
        local executing=1
        echo

        local bold="\e[1m" dim="\e[2m" red="\e[31m" r="\e[m" hc="\e[?25l" sc="\e[?25h" origin="\e[7G" ops=$*
        local attr children core flatpaks i ii indent intent last lastc opt orphans pfx pkg pulse sig sops
        local -A clineage nullaa

        atlas _interpret
        atlas _resolve
    }

#  ┌──────────── interpret ─────────────────────────────────────────────────────────────────────────────────────────────────────────┐ 1

    [[ $1 = _interpret ]] && {
        ops=${ops//[ -]}
        [[ $ops =~ [^qcofsudr] ]] && atlas _error
        [[ -z ${ops//q} ]] && ops+=cofsudr
    }

#  ┌──────────── resolve ───────────────────────────────────────────────────────────────────────────────────────────────────────────┐ 1

    [[ $1 = _resolve ]] && {
        atlas _visualize
        [[ $ops =~ s ]] && atlas _save
        [[ $ops =~ u ]] && atlas _upgrade
        [[ $ops =~ d ]] && atlas _delta
        [[ $ops =~ r ]] && atlas _remove
    }

#  ┌──────────── error ─────────────────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _error ]] && {
        echo -e "usage:  atlas ${bold}[qcofsudr]$r\n"
        echo "  q  ➜  quiet mode"
        echo "  c  ➜  view core packages"
        echo "  o  ➜  view orphans"
        echo "  f  ➜  view flatpak apps"
        echo "  s  ➜  save state"
        echo "  u  ➜  upgrade system"
        echo "  d  ➜  show difference"
        echo "  r  ➜  remove orphans"
        kill -2 $$
    }

#  ┌──────────── visualize ─────────────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _visualize ]] && {
        sops=$ops
        atlas _scan

        [[ $ops =~ c ]] && {
            echo -e "${bold}core (${#core[*]})$r"
            local -n arr=core
            local -n lineage=clineage
            atlas _render
        }

        [[ $ops =~ o ]] && {
            [[ $orphans ]] && {
                echo -e "$bold${red}orphans (${#orphans[*]})$r"
                local -n arr=orphans
                local -n lineage=nullaa
                attr=$red
                atlas _render
                attr=
            } || {
                [[ $ops =~ [^o] ]] || echo -e "${dim}nil$r\n"
            }
        }

        [[ $ops =~ f ]] && {
            [[ $flatpaks ]] && {
                echo -e "${bold}flatpaks (${#flatpaks[*]})$r"
                local -n arr=flatpaks
                local -n lineage=nullaa
                atlas _render
            } || {
                [[ $ops =~ [^f] ]] || echo -e "${dim}nil$r\n"
            }
        }
    }

#  ┌──────────── save ──────────────────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _save ]] && {
        echo -n #wip
    }

#  ┌──────────── upgrade ───────────────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _upgrade ]] && {
        echo -en "scan for updates? (y/${bold}n$r) "
        read intent
        [[ ${intent,,} = y ]] && {
            flatpak update
            flatpak remove --unused -y
            echo -n #wip
        }
        echo
    }

#  ┌──────────── delta ─────────────────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _delta ]] && {
        echo -n #wip
    }

#  ┌──────────── remove ────────────────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _remove ]] && {
        sops=o
        atlas _scan

        [[ $orphans ]] && {
            echo -en "remove orphans? (y/${bold}n$r) "
            read intent
            [[ ${intent,,} = y ]] && sudo pacman -Rns ${orphans[*]}
            echo
        } || {
            [[ $ops =~ [^r] ]] || echo -e "${dim}nil$r\n"
        }
    }

#  ┌──────────── scan ──────────────────────────────────────────────────────────────────────────────────────┐ 3

    [[ $1 = _scan ]] && {
        {
            atlas _pulse

            [[ $sops =~ [co] ]] && {
                echo -en "$origin${dim}atlas: scanning orphans$r\e[K"
                orphans=( $(pacman -Qqtd) )
            }

            [[ $sops =~ c ]] && {
                echo -en "$origin${dim}atlas: scanning core$r\e[K"
                core=( $(grep -vxf <(printf "%s\n" ${orphans[*]}) <(pacman -Qqtt)) )
                [[ $sops =~ q ]] || atlas _extractcl
            }

            [[ $sops =~ f ]] && {
                echo -en "$origin${dim}atlas: scanning flatpaks$r\e[K"
                mapfile -t flatpaks < <(flatpak list --app --columns=name)
            }

            atlas _pulse
        } 2>/dev/null
    }

#  ┌──────────── render ────────────────────────────────────────────────────────────────────────────────────┐ 3

    [[ $1 = _render ]] && {
        for i in ${!arr[*]}
        do
            pkg=${arr[i]}

            last=$(( i == ${#arr[*]} - 1 ))

            (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
            [[ $ops =~ q ]] && pfx=

            echo -e "$attr$pfx$pkg$r"

            children=( ${lineage[$pkg]} )

            for ii in ${!children[*]}
            do
                pkg=${children[ii]}

                lastc=$(( ii == ${#children[*]} - 1 ))

                (( last )) && indent="   " || indent="│  "
                (( lastc )) && pfx="└─ " || pfx="├─ "

                echo -e "$attr$indent$dim$pfx$pkg$r"
            done
        done
        echo
    }

#  ┌──────────── pulse ─────────────────────────────────────────────────────────────────────────┐ 4

    [[ $1 = _pulse ]] && {
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
            atlas _pulse
            echo -e "${red}scanning terminated$r"
            kill -2 $$
        ' 2
    }

#  ┌──────────── extractcl ─────────────────────────────────────────────────────────────────────┐ 4

    [[ $1 = _extractcl ]] && {
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
