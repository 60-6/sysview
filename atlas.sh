# ─────────────────────────────────────────────────────────────────────────────────────────── \\  ▼  // ─────────────────────────────────────────────────────────────────────────────────────────── #
                                                                                               atlas()
{

#  ┌── directives ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐

    local default_commands=irfosudc
    local update_interval=3
    local cache_limit=5

#  └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

#  ┌── execution ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐

    (( executing )) || {
        local executing=1 cmds=$*
        local -A delta lineage modified null
        local children csize flatpaks i ii indent last lastc log opt orphans pfx pkg pulse root
        local bold=$'\e[1m' dim=$'\e[2m' red=$'\e[31m' reset=$'\e[m' n=$'\n' r=$'\r' c=$'\e[K' h=$'\e[?25l' s=$'\e[?25h' o=$'\e[7G'

        echo
        atlas .resolve
    }

#  └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

#  ┌── routing ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .resolve ]] && {
        [[ $cmds =~ [^-\ qinrfosudc] ]] && atlas .syntax
        [[ ${cmds//[qin]} ]] || cmds+=$default_commands

        atlas .sig -

        [[ $cmds =~ n ]] || atlas .scan $cmds

        for i in $(fold -w1 <<< $cmds)
        do atlas .$i
        done

        atlas .sig
    }

    [[ $1 = .syntax ]] && {
        echo  $bold  " ▼ atlas commands"
        echo  $reset
        echo         "  ┌── modifiers ──────────────┐"
        echo         "  │ q  ·  quiet output        │"
        echo         "  │ i  ·  implicit mode       │"
        echo         "  │ n  ·  no scan caching     │"
        echo         "  └───────────────────────────┘"
        echo
        echo         "  ┌── operations ─────────────┐"
        echo         "  │ r  ·  view root           │"
        echo         "  │ f  ·  view flatpaks       │"
        echo         "  │ o  ·  view orphans        │"
        echo         "  │ s  ·  temporary save      │"
        echo         "  │ u  ·  upgrade system      │"
        echo         "  │ d  ·  view difference     │"
        echo         "  │ c  ·  cleanup orphans     │"
        echo         "  └───────────────────────────┘"
        kill -2 $$
    }

    [[ $1 = .sig ]] && {
        [[ $2 ]] && {
            atlas .await
            trap '
                atlas .pulse
                atlas .sig
                echo "$r$red> atlas: terminated ⚠$reset$c"
                kill -2 $$
            ' 2 15
        return;}

        atlas .await -
        trap - 2 15
    }

#  └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

#  ┌── operations ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .r ]] && {
        atlas .scan r

        echo "${bold}root (${#root[@]})$reset"
        local -n arr=root
        local -n assoca=lineage
        atlas .render
    }

    [[ $1 = .f ]] && {
        atlas .scan f

        [[ $flatpaks ]] || {
            [[ $cmds =~ i ]] || echo "${dim}flatpaks: nil$reset$n"
        return;}

        echo "${bold}flatpaks (${#flatpaks[@]})$reset"
        local -n arr=flatpaks
        local -n assoca=null
        atlas .render
    }

    [[ $1 = .o ]] && {
        atlas .scan o

        [[ $orphans ]] || {
            [[ $cmds =~ i ]] || echo "${dim}orphans: nil$reset$n"
        return;}

        echo "$red${bold}orphans (${#orphans[@]})$reset"
        local -n arr=orphans
        local -n assoca=null
        atlas .render $red
    }

    [[ $1 = .s ]] && {
        atlas .scan s

        declare -gA save

        save[root]=$(printf "%s$n" "${root[@]}")
        save[flatpaks]=$(printf "%s$n" "${flatpaks[@]}")
        save[orphans]=$(printf "%s$n" "${orphans[@]}")

        [[ $cmds =~ i ]] || echo "${dim}saved$reset$n"
    }

    [[ $1 = .u ]] && {
        [[ $cmds =~ i && $(tac /var/log/pacman.log 2>/dev/null | grep -m1 "system upgrade") > [$(date -d -${update_interval}days +%F) ]] && return

        echo -n "scan for updates? (y/${bold}n$reset) "
        atlas .await - -

        [[ ${REPLY,,} = y ]] && {
            [[ $(command -v yay) ]] && {
                yay
            :;} || {
                [[ $(command -v paru) ]] && {
                    paru
                :;} || sudo pacman -Syu
            }

            [[ $(command -v flatpak) ]] && {
                echo
                flatpak update && flatpak remove --unused
            }
        }

        echo
        atlas .await
    }

    [[ $1 = .d ]] && {
        [[ ${save[@]} ]] || {
            echo "${dim}no save found$reset$n"
        return;}

        atlas .scan d

        for i in root flatpaks orphans
        do
            local -n arr=$i

            delta[${i}0]=$(grep -vxf <(printf "%s$n" "${arr[@]}") <(echo "${save[$i]}"))
            delta[${i}1]=$(grep -vxf <(echo "${save[$i]}") <(printf "%s$n" "${arr[@]}"))

            [[ ${delta[${i}0]}${delta[${i}1]} ]] && {
                echo "${bold}$i delta$reset"
                [[ ${delta[${i}0]} ]] && echo "$red${delta[${i}0]}$reset"
                [[ ${delta[${i}1]} ]] && echo "${delta[${i}1]}"
                echo
            }
        done

        [[ $cmds =~ i || ${delta[@]} =~ [^\ ] ]] || echo "${dim}delta: nil$reset$n"
    }

    [[ $1 = .c ]] && {
        atlas .scan o

        [[ $orphans ]] && {
            echo -n "remove orphans? (y/${bold}n$reset) "
            atlas .await - -

            [[ ${REPLY,,} = y ]] && sudo pacman -Rns ${orphans[@]}

            echo
            atlas .await
        :;} || {
            [[ $cmds =~ i ]] || echo "${dim}no orphans to remove$reset$n"
        }

        csize=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)

        [[ $csize ]] || {
            [[ $cmds =~ i ]] || echo "${dim}cache directory not found$reset$n"
        return;}

        [[ $cmds =~ i ]] && (( $(numfmt --from=iec $csize) < $cache_limit<<30 )) && return

        echo -n "clear package cache [$csize]? (y/${bold}n$reset) "
        atlas .await - -

        [[ ${REPLY,,} = y ]] && yes | sudo pacman -Scc &>/dev/null

        echo
        atlas .await
    }

#  └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

#  ┌── engine ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐

    [[ $1 = .await ]] && {
        [[ $2 ]] && {
            echo -n $s
            stty echo </dev/tty

            [[ $3 ]] && {
                while read -t 0
                do read
                done
                read
            }
        return;}

        stty -echo
        echo -n $h
    }

    [[ $1 = .scan ]] && {
        [[ $2 =~ r ]] && set 0 $2re
        [[ $2 =~ c ]] && set 0 $2o
        [[ $2 =~ [sd] ]] && set 0 $2rfo
        [[ $cmds =~ q ]] && set 0 ${2//e}

        [[ $cmds =~ n ]] || {
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

            set 0 ${2//[$log]}
        }

        atlas .pulse -

        {
            [[ $2 =~ [ro] ]] && {
                echo -n "$o${dim}atlas: scanning orphans…$reset"
                orphans=( $(pacman -Qqtd) )
                log+=o
            }

            [[ $2 =~ r ]] && {
                echo -n "$o${dim}atlas: scanning root…$reset$c"
                root=( $(grep -vxf <(printf "%s$n" "${orphans[@]}") <(pacman -Qqtt)) )
                [[ $2 =~ e ]] && atlas .extract
                log+=r
            }

            [[ $2 =~ f ]] && {
                echo -n "$o${dim}atlas: scanning flatpaks…$reset$c"
                mapfile -t flatpaks < <(flatpak list --app --columns=name)
                log+=f
            }
        } 2>/dev/null

        atlas .pulse
    }

    [[ $1 = .pulse ]] && {
        {
            [[ $2 ]] && {
                while :
                do
                    for f in '/' '—' '\' '|'
                    do
                        echo -n "$r$bold( $f )$reset"
                        sleep 0.05
                    done
                done &pulse=$!
            return;}

            kill $pulse
            wait $pulse
            echo -n "$r$c"
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

    [[ $1 = .render ]] && {
        for i in ${!arr[@]}
        do
            pkg=${arr[i]}

            last=$(( i == ${#arr[@]} - 1 ))
            [[ $cmds =~ q ]] || {
                (( last )) && pfx="│$n└─ " || pfx="│$n├─ "
            }

            echo "$2$pfx$pkg$reset"

            children=( ${assoca[$pkg]} )

            for ii in ${!children[@]}
            do
                pkg=${children[ii]}

                lastc=$(( ii == ${#children[@]} - 1 ))
                (( last )) && indent="   " || indent="│  "
                (( lastc )) && pfx="└─ " || pfx="├─ "

                echo "$2$indent$dim$pfx$pkg$reset"
            done
        done

        echo
    }

#  └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

}

# ───────────────────────────────────────────────────────────────────────────────────────── << atlas() >> ───────────────────────────────────────────────────────────────────────────────────────── #
