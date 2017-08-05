# tado plugin for Vera / MiOS
## Tado Plugin for Vera / MiOS

I have created this plugin that will be available on the Vera / MiOS app store for end users to install.

I wrote the plugin to control my Smart AC Controller from Tado but I have also tested it against a Smart Thermostat. I have not tested it against a Smart Radiator Valve as I have not got one but if anyone wants to lend me their Tado.com account then I can test and update to add support for it.

In general it seems to be fairly stable now, but I havent got a large test base so I welcome any feedback from anyone who has tested it.

## Installation
After installing the plugin, a Tado.com Connection device should automatically be created. In the Web UI, there is a Tado Settings page belonging to it. Please specify your tado.com credentials here and press Set next to each value before hitting Apply

Your Vera device will now login to tado.com and get a list of all your homes and devices. You will see your luup engine reload when it creates all the child devices.

You'll have a "Home" device appear, this device will contain all the variables related to your house (its weather, gps location etc).

You'll then have a "Zone" device created for each Tado unit you have registered under that house. So if you have a Tado unit called Bedroom then it will be created and will appear as a thermostat.

## How to use / Layout

This is my first attempt at a MiOS plugin and my first time programming in Lua. From the various online information I could find, it is advised to try to use exisitng UPNP values where possible. So I have done that and used the inbuilt Thermostat device and serviceIDs rather than creating my own. That means I am limited though to the predefined graphical layouts.

For example, setting the Fan speed. Tado offers Low, Middle, High and Auto values, whilst the Vera will on the web interface display buttons for PeriodicOn, ConstantOn and Auto. On the mobile app it wont even display any buttons to control the fan speed.

So I have mapped the features across so that Auto will map to Auto, ConstantOn will map to High and PeriodicOn will map to Low.

When it comes to enabling Manual mode verus Smart Schedule, I have tied this to the Energy Mode. Enabling Energy Mode will set the Tado to the Smart Schedule (the thinking behind it is that you'll save money as it will not switch on if you are not home). Whilst Normal mode will put the Tado into Manual override mode. Then the thermostat will just act like an old dum thermostat.

## UI7

I have only tested the plugin towards UI7 (firmware 1.7.963). I originally tried it against version 1.7.947, but this version seems to have some bugs that have now been resolved in 963 (problems with not being able to change the username/password from the Tado Setting page etc).

Also the latest iOS app as off 02/08/2017 seems to fix the issues with the Auto button having the wrong label and Heat and Auto buttons showing up even on Smart Thermostats that only have a Heat and Off mode (in the iOS app, it seems like the web gui still incorrectly shows the Cool and Auto button for the Smart Thermostats).

## Good to know
- Dry mode can be enabled using the SetModeTarget option in case someone wants to do it progamatically. However there is no graphical support for Dry or Fan Only mode so the GUI will not display what mode it is in
- Tado does not report a SetPoint temperature if the Thermostat/AC Controller is not in Heating or Cooling mode. Therefore if it is Off or in Auto, then no temperature (or NaN) will be displayed.
- To make it easier for people who want to write their own coding etc, I have added a Get<variablename> for each variable. So you can easily retrieve any data you want (Visit http://<VERA_IP>:3480/data_request?id=lu_invoke )

## Known issues
- As mentioned earlier, by using the UPNP standard I am limited to the graphical appearance. But I could look at writing my own graphical layout in the future

If you have any issues. Please set Debug to 1 on your Tado.com connection, hit reload and send me a copy of the log file produced. You can access your log file from SSH or via this address, http://<VERA_IP>/cgi-bin/cmh/log.sh?Device=LuaUPnP

## Feature requests
Please let me know if there is a particular feature you feel that is missing and I'll see how hard it will be to incorporate it

## Want to help out?
Happy for anyone to join the project if they want to help improve it or maintain it.
