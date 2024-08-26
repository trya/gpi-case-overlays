# GPI Case overlays

**At the time, only an overlay for the GPI Case 2 is available, as I only own this one, but feel free to submit overlays for other GPI Case models in merge requests.**

## Overview

These overlays are supposed to be cleaner replacements for the patch scripts provided by Retroflag for correct display and safe shutdown (Retroflag could have included such an overlay into an ID EEPROM so that none of these would be necessary, but whatever).

The main idea behind these is to get the GPI Case to work with unpatched distributions, such as Raspberry Pi OS (_Raspbian_) or RetroPie.

## Usage

### Main use case (DPI screen and safe shutdown)

Copy the binary device tree overlays (with `.dtbo` extension) into the `/boot/overlays` directory (or `/boot/firmware/overlays` on RPi OS Bookworm and later), then add the following section into `/boot/config.txt`:
```
[cm4]
dtoverlay=gpi-case-2
```
You may want to remove the `otg_mode=1` line if present as it prevents the use of USB peripherals.

And that's all for the main use case. The screen works with the KMS driver (not firmware KMS anymore) and switching the power button should trigger a `KEY_POWER` event (code 116) that systemd should catch and then execute a proper shutdown, given logind is properly configured. `/etc/systemd/logind.conf` should tell systemd to power off the system upon such event:
```
[Login]
HandlePowerKey=poweroff
```

### Automatic display switching with dock

When the GPI Case 2 is docked with the provided Retroflag dock, we expect both the machine to switch to HDMI video and audio outputs, which is not so evident depending on the desktop environment.
Supposing a simple X11 desktop environment which does not manage displays and Pulseaudio/Pipewire as the sound server, just copy  `switch_gpi_disp.sh` to `/usr/local/bin` and `85-switch-gpi-disp.rules` to `/etc/udev/rules.d`. Reboot or reload udev rules and that's it for automatic display switching!

## Compiling device tree overlays

This repository also provide source of the device tree overlays in two forms: before and after preprocessing. The GPI Case overlay is built by merging other overlays together (with `ovmerge`) and some of the parent overlays may contain device tree includes in the form of Linux C headers, so the source needs to be preprocessed before being compiled with `dtc`.
To preprocess the overlay source `gpi-case-2-overlay.dts`:
```
cpp -nostdinc -undef -x assembler-with-cpp -I [path to linux kernel headers] gpi-case-2-overlay.dts gpi-case-2-overlay.dts.preproc
```
Then, to compile the preprocessed overlay source `gpi-case-2-overlay.dts.preproc`:
```
dtc -I dts -O dtb -o gpi-case-2.dtbo gpi-case-2-overlay.dts.preproc
```

## Technical details

### Device tree overlay 

The source overlay is built with already existing overlays provided with the kernel. The above line 
`dtoverlay=gpi-case-2` in `/boot/config.txt` could be replaced with:
```
dtoverlay=dwc2,dr_mode=host
dtoverlay=vc4-kms-dpi-generic
dtparam=hactive=640,hfp=41,hsync=40,hbp=41
dtparam=vactive=480,vfp=18,vsync=9,vbp=18
dtparam=clock-frequency=24000000,rgb666-padhi
dtparam=width-mm=60,height-mm=45
dtoverlay=gpio-led,gpio=27,active_low=1,label=power_enable
dtoverlay=gpio-shutdown,gpio_pin=26  
```
- `dtoverlay=dwc2,dr_mode=host` enables USB hosting on the USB-C port, meaning you can plug USB peripherals in.
- `dtoverlay=vc4-kms-dpi-generic` and the following `dtparams` configures the 3-inch display (DPI) with the proper timings in KMS. The `rgb666-padhi` parameter tells the kernel that only the 6 most significant bits are used for each color channel, meaning GPIO pins 10, 11, 18, 19, 26 and 27 are not used by the display (the last two of which will be important for safe shutdown).
- `dtoverlay=gpio-led,gpio=27,active_low=1,label=power_enable` and `dtoverlay=gpio-shutdown,gpio_pin=26` are related to safe shutdown. Actually, when you switch the power button of the GPI Case 2 back to off, GPIO 26 on the CM4 gets pulled down and power is cut immediately. It looks like GPIO 27 on the CM4 is also wired to power, so keeping it high with overlay `gpio-led` will keep the machine powered on despite switch off. Then, the CM4 can see the falling edge on GPIO 26 and consider it a `KEY_POWER` event thanks to overlay `gpio-shutdown`.

### Automatic display switching

When the GPI Case 2 is plugged in the USB-C port of the dock, GPIO 18 is raised and both display and speaker are turned off (this is not controlled by the Raspberry Pi, by the way). The main effect of GPIO 18 from the CM4's point of view is that it controls the emulation of an HDMI input (with its associated I2C/DDC bus and EDID ROM), with a maximum resolution of 1280x720 at 60 Hz, which means the CM4 cannot really know the external display that's actually plugged in the dock, only a couple of common resolutions are exposed to the CM4. GPIO 18 is actually not raised if no display is plugged in the dock, which means its behavior is controlled by logic inside the dock.

The best we can do as far as the Retroflag dock is involved is to detect that a display is connected through a udev event, then change the video and audio outputs. On the GPI Case 2, the speaker is connected to a USB audio card (referenced as sink `alsa_output.usb-GeneralPlus_USB_Audio_Device-00.analog-stereo` in Pulseaudio).

## TODO

- Overlays for other GPI Case models.
- Modding for compatibility with all HDMI displays resolutions: I need to find out how to bypass the current HDMI-to-USB passthrough and enable full HDMI functionality between the external display and the CM4.
