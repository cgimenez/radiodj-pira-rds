Pira 32 driver for RadioDJ
=

A small but efficient solution to drive a Pira 32 RDS (https://pira.cz/eng/) encoder with a Raspberry (or any host running linux) throught serial port. This Ruby app have been running 7/7 days for years. You can tailor this app to suite your needs and have a very powerfull solution for less than 200$

This program is provided AS-IS - It's been only used with RadioDJ 1.8.X

The Pira 32 have been discontinued but the Pira 132 is told to be backward compatible.

This app acts as a TCP server, receiving broadcast data from a RadioDJ client about the currently playing program.

On RadioDJ side :

- Go to the Now Playing plugin
- Click network tab and select TCP, port 21100 and type the IP address of the Raspberry
- Navigate through your filesystem to select a 'template radiodj file' which is nothing more than a text file containing
  `ARTIST=$artist$^TITLE=$title$^TYPE=$track-type$^DURATION=$durationinSeconds$^ALBUM=$album$`

Each time a new broadcast program is started, RadioDJ will open a shortlived connection to the RDS driver, providing the informations of the template.

On Raspberry side (Minimal install documentation without details) :

- clone this repo somewhere into /home/pi
- install the usual gcc collection with apt-get

if you want to run this app as a systemd service, stay away from rvm - just install the stock ruby 2.x provided with your Raspbian distro
- apt-get install ruby2.1
- apt-get install ruby2.1-dev
- apt-get install gem2.1
- symlink /usr/bin/ruby2.1 to /usr/bin/ruby
- symlink /usr/bin/gem2.1 to /usr/bin/gem
- sudo gem install rubyserial

- configure the STATION_SHORT (PS), STATION_PI (PI) and STATION_LONG (for Dynamic PS) at the top of rds.rb file

Create rds.service file in /etc/systemd/system/ as

```
[Unit]
Description=rds
After=network.target
[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/home/pi/rds
ExecStart=/usr/bin/ruby /home/pi/rds/rds-v1.3.rb daemon
TimeoutSec=30
RestartSec=15s
Restart=always
[Install]
WantedBy=multi-user.target
```

Then from there, you can

```
sudo systemctl restart rds.service
sudo systemctl start rds.service
sudo systemctl stop rds.service
```

Using systemd is not mandatory, you can start the app as ruby ./rds.rb in a 'screen' session then detach the terminal and leave it running. But if the app crashes you'll be stuck with a non refreshed RDS signal. So, the systemd.


*(C) 2016 Christophe Gimenez*
