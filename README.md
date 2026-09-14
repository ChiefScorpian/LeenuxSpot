# LeenuxSpot

LeenuxSpot is a Linux NetworkManager-based hotspot/router controller.

## Installation

Run:

    sudo ./install.sh

The installer installs:

    /usr/local/bin/leenuxctl

If an existing installation is found, it is backed up automatically.

## Setup

Create a hotspot:

    sudo leenuxctl setup --name LeenuxSpot --password 'your-password'

You can also specify the Wi-Fi interfaces:

    sudo leenuxctl setup \
        --name LeenuxSpot \
        --password 'your-password' \
        --upstream wlan0 \
        --hotspot wlan1

## Useful commands

    sudo leenuxctl status
    sudo leenuxctl doctor

    sudo leenuxctl start
    sudo leenuxctl stop
    sudo leenuxctl restart

## Domain blocking

    sudo leenuxctl domain block example.com
    sudo leenuxctl domain block example.com --kill
    sudo leenuxctl domain unblock example.com
    sudo leenuxctl domain list
    sudo leenuxctl domain status

## Client management

    sudo leenuxctl client list
    sudo leenuxctl client status <MAC|IP|hostname>
    sudo leenuxctl client block <MAC|IP|hostname>
    sudo leenuxctl client unblock <MAC|IP|hostname>

## Modes

    sudo leenuxctl mode router
    sudo leenuxctl mode lan-only
    sudo leenuxctl mode disabled

## Runtime files

LeenuxSpot creates its configuration at runtime.

Configuration:

    /etc/leenux/

NetworkManager DNS configuration:

    /etc/NetworkManager/dnsmasq-shared.d/

Block-page service:

    /etc/systemd/system/leenux-blockpage.service

Controller:

    /usr/local/bin/leenuxctl
