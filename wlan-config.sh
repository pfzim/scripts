#!/bin/sh

# RUN:
# wget http://hencvik.googlecode.com/files/wlan-config.sh
# chmod a+rx wlan-config.sh
# sudo ./wlan-config.sh

back_title="Ubuntu WLAN configuration script v0.02 (c) pfzim"
fg_title="Ubuntu configuration"
DIALOG=whiptail

ask() {
  while :
  do
    read -p "$1" $2
    if [ -n "$(eval "echo \$$2")" ] ; then
      break
    fi
    if [ $# -gt 2 -a -n "$3" ] ; then
      eval "$2=\$3"
      break
    fi
  done
}

a_msgbox() {
  ${DIALOG} --backtitle "${back_title}" --clear --title "${fg_title}" --msgbox "$1" 10 75
}

# text result default
a_yesno() {
  defval=" --defaultno"
  if [ "$3" = "yes" ] ; then
    defval=""
  fi
  
  ${DIALOG} --backtitle "${back_title}" --clear --title "${fg_title}"${defval} --yesno "$1" 22 75
  if [ $? -eq 0 ] ; then
    eval "$2=Y"
  else
    eval "$2=N"
  fi
}

# text result=default value
a_input() {
  temp_result=`mktemp 2>/dev/null` || temp_result=/tmp/test$$
  eval "${DIALOG} --backtitle \"${back_title}\" --clear --title \"${fg_title}\"${defval} --inputbox \"$1\" 10 75 \"\${$2}\" 2>$temp_result"
  result=`cat $temp_result`
  rm -f $temp_result
  if [ $? -eq 0 ] ; then
    eval "$2=\$result"
  fi
}

# text result
a_passwd0() {
  temp_result=`mktemp 2>/dev/null` || temp_result=/tmp/test$$
  ${DIALOG} --backtitle "${back_title}" --clear --title "${fg_title}"${defval} --passwordbox "$1" 10 75 2>$temp_result
  result=`cat $temp_result`
  rm -f $temp_result
  if [ $? -eq 0 ] ; then
    eval "$2=\$result"
  else
    eval "$2=\"$3\""
  fi
}

a_passwd() {
  while :
  do
    temp_passwd1=""
    temp_passwd2=""
    a_passwd0 "$1" temp_passwd1
    a_passwd0 "Enter password again:" temp_passwd2
    if [ -n "$temp_passwd1" -a "$temp_passwd1" = "$temp_passwd2" ] ; then
      eval "$2=\"$temp_passwd1\""
      break
    fi
  done
}

if [ "$(id -u)" != "0" ]; then
  echo "Sorry, you must execute me with sudo."
  exit 1
fi

# configure wireless network
############################

ask_settings_ip() {
  while :
  do
    a_input "Enter IP address [192.168.1.100]:" $1
    a_input "Enter network mask [255.255.255.0]:" $2
    a_input "Enter gateway [192.168.1.1]:" $3
    a_input "Enter DNS1 []:" $4
    a_input "Enter DNS2 []:" $5

    eval "a_yesno \"Network settings:\\n\\nIP: \$$1\nMask: \$$2\\nGateway: \$$3\\nDNS1: \$$4\\nDNS2: \$$5\\n\\nEntered data correct?\" result"
    if [ "$result" = "Y" -o "$result" = "y" ] ; then
      break
    fi
  done
}

ask_settings_pass() {
  while :
  do
    #read -s -p "Enter WPA password: " p1
    #read -s -p "Enter again: " p2
    #read -p "Enter WPA password: " p1
    #read -p "Enter again: " p2
    a_passwd "Enter password for wireless network:" p1

    if [ "${#p1}" -ge 8 -a "${#p1}" -le 63 ] ; then
      eval "$1=$p1"
      break
    else
      a_msgbox "Passphrase must be 8..63 characters"
    fi
  done
}

#read -p "Configure wireless interface [Y/n]?" result
c_wifi_pre() {
  #sudo apt-get install wpasupplicant
  
  fg_title="Wireless network configuration"

  while :
  do
    list_items=$(iwconfig | grep -e "^\\s*[a-zA-Z]\+[0-9]\+" | sed -e "s/^\\s*\([a-zA-Z]\+[0-9]\+\).*\$/\\1/" |
      (
        n=1
        while read line
        do
          echo "\"${line}\" \"Wireless interface ${n}\""
          n=$((n+1))
        done
        echo "rescan \"Find new WiFi adapters...\""
        echo "exit \"Finish configuration\""
      )
    )

    if [ -z "${list_items}" ] ; then
      break
    fi

    tempfile=`mktemp 2>/dev/null` || tempfile=/tmp/test$$
    #trap "rm -f $tempfile" 0 1 2 5 15

    eval ${DIALOG} --backtitle \"${back_title}\" --clear --title \"Wireless network configuration\" --menu \"Select WiFi inteface\" 20 75 13 ${list_items} 2>$tempfile

    if [ $? -ne 0 ] ; then
      rm -f $tempfile
      break
    fi

    net_if=$(cat $tempfile)
    rm -f $tempfile

    if [ "${net_if}" = "rescan" ] ; then
      continue
    fi

    if [ "${net_if}" = "exit" ] ; then
      break
    fi

    ifconfig ${net_if} up

    list_items=$(iwlist ${net_if} scan 2>&1 | \
    sed -e "s/^\\s*//" \
        -e "s/^Cell [0-9]\+ - /#/" \
        -e "s/^#Address: \([0-9a-Z:]\+\)$/#ap_mac=\"\\1\"/" \
        -e "s/^Quality=\([0-9]\+\\/[0-9]\+\).*$/ap_quality=\"\\1\"/" \
        -e "s/^.*Channel \([0-9]\+\).*$/ap_channel=\\1/" \
        -e "s/^ESSID:/ap_essid=/" \
        -e "s/^Mode: \([a-Z]+\)$/ap_mode=\\1/" \
        -e "s/^Encryption key:\([a-Z]\+\)$/ap_enc=\\1/" \
        -e "s/^IE: WPA Version \([0-9]\+\)$/ap_etype=WPA\nap_ever=\\1/" | \
    grep "^#\?ap_[a-z]\+=.*$" | \
    tr "\n#" ";\n" | \
    grep -v "^$" | \
    sed -e "s/;$//" | \
    sed -e "s/\"/\\\"/" | \
    awk "{ print NR \";\" \$0 }"
      )
    list_menu=$(echo "${list_items}" | sed -e "s/^\([0-9]\+\).*ap_essid=\([^;]\+\).*$/\1 \2/")

    #echo "*** RESULT ***"
    #echo "${list_items}"
    #echo "*** RESULT ***"
    #echo "*** RESULT ***"
    #echo "${list_menu}"
    #echo "*** RESULT ***"

    if [ -n "${list_items}" ] ; then
      eval ${DIALOG} --backtitle \"${back_title}\" --clear --title \"Wireless network configuration\" --menu \"Select WiFi accesspoint\" 20 75 13 ${list_menu} 2>$tempfile

      if [ $? -eq 0 ] ; then
        sel_item=$(cat $tempfile)
        ap_info=$(echo "${list_items}" | grep "^${sel_item};" | sed -e "s/^[0-9]\+;//")
        #echo "AP_INFO: ${ap_info}"
        eval "${ap_info}"
        #echo "MAC: ${ap_mac}"
        #echo "ESSID: ${ap_essid}"
        #echo "ENC-TYPE: ${ap_etype}"

        net_res="# xbmc-config-script-${net_if}\n"
        net_res="${net_res}auto ${net_if}\n"
        net_dhcp=1

        #read -p "Use DHCP [Y/n]?" result
        a_yesno "Use DHCP?" result "yes"
        if [ "$result" = "Y" -o "$result" = "y" ] ; then
          net_res="${net_res}iface ${net_if} inet dhcp\n"
        else
          net_dhcp=0
          net_ip="192.168.1.100"
          net_mask="255.255.255.0"
          net_gw="192.168.1.1"
          net_dns1=""
          net_dns2=""
          ask_settings_ip net_ip net_mask net_gw net_dns1 net_dns2
          net_res="${net_res}iface ${net_if} inet static\n"
          net_res="${net_res}address ${net_ip}\n"
          net_res="${net_res}netmask ${net_mask}\n"
          net_res="${net_res}gateway ${net_gw}\n"
          if [ -n "${net_dns1}" -o -n "${net_dns2}" ] ; then
            net_res="${net_res}dns-nameservers"
            if [ -n "${net_dns1}" ] ; then
              net_res="${net_res} ${net_dns1}"
            fi
            if [ -n "${net_dns2}" ] ; then
              net_res="${net_res} ${net_dns2}\n"
            fi
            net_res="${net_res}\n"
          fi
        fi

        if eval "sed \"/# xbmc-config-script-${net_if}/,/# xbmc-config-script-${net_if}-end/d\" /etc/network/interfaces | grep -v -e \"^\\\\s*#\" | grep -q -e \"${net_if}\"" ; then
          a_msgbox "Error: configuration for interface ${net_if} already exist in file /etc/network/interfaces"
        else
          if [ "${ap_enc}" = "on" ]  ; then
            ask_settings_pass ap_pass

            if [ "${ap_etype}" = "WPA" ]  ; then
              ap_pass=$(wpa_passphrase "${ap_essid}" "${ap_pass}" | grep "^\s*psk=" | sed -e "s/^\s*psk=\(.*\)$/\1/")

              net_res="${net_res}wpa-driver wext\n"
              net_res="${net_res}wpa-ssid ${ap_essid}\n"
              net_res="${net_res}wpa-ap-scan 2\n"
              net_res="${net_res}wpa-proto RSN WPA\n"
              net_res="${net_res}wpa-pairwise CCMP TKIP\n"
              net_res="${net_res}wpa-group CCMP TKIP\n"
              net_res="${net_res}wpa-key-mgmt WPA-PSK\n"
              net_res="${net_res}wpa-psk ${ap_pass}\n"
            else
              # WEP
              net_res="${net_res}wireless-mode managed\n"
              net_res="${net_res}wireless-essid ${ap_essid}\n"
              net_res="${net_res}wireless-enc ${ap_pass}\n"
            fi
          else
              net_res="${net_res}wireless-mode managed\n"
              net_res="${net_res}wireless-essid ${ap_essid}\n"
          fi

          net_res="${net_res}# xbmc-config-script-${net_if}-end\n"

          #echo "\n${net_res}"

          #read -p "Save this configuration [Y/n]?" result
          a_yesno "${net_res}\nSave this configuration?" result "yes"
          if [ "$result" = "Y" -o "$result" = "y" ] ; then
            sed -i "/# xbmc-config-script-${net_if}/,/# xbmc-config-script-${net_if}-end/d" /etc/network/interfaces
            echo "${net_res}" >> /etc/network/interfaces
          fi

          a_yesno "${net_res}\nConnect using this configuration?" result "yes"
          if [ "$result" = "Y" -o "$result" = "y" ] ; then
            if [ "${ap_enc}" = "on" ]  ; then
              if [ "${ap_etype}" = "WPA" ]  ; then
                tempconf=`mktemp 2>/dev/null` || tempconf=/tmp/test$$
                wpa_passphrase "${ap_essid}" "${ap_pass}" > tempconf
                wpa_supplicant -Dwext -i${net_if} -c${tempconf}
                rm -f ${tempconf}
              else
                iwconfig ${net_if} essid "${ap_essid}" key "${ap_pass}"
              fi
            else
              iwconfig ${net_if} essid "${ap_essid}"
            fi

            if [ "$net_dhcp" -eq 1 ] ; then
              dhclient ${net_if}
            else
              ifconfig ${net_if} inet ${net_if} netmask ${net_mask}
              route add default gw ${net_gw} ${net_if}
            fi
          fi

        fi

      fi
      rm -f $tempfile

    fi

  done
}

c_wifi_pre
